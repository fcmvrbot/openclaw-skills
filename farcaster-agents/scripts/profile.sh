#!/usr/bin/env bash

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'EOF' >&2
Usage: profile.sh [--fid <fid> | --name <name> | --wallet <wallet> | --fids <fid,fid,...>] [--token-ca <tokenCA>] [--bot <name>]

Fetches profiles through /api/profile. GET requests hit the query string so keep fids <= 50.
EOF
  exit 1
}

fid=""
name=""
wallet=""
fids=""
token_ca=""
bot_name=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fid)
      shift
      fid="$1"
      ;;
    --name)
      shift
      name="$1"
      ;;
    --wallet)
      shift
      wallet="$1"
      ;;
    --fids)
      shift
      fids="$1"
      ;;
    --token-ca)
      shift
      token_ca="$1"
      ;;
    --bot)
      shift
      bot_name="$1"
      ;;
    *)
      usage
      ;;
  esac
  shift || break
done

if [[ -z "$fid" && -z "$name" && -z "$wallet" && -z "$fids" ]]; then
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
bot_base_url="$(jq -r --arg name "$bot_name" '.bots[] | select(.name == $name) | .baseUrl // empty' "$config_file")"
if [[ -n "$bot_base_url" && "$bot_base_url" != "null" ]]; then
  base_url="$bot_base_url"
fi

if [[ -z "$api_key" ]]; then
  echo "apiKey missing for bot '$bot_name' in config.json" >&2
  exit 1
fi

params=()
[[ -n "$fid" ]] && params+=(--data-urlencode "fid=$fid")
[[ -n "$name" ]] && params+=(--data-urlencode "name=$name")
[[ -n "$wallet" ]] && params+=(--data-urlencode "wallet=$wallet")
[[ -n "$fids" ]] && params+=(--data-urlencode "fids=$fids")
[[ -n "$token_ca" ]] && params+=(--data-urlencode "tokenCA=$token_ca")

curl --fail --show-error -sS \
  -G "${base_url}/api/profile" \
  "${params[@]}" \
  -H "x-api-key: ${api_key}"
