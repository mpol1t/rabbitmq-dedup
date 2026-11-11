#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TAG_NAME="${1:-}"
DOCKERFILE="$ROOT_DIR/Dockerfile"
README_FILE="$ROOT_DIR/README.md"
CHECKSUM_FILE="$ROOT_DIR/plugins/checksums.txt"
source "$ROOT_DIR/plugins/upstream-release.env"
TMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  echo "release validation failed: $*" >&2
  exit 1
}

readme_declares_version() {
  local label="$1"
  local value="$2"
  grep -Fq -- "- ${label}: \`${value}\`" "$README_FILE"
}

rabbitmq_series_version=$("$ROOT_DIR/scripts/read-rabbitmq-version.sh" "$DOCKERFILE")

grep -Fq -- "docker pull mpolit/rabbitmq-dedup:4.2-alpine" "$README_FILE" || \
  fail "README pull example does not include 4.2-alpine"

grep -Fq -- "image: mpolit/rabbitmq-dedup:4.2-alpine" "$README_FILE" || \
  fail "README compose example does not include 4.2-alpine"

mapfile -t docker_plugins < <(sed -n 's|^COPY plugins/\(.*\.ez\) .*|\1|p' "$DOCKERFILE")
[ "${#docker_plugins[@]}" -gt 0 ] || fail "no plugin artifacts declared in Dockerfile"

declare -A version_labels=(
  ["rabbitmq_message_deduplication"]="Dedup plugin"
  ["elixir"]="Elixir runtime plugin"
  ["logger"]="Logger runtime plugin"
)

for plugin in "${docker_plugins[@]}"; do
  [ -f "$ROOT_DIR/plugins/$plugin" ] || fail "missing plugin artifact plugins/$plugin"
  grep -Fq "  ${plugin}" "$CHECKSUM_FILE" || fail "checksums.txt missing entry for ${plugin}"

  plugin_name="${plugin%-*}"
  plugin_version="${plugin#${plugin_name}-}"
  plugin_version="${plugin_version%.ez}"

  if [ -n "${version_labels[$plugin_name]:-}" ]; then
    readme_declares_version "${version_labels[$plugin_name]}" "$plugin_version" || \
      fail "README ${version_labels[$plugin_name]} does not match vendored artifact ${plugin}"
  fi
done

upstream_archive="$TMP_DIR/${PLUGIN_BUNDLE}"
upstream_extract_dir="$TMP_DIR/upstream"
mkdir -p "$upstream_extract_dir"
curl -fsSL \
  "https://github.com/noxdafox/rabbitmq-message-deduplication/releases/download/${PLUGIN_RELEASE}/${PLUGIN_BUNDLE}" \
  -o "$upstream_archive"
echo "${PLUGIN_SHA256}  ${upstream_archive}" | sha256sum -c - >/dev/null
unzip -qo "$upstream_archive" -d "$upstream_extract_dir"

for plugin in "${docker_plugins[@]}"; do
  upstream_plugin="$upstream_extract_dir/$plugin"
  [ -f "$upstream_plugin" ] || fail "upstream bundle does not contain ${plugin}"
  plugin_sha="$(sha256sum "$ROOT_DIR/plugins/$plugin" | awk '{print $1}')"
  upstream_sha="$(sha256sum "$upstream_plugin" | awk '{print $1}')"
  [ "$plugin_sha" = "$upstream_sha" ] || fail "vendored plugin ${plugin} does not match upstream bundle ${PLUGIN_BUNDLE}"
done

if [ -n "$TAG_NAME" ]; then
  [[ "$TAG_NAME" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]] || fail "tag must match v<major>.<minor>.<patch>"
  tag_version="${BASH_REMATCH[1]}"
  [ "$tag_version" = "$rabbitmq_series_version" ] || \
    fail "tag version ${tag_version} does not match Dockerfile RabbitMQ version ${rabbitmq_series_version}"
fi

echo "release validation passed"
