#!/bin/bash
# Runs ON THE EC2 HOST. Replaces one environment's PetClinic container with
# the given image, and puts the previous image back if the new one is unhealthy.
#
# Usage: deploy.sh <staging|production> <image> <aws-region>
#
# The host's own IAM role pulls the image and reads the database secret, so
# no credentials travel from the pipeline to the host.
set -euo pipefail

PROJECT="8byte-devops"

start_container() {
  local image="$1"
  sudo docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  # Each environment has its own name, network, host port and limits, so a
  # deployment of one environment never touches the other's container.
  sudo docker run -d \
    --name "$CONTAINER" \
    --network "$NETWORK" \
    --publish "$PORT:8080" \
    --memory 768m \
    --cpus 0.75 \
    --restart unless-stopped \
    --env-file "$ENV_FILE" \
    "$image" >/dev/null
}

# Healthy means the health endpoint reports UP (which includes the database
# connection) and a page that reads from the database loads.
wait_until_healthy() {
  local attempt
  for attempt in $(seq 1 36); do
    if curl -fsS "http://localhost:$PORT/actuator/health" 2>/dev/null | grep -q '"status":"UP"'; then
      curl -fsS -o /dev/null "http://localhost:$PORT/owners?lastName="
      return
    fi
    # A restart count above zero means the application crashed on startup.
    if [ "$(sudo docker inspect -f '{{.RestartCount}}' "$CONTAINER" 2>/dev/null || echo 1)" -gt 0 ]; then
      return 1
    fi
    sleep 5
  done
  return 1
}

# Runs when the script ends for any reason, so neither the registry token nor
# the database settings file is left on the host after a failure.
cleanup() {
  rm -f "${ENV_FILE:-}"
  sudo rm -rf "${DOCKER_AUTH_DIR:-}"
}

main() {
  ENVIRONMENT="$1"
  IMAGE="$2"
  REGION="$3"

  case "$ENVIRONMENT" in
    staging) PORT=8081 ;;
    production) PORT=8082 ;;
    *)
      echo "Unknown environment: $ENVIRONMENT" >&2
      exit 1
      ;;
  esac

  CONTAINER="petclinic-$ENVIRONMENT"
  NETWORK="$ENVIRONMENT-net"
  REGISTRY="${IMAGE%%/*}"
  trap cleanup EXIT

  # Remember what is running now so it can be restored.
  PREVIOUS_IMAGE="$(sudo docker inspect -f '{{.Config.Image}}' "$CONTAINER" 2>/dev/null || true)"

  echo "Pulling $IMAGE"
  # The registry token is kept in a private directory for this run only, not
  # in the host's shared Docker settings, so a staging and a production
  # deployment running at the same time cannot disturb each other. docker
  # login warns about storing the token on disk; cleanup removes it, so only
  # a real failure is reported.
  DOCKER_AUTH_DIR="$(mktemp -d)"
  if ! aws ecr get-login-password --region "$REGION" |
    sudo docker --config "$DOCKER_AUTH_DIR" login --username AWS --password-stdin "$REGISTRY" >/dev/null 2>&1; then
    echo "ECR login failed for $REGISTRY" >&2
    exit 1
  fi
  # If the pull fails the script stops here, before the running container is touched.
  sudo docker --config "$DOCKER_AUTH_DIR" pull --quiet "$IMAGE" >/dev/null

  # The container's settings go into a private temporary file that cleanup
  # removes. The values are never printed. Of the management endpoints, only
  # health is switched on, without internal details.
  ENV_FILE="$(mktemp)"
  aws secretsmanager get-secret-value --region "$REGION" \
    --secret-id "$PROJECT/$ENVIRONMENT/database" --query SecretString --output text |
    jq -r '"SPRING_PROFILES_ACTIVE=postgres",
           "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health",
           "MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS=never",
           "POSTGRES_URL=jdbc:postgresql://\(.host):\(.port)/\(.dbname)",
           "POSTGRES_USER=\(.username)",
           "POSTGRES_PASS=\(.password)"' >"$ENV_FILE"

  sudo docker network inspect "$NETWORK" >/dev/null 2>&1 ||
    sudo docker network create "$NETWORK" >/dev/null

  # Both a container that cannot start and one that starts but never becomes
  # healthy count as a failed deployment and lead to the rollback below.
  echo "Starting $CONTAINER on port $PORT"
  if start_container "$IMAGE" && wait_until_healthy; then
    echo "$CONTAINER is healthy on $IMAGE"
    exit 0
  fi

  echo "$CONTAINER did not become healthy. Last log lines:" >&2
  sudo docker logs --tail 40 "$CONTAINER" >&2 || true

  # Put back whatever was running before, even if it is the same image: a
  # failed redeployment must not leave the environment without a container.
  # This restores the application image only, never the database contents.
  if [ -n "$PREVIOUS_IMAGE" ]; then
    echo "Rolling back to $PREVIOUS_IMAGE" >&2
    if start_container "$PREVIOUS_IMAGE" && wait_until_healthy; then
      echo "Rollback succeeded: $CONTAINER is healthy on $PREVIOUS_IMAGE" >&2
    else
      echo "Rollback failed: $CONTAINER is not healthy" >&2
    fi
  fi
  exit 1
}

# The script arrives over SSH on standard input. Calling main on the last
# line makes bash read the whole script before it runs any of it.
main "$@"
