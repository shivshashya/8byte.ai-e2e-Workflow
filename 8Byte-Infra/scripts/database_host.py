"""Internal SSH helper: receive credentials on stdin; never echo SQL/passwords."""
import json
import os
import re
import subprocess
import sys
import tempfile
import uuid


def main():
    request = json.load(sys.stdin)
    admin = request["admin"]
    applications = request["applications"]
    with tempfile.TemporaryDirectory(prefix="petclinic-db-") as directory:
        passfile = os.path.join(directory, "pgpass")

        def escape(value):
            return str(value).replace("\\", "\\\\").replace(":", "\\:")

        with open(passfile, "w", opener=lambda path, flags: os.open(path, flags, 0o600)) as stream:
            for credentials in [admin] + list(applications.values()):
                stream.write(":".join(escape(value) for value in [
                    request["host"], request["port"], "*",
                    credentials["username"], credentials["password"],
                ]) + "\n")

        def psql(user, database, sql, sslmode="prefer", expect_denied=False):
            environment = os.environ.copy()
            environment.update({
                "PGHOST": request["host"], "PGPORT": str(request["port"]),
                "PGUSER": user, "PGPASSFILE": passfile, "PGSSLMODE": sslmode,
                "PGCONNECT_TIMEOUT": "10", "PGAPPNAME": "petclinic-db-setup",
            })
            environment.pop("PGPASSWORD", None)
            result = subprocess.run([
                "psql", "-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1",
                "--dbname", database,
            ], input=sql, text=True, capture_output=True, env=environment, timeout=90)
            if expect_denied:
                if result.returncode == 0 or "permission denied for database" not in result.stderr:
                    raise RuntimeError("Cross-database check did not return the expected access denial")
            elif result.returncode:
                # Error text can contain SQL/passwords. Keep it out of logs.
                raise RuntimeError("PostgreSQL operation failed; SQL and credentials suppressed")
            return result.stdout.strip()

        inventory = json.loads(psql(admin["username"], "postgres", """
SELECT json_build_object(
  'databases', (SELECT coalesce(json_object_agg(datname, pg_get_userbyid(datdba)), '{}'::json)
    FROM pg_database WHERE datname IN ('app_staging', 'app_production')),
  'roles', (SELECT coalesce(json_object_agg(rolname,
    json_build_object('super', rolsuper, 'createdb', rolcreatedb,
      'createrole', rolcreaterole, 'replication', rolreplication, 'bypassrls', rolbypassrls)), '{}'::json)
    FROM pg_roles WHERE rolname IN ('staging_user', 'production_user')),
  'memberships', (SELECT count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member
    WHERE r.rolname IN ('staging_user', 'production_user')),
  'logging_safe', current_setting('log_statement') = 'none'
    AND current_setting('log_min_duration_statement') = '-1'
    AND current_setting('log_min_duration_sample') = '-1'
    AND coalesce(current_setting('pgaudit.log', true), 'none') IN ('none', '')
);
"""))
        for environment, credentials in applications.items():
            owner = inventory["databases"].get(credentials["dbname"])
            if owner and owner != credentials["username"]:
                raise RuntimeError("Existing database has an unexpected owner; no initialization performed")
            role = inventory["roles"].get(credentials["username"])
            if role and (any(role.values()) or not credentials["already_stored"]):
                raise RuntimeError("Existing role has unexpected privileges or no stored credentials")
        if inventory["memberships"]:
            raise RuntimeError("Existing application role memberships require review")
        if not inventory["logging_safe"]:
            raise RuntimeError("Statement logging must be reviewed before credential initialization")
        if request["mode"] == "preflight":
            print(json.dumps({"admin_connection": "PASS", "preflight": "PASS"}))
            return

        # Prove the instance role can read exactly the application secret values.
        caller = subprocess.run(["aws", "sts", "get-caller-identity", "--output", "json"],
                                text=True, capture_output=True, timeout=30)
        if caller.returncode or request["expected_role"] not in json.loads(caller.stdout)["Arn"]:
            raise RuntimeError("Host is not using the expected EC2 instance role")
        for credentials in applications.values():
            result = subprocess.run([
                "aws", "secretsmanager", "get-secret-value", "--region", request["region"],
                "--secret-id", credentials["secret_arn"], "--query", "SecretString", "--output", "text",
            ], text=True, capture_output=True, timeout=30)
            if result.returncode:
                raise RuntimeError("EC2 could not retrieve application credentials")
            stored = json.loads(result.stdout)
            if any(stored[key] != credentials[key] for key in ["dbname", "username", "password"]):
                raise RuntimeError("Application secret changed during initialization; retry after review")

        def psql_value(value):
            return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"

        prelude = (
            "\\set admin_user " + psql_value(admin["username"]) + "\n"
            "\\set staging_password " + psql_value(applications["staging"]["password"]) + "\n"
            "\\set production_password " + psql_value(applications["production"]["password"]) + "\n"
        )
        psql(admin["username"], "postgres", prelude + request["sql"])
        checks = {}
        for environment, credentials in applications.items():
            user, database = credentials["username"], credentials["dbname"]
            identity = psql(user, database, "SELECT current_database() || ':' || current_user;")
            if identity != database + ":" + user:
                raise RuntimeError("Unexpected application database identity")
            if psql(user, database, "SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid();", sslmode="disable") != "f":
                raise RuntimeError("Non-TLS connectivity check failed")
            other = applications["production" if environment == "staging" else "staging"]["dbname"]
            psql(user, other, "SELECT 1;", expect_denied=True)
            # Separate connections prove persistence, then remove the test object.
            table = "public.infra_check_" + uuid.uuid4().hex
            created = False
            try:
                psql(user, database, f"CREATE TABLE {table} (value text); INSERT INTO {table} VALUES ('persisted');")
                created = True
                if psql(user, database, f"SELECT value FROM {table};") != "persisted":
                    raise RuntimeError("Data persistence check failed")
            finally:
                if created:
                    psql(user, database, f"DROP TABLE {table};")
            checks[environment] = {
                "own_database": "PASS", "cross_database_denied": "PASS",
                "non_tls": "PASS", "persistence_and_cleanup": "PASS",
            }
        print(json.dumps({"host_secret_read": "PASS", "checks": checks}))


try:
    main()
except (RuntimeError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
    # These messages are fixed strings or type names, never command/SQL dumps.
    print(str(error) if isinstance(error, RuntimeError) else "Database setup failed: " + type(error).__name__, file=sys.stderr)
    sys.exit(1)
