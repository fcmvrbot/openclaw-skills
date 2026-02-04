#!/usr/bin/env bash

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'EOF' >&2
Usage: farcaster-like.sh [--bot <name>] <fid> <hash>

Posts a like on behalf of the configured bot (use `config.json` to set bot credentials). Both fid and hash are required.
EOF
  exit 1
}

bot_name=""
positional=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bot)
      shift
      bot_name="$1"
      ;;
    *)
      positional+=("$1")
      ;;
  esac
  shift || break
done

if [[ ${#positional[@]} -ne 2 ]]; then
  usage
fi

fid="${positional[0]}"
hash="${positional[1]}"

if [[ -z "$fid" || -z "$hash" ]]; then
  usage
fi

if [[ ! -f "$config_file" ]]; then
  echo "config.json not found at $config_file" >&2
  exit 1
fi

base_url="$(jq -r '.baseUrl // "https://api.farclaw.com"' "$config_file")"
default_bot="$(jq -r '.defaultBot // empty' "$config_file")"
bot_count="$(jq -r '.bots | length // 0' "$config_file")"

if [[ -z "$bot_name" ]]; then
  if [[ -n "$default_bot" && "$default_bot" != "null" ]]; then
    bot_name="$default_bot"
  elif [[ "$bot_count" -eq 1 ]]; then
    bot_name="$(jq -r '.bots[0].name // empty' "$config_file")"
  else
    echo "bot name required (use --bot <name> or set defaultBot)" >&2
    exit 1
  fi
fi

bot_entry="$(jq -c --arg name "$bot_name" '.bots[] | select(.name == $name)' "$config_file")"
if [[ -z "$bot_entry" ]]; then
  echo "bot '$bot_name' not found in config.json" >&2
  exit 1
fi

api_key="$(jq -r --arg name "$bot_name" '.bots[] | select(.name == $name) | .apiKey // empty' "$config_file")"
bot_fid="$(jq -r --arg name "$bot_name" '.bots[] | select(.name == $name) | .fid // empty' "$config_file")"
bot_base_url="$(jq -r --arg name "$bot_name" '.bots[] | select(.name == $name) | .baseUrl // empty' "$config_file")"
if [[ -n "$bot_base_url" && "$bot_base_url" != "null" ]]; then
  base_url="$bot_base_url"
fi

if [[ -z "$api_key" ]]; then
  echo "apiKey missing for bot '$bot_name' in config.json" >&2
  exit 1
fi

if [[ -z "$bot_fid" ]]; then
  echo "fid missing for bot '$bot_name' in config.json" >&2
  exit 1
fi

if ! [[ "$bot_fid" =~ ^[0-9]+$ ]]; then
  echo "fid must be a positive number in config.json" >&2
  exit 1
fi

curl --fail --show-error -sS \
  -X POST "${base_url}/api/farcaster/bots/${bot_fid}" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${api_key}" \
  -d "{\"action\":\"like\",\"target\":{\"fid\":${fid},\"hash\":\"${hash}\"}}"
