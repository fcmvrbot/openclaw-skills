#!/usr/bin/env bash

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'USAGE' >&2
Usage: vibeshift-feed-by-fids.sh --fids <fid1,fid2,...> [--limit <1-200>] [--cursor <cursor>] [--bot <name>]

Fetches /api/vibeshift/feedByFids with an explicit fid list.
USAGE
  exit 1
}

fids=""
limit=""
cursor=""
bot_name=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fids)
      shift
      fids="$1"
      ;;
    --limit)
      shift
      limit="$1"
      ;;
    --cursor)
      shift
      cursor="$1"
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

if [[ -z "$fids" ]]; then
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

payload="$(jq -c \
  --arg fids "$fids" \
  --arg limit "$limit" \
  --arg cursor "$cursor" \
  'def to_num_array($raw):
      ($raw | split(",") | map(tonumber?) | map(select(. != null and . > 0)) | unique);
    {
      fids: to_num_array($fids)
    }
    + (if $limit != "" then { limit: ($limit | tonumber?) } else {} end)
    + (if $cursor != "" then { cursor: $cursor } else {} end)
  ')
"

if [[ "$payload" == "" ]]; then
  echo "failed to build request payload" >&2
  exit 1
fi

curl --fail --show-error -sS \
  -X POST "${base_url}/api/vibeshift/feedByFids" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${api_key}" \
  -d "$payload"
