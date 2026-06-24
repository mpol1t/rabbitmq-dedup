#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-rabbitmq-dedup:local}"

trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --format table \
  --no-progress \
  "$IMAGE"
