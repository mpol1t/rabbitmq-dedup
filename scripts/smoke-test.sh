#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-rabbitmq-dedup:test}"
CONTAINER_NAME="rabbitmq-dedup-smoke-${RANDOM}-${RANDOM}"
RABBITMQ_USER="${RABBITMQ_USER:-smoke}"
RABBITMQ_PASS="${RABBITMQ_PASS:-smoke-test-password}"
WAIT_SECONDS="${WAIT_SECONDS:-90}"
EXPECTED_RABBITMQ_VERSION="${EXPECTED_RABBITMQ_VERSION:-4.2.7}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-}"
START_TIME=$(date +%s)
TMP_DIR=$(mktemp -d)
DOCKER_RUN_ARGS=()

if [ -n "$DOCKER_PLATFORM" ]; then
  DOCKER_RUN_ARGS+=(--platform "$DOCKER_PLATFORM")
fi

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

dump_logs() {
  echo "Container logs for ${CONTAINER_NAME}:" >&2
  docker logs "$CONTAINER_NAME" >&2 || true
}

cleanup() {
  rm -rf "$TMP_DIR"
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

trap 'status=$?; if [ $status -ne 0 ]; then dump_logs; fi; cleanup' EXIT

require_command curl
require_command docker
require_command python3

rabbitmqadmin() {
  docker exec "$CONTAINER_NAME" rabbitmqadmin \
    --non-interactive \
    -u "$RABBITMQ_USER" \
    -p "$RABBITMQ_PASS" \
    --host localhost \
    --port 15672 \
    --vhost / \
    "$@"
}

docker run -d \
  --name "$CONTAINER_NAME" \
  -e "RABBITMQ_DEFAULT_USER=${RABBITMQ_USER}" \
  -e "RABBITMQ_DEFAULT_PASS=${RABBITMQ_PASS}" \
  -p 127.0.0.1::5672 \
  -p 127.0.0.1::15672 \
  "${DOCKER_RUN_ARGS[@]}" \
  "$IMAGE" >/dev/null

MANAGEMENT_PORT=$(docker port "$CONTAINER_NAME" 15672/tcp | awk -F: '{print $2}')
AMQP_PORT=$(docker port "$CONTAINER_NAME" 5672/tcp | awk -F: '{print $2}')

echo "Started ${IMAGE} as ${CONTAINER_NAME}"
echo "Management API: http://127.0.0.1:${MANAGEMENT_PORT}"
echo "AMQP port: ${AMQP_PORT}"

until curl -fsS -u "${RABBITMQ_USER}:${RABBITMQ_PASS}" \
  "http://127.0.0.1:${MANAGEMENT_PORT}/api/overview" \
  -o "${TMP_DIR}/overview.json"; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    echo "Container exited before becoming ready" >&2
    exit 1
  fi

  if [ $(( $(date +%s) - START_TIME )) -ge "$WAIT_SECONDS" ]; then
    echo "Timed out waiting for RabbitMQ management API" >&2
    exit 1
  fi

  sleep 2
done

EXPECTED_RABBITMQ_VERSION="${EXPECTED_RABBITMQ_VERSION}" TMP_DIR="${TMP_DIR}" python3 - <<'PY'
import json
import os
from pathlib import Path

overview = json.loads(Path(os.environ["TMP_DIR"], "overview.json").read_text())
version = overview["rabbitmq_version"]
expected = os.environ["EXPECTED_RABBITMQ_VERSION"]
assert version == expected, f"unexpected RabbitMQ version: {version}"
print(f"RabbitMQ version: {version}")
PY

docker exec "$CONTAINER_NAME" rabbitmq-plugins list -e | tee "${TMP_DIR}/enabled-plugins.txt"
grep -q 'rabbitmq_message_deduplication' "${TMP_DIR}/enabled-plugins.txt"
grep -q 'rabbitmq_shovel' "${TMP_DIR}/enabled-plugins.txt"
grep -q 'rabbitmq_shovel_management' "${TMP_DIR}/enabled-plugins.txt"

rabbitmqadmin declare exchange \
  --name smoke-dedup \
  --type x-message-deduplication \
  --auto-delete true \
  --durable false \
  --arguments '{"x-cache-size":128}'

rabbitmqadmin declare queue \
  --name smoke-queue \
  --auto-delete true \
  --durable false

rabbitmqadmin declare binding \
  --source smoke-dedup \
  --destination-type queue \
  --destination smoke-queue \
  --routing-key ''

rabbitmqadmin publish message \
  --exchange smoke-dedup \
  --routing-key '' \
  --payload first \
  --properties '{"headers":{"x-deduplication-header":"abc"}}' \
  | tee "${TMP_DIR}/first-publish.txt"

rabbitmqadmin publish message \
  --exchange smoke-dedup \
  --routing-key '' \
  --payload second \
  --properties '{"headers":{"x-deduplication-header":"abc"}}' \
  | tee "${TMP_DIR}/second-publish.txt"

grep -q 'Message published and routed successfully' "${TMP_DIR}/first-publish.txt"
grep -q 'Message published but NOT routed' "${TMP_DIR}/second-publish.txt"

curl -fsS -u "${RABBITMQ_USER}:${RABBITMQ_PASS}" \
  -H 'content-type: application/json' \
  -X POST \
  "http://127.0.0.1:${MANAGEMENT_PORT}/api/queues/%2F/smoke-queue/get" \
  --data-binary '{"count":5,"ackmode":"ack_requeue_false","encoding":"auto","truncate":50000}' \
  -o "${TMP_DIR}/messages.json"

TMP_DIR="${TMP_DIR}" python3 - <<'PY'
import json
import os
from pathlib import Path

tmp_dir = Path(os.environ["TMP_DIR"])
messages = json.loads((tmp_dir / "messages.json").read_text())
assert len(messages) == 1, messages
assert messages[0]["payload"] == "first", messages
headers = messages[0]["properties"]["headers"]
assert headers["x-deduplication-header"] == "abc", messages
print("Dedup behavior verified")
PY

echo "Smoke test passed"
