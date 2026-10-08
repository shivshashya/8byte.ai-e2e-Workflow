"""Operator-only credential initialization over SSH. Run explicitly with --execute.

Uses local AWS credentials for the admin secret and writes application versions
outside Terraform. EC2 never gains IAM permission to retrieve the admin secret.
Requires a previously verified SSH host key in the operator's known_hosts file.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import secrets
import shlex
import subprocess
import tempfile


def command(arguments, *, label, input_text=None):
    result = subprocess.run(arguments, input=input_text, text=True, capture_output=True, timeout=300)
    if result.returncode:
        # AWS/SSH/psql output could contain secrets. Never dump a failed process.
        raise RuntimeError(label + " failed; sensitive process output suppressed")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", required=True,
                        help="Explicitly allow credential writes and database initialization")
    parser.parse_args()
    scripts = Path(__file__).resolve().parent
    outputs = json.loads(command(["terraform", f"-chdir={scripts.parent}", "output", "-json"], label="Terraform outputs"))
    values = {name: output["value"] for name, output in outputs.items()}
    region = values["rds_admin_secret_arn"].split(":")[3]
    account = values["rds_admin_secret_arn"].split(":")[4]

    def aws(*arguments):
        return json.loads(command(["aws", *arguments, "--region", region, "--output", "json"], label="AWS " + arguments[0] + " " + arguments[1]))

    if aws("sts", "get-caller-identity")["Account"] != account:
        raise RuntimeError("Operator AWS account does not match Terraform infrastructure")
    instance = aws("ec2", "describe-instances", "--instance-ids", values["ec2_instance_id"])["Reservations"][0]["Instances"][0]
    admin = json.loads(aws("secretsmanager", "get-secret-value", "--secret-id", values["rds_admin_secret_arn"])["SecretString"])
    applications = {}
    for environment, username in [("staging", "staging_user"), ("production", "production_user")]:
        arn = values["database_secret_arns"][environment]
        metadata = aws("secretsmanager", "describe-secret", "--secret-id", arn)
        versions = metadata.get("VersionIdsToStages", {})
        expected = {"engine": "postgres", "host": values["rds_address"], "port": values["rds_port"],
                    "dbname": "app_" + environment, "username": username}
        if versions:
            if not any("AWSCURRENT" in stages for stages in versions.values()):
                raise RuntimeError("Existing secret has no current version; review before continuing")
            credentials = json.loads(aws("secretsmanager", "get-secret-value", "--secret-id", arn)["SecretString"])
            if any(credentials.get(key) != value for key, value in expected.items()):
                raise RuntimeError("Existing application secret metadata does not match the expected database")
        else:
            credentials = {**expected, "password": secrets.token_hex(32)}
        if not isinstance(credentials.get("password"), str) or any(c in credentials["password"] for c in "\r\n"):
            raise RuntimeError("Application password has an unsupported format")
        applications[environment] = {**credentials, "secret_arn": arn, "already_stored": bool(versions)}
    if applications["staging"]["password"] == applications["production"]["password"]:
        raise RuntimeError("Application environments must have different passwords")

    with tempfile.TemporaryDirectory(prefix="petclinic-operator-") as directory:
        key = os.path.join(directory, "ssh_key")
        command(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", key], label="Temporary SSH key generation")
        proxy = shlex.join(["aws", "ec2-instance-connect", "open-tunnel", "--region", region,
                           "--instance-connect-endpoint-id", values["ssh_endpoint_id"],
                           "--private-ip-address", instance["PrivateIpAddress"], "--remote-port", "22"])
        ssh = ["ssh", "-T", "-i", key, "-o", "IdentitiesOnly=yes", "-o", "StrictHostKeyChecking=yes",
               "-o", "ConnectTimeout=20", "-o", "ProxyCommand=" + proxy, "ec2-user@" + instance["PrivateIpAddress"]]

        def remote(remote_command, payload=None):
            # Temporary public keys remain valid for 60 seconds; renew each call.
            response = aws("ec2-instance-connect", "send-ssh-public-key", "--instance-id", values["ec2_instance_id"],
                           "--availability-zone", instance["Placement"]["AvailabilityZone"], "--instance-os-user", "ec2-user",
                           "--ssh-public-key", "file://" + key + ".pub")
            if not response.get("Success"):
                raise RuntimeError("Temporary SSH key upload failed")
            return command([*ssh, remote_command], label="SSH database operation", input_text=payload)

        print("Ensuring PostgreSQL client is installed on EC2.", flush=True)
        remote("command -v psql >/dev/null || sudo dnf install -y postgresql17 >/dev/null")
        helper = base64.b64encode((scripts / "database_host.py").read_bytes()).decode()
        remote_python = "python3 -c " + shlex.quote("import base64;exec(base64.b64decode('" + helper + "'))")
        request = {"mode": "preflight", "host": values["rds_address"], "port": values["rds_port"],
                   "region": region, "admin": {"username": admin["username"], "password": admin["password"]},
                   "applications": applications, "sql": (scripts / "initialize_databases.sql").read_text(),
                   "expected_role": f"arn:aws:sts::{account}:assumed-role/8byte-devops-application/"}
        print("Preflight:", remote(remote_python, json.dumps(request)).strip(), flush=True)
        for environment, credentials in applications.items():
            if not credentials["already_stored"]:
                path = os.path.join(directory, environment + ".json")
                with open(path, "w", opener=lambda name, flags: os.open(name, flags, 0o600)) as stream:
                    json.dump({key: credentials[key] for key in ["engine", "host", "port", "dbname", "username", "password"]}, stream)
                try:
                    aws("secretsmanager", "put-secret-value", "--secret-id", credentials["secret_arn"], "--secret-string", "file://" + path)
                finally:
                    os.unlink(path)
                credentials["already_stored"] = True
            print(environment + " credentials stored; values hidden.", flush=True)
        # Persist credentials first so a partially completed initialization can resume.
        request["mode"] = "initialize"
        print("Database checks:", remote(remote_python, json.dumps(request)).strip(), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        raise SystemExit(str(error) if isinstance(error, RuntimeError) else "Initialization failed: " + type(error).__name__)
