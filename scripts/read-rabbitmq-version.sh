#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
DOCKERFILE="${1:-$ROOT_DIR/Dockerfile}"

mapfile -t base_images < <(sed -nE 's/^[[:space:]]*[Ff][Rr][Oo][Mm][[:space:]]+//p' "$DOCKERFILE")
if [ "${#base_images[@]}" -ne 1 ] || \
  [[ ! "${base_images[0]}" =~ ^rabbitmq:(4\.2\.[0-9]+)-management-alpine@sha256:[0-9a-f]{64}$ ]]; then
  echo "Expected one literal, digest-pinned rabbitmq:4.2.x-management-alpine FROM in ${DOCKERFILE}" >&2
  exit 1
fi

printf '%s\n' "${BASH_REMATCH[1]}"
