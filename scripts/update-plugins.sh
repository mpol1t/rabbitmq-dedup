#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PLUGIN_RELEASE_OVERRIDE="${PLUGIN_RELEASE:-}"
PLUGIN_BUNDLE_OVERRIDE="${PLUGIN_BUNDLE:-}"
PLUGIN_SHA256_OVERRIDE="${PLUGIN_SHA256:-}"
source "$ROOT_DIR/plugins/upstream-release.env"
PLUGIN_RELEASE="${PLUGIN_RELEASE_OVERRIDE:-$PLUGIN_RELEASE}"
PLUGIN_BUNDLE="${PLUGIN_BUNDLE_OVERRIDE:-$PLUGIN_BUNDLE}"
PLUGIN_SHA256="${PLUGIN_SHA256_OVERRIDE:-$PLUGIN_SHA256}"
TMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

ARCHIVE="$TMP_DIR/plugins.zip"
EXTRACT_DIR="$TMP_DIR/extracted"
URL="https://github.com/noxdafox/rabbitmq-message-deduplication/releases/download/${PLUGIN_RELEASE}/${PLUGIN_BUNDLE}"

mkdir -p "$EXTRACT_DIR"

echo "Downloading ${URL}"
curl -fsSL "$URL" -o "$ARCHIVE"
echo "${PLUGIN_SHA256}  ${ARCHIVE}" | sha256sum -c -

unzip -qo "$ARCHIVE" -d "$EXTRACT_DIR"
find "$ROOT_DIR/plugins" -maxdepth 1 -type f -name '*.ez' -delete
install -m 0644 "$EXTRACT_DIR"/*.ez "$ROOT_DIR/plugins/"
(cd "$ROOT_DIR/plugins" && sha256sum *.ez | sort > checksums.txt)

echo "Updated plugin artifacts:"
find "$ROOT_DIR/plugins" -maxdepth 1 -type f -name '*.ez' -printf ' - %f\n' | sort
