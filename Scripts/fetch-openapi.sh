#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
dest="$root/Chimeling/Core/SDK/openapi.yaml"
url="https://chimeling.app/api/doc.yaml"

mkdir -p "$(dirname "$dest")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

curl -fsSL --retry 3 --retry-delay 1 "$url" -o "$tmp"

if ! grep -q '^openapi:' "$tmp"; then
	echo "fetch-openapi.sh: downloaded file is not OpenAPI YAML (missing 'openapi:' at start of a line)" >&2
	exit 1
fi

mv "$tmp" "$dest"
trap - EXIT
