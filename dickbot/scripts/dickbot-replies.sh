#!/usr/bin/env bash

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'EOF' >&2
Usage: dickbot-replies.sh --target-fid <fid> [--limit <1-200>] [--cursor <cursor>]

Returns replies whose target is the supplied fid via /api/vibeshift/replies-to-target.
EOF
  exit 1
}

target_fid=""
limit=""
cursor=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-fid)
      shift
      target_fid="$1"
      ;;
    --limit)
      shift
      limit="$1"
      ;;
    --cursor)
      shift
      cursor="$1"
      ;;
    *)
      usage
      ;;
  esac
  shift || break
done

if [[ -z "$target_fid" ]]; then
  echo "target-fid is required" >&2
  usage
fi

if [[ ! -f "$config_file" ]]; then
  echo "config.json not found at $config_file" >&2
  exit 1
fi

api_key="$(jq -r '.apiKey // empty' "$config_file")"
base_url="$(jq -r '.baseUrl // "https://ham.cooking"' "$config_file")"

if [[ -z "$api_key" ]]; then
  echo "apiKey missing from config.json" >&2
  exit 1
fi

params=(--data-urlencode "targetFid=$target_fid")
[[ -n "$limit" ]] && params+=(--data-urlencode "limit=$limit")
[[ -n "$cursor" ]] && params+=(--data-urlencode "cursor=$cursor")

curl --fail --show-error -sS \
  -G "${base_url}/api/vibeshift/replies-to-target" \
  "${params[@]}" \
  -H "x-api-key: ${api_key}"
