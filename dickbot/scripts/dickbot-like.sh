#!/usr/bin/env bash

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'EOF' >&2
Usage: dickbot-like.sh <fid> <hash>

Posts a like on behalf of the configured bot (use `config.json` to set the fid/name). Both fid and hash are required.
EOF
  exit 1
}

if [[ $# -ne 2 ]]; then
  usage
fi

fid="$1"
hash="$2"

if [[ -z "$fid" || -z "$hash" ]]; then
  usage
fi

if [[ ! -f "$config_file" ]]; then
  echo "config.json not found at $config_file" >&2
  exit 1
fi

api_key="$(jq -r '.apiKey // empty' "$config_file")"
base_url="$(jq -r '.baseUrl // "https://api.farclaw.com"' "$config_file")"
bot_fid="$(jq -r '.fid // empty' "$config_file")"
bot_name="$(jq -r '.name // empty' "$config_file")"

if [[ -z "$api_key" ]]; then
  echo "apiKey missing from config.json" >&2
  exit 1
fi

if [[ -z "$bot_fid" ]]; then
  echo "fid missing in config.json" >&2
  exit 1
fi

if ! [[ "$bot_fid" =~ ^[0-9]+$ ]]; then
  echo "fid must be a positive number in config.json" >&2
  exit 1
fi

if [[ -z "$bot_name" ]]; then
  echo "name missing from config.json" >&2
  exit 1
fi

curl --fail --show-error -sS \
  -X POST "${base_url}/api/farcaster/bots/${bot_fid}" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${api_key}" \
  -d "{\"action\":\"like\",\"target\":{\"fid\":${fid},\"hash\":\"${hash}\"}}"
