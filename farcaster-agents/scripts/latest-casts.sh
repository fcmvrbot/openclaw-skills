#!/usr/bin/env bash

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'EOF' >&2
Usage: latest-casts.sh --fid <fid> [--limit <1-200>] [--cursor <cursor>] [--since <cursorOrDate>] [--include-replies <true|false>] [--replies-only] [--bot <name>]

Fetches /api/vibeshift/latestCastsByFid with optional pagination and reply filtering.
EOF
  exit 1
}

fid=""
limit=""
cursor=""
since=""
include_replies=""
replies_only=false
bot_name=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fid)
      shift
      fid="$1"
      ;;
    --limit)
      shift
      limit="$1"
      ;;
    --cursor)
      shift
      cursor="$1"
      ;;
    --since)
      shift
      since="$1"
      ;;
    --include-replies)
      shift
      include_replies="$1"
      ;;
    --replies-only)
      replies_only=true
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

if [[ -z "$fid" ]]; then
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

params=(--data-urlencode "fid=$fid")
[[ -n "$limit" ]] && params+=(--data-urlencode "limit=$limit")
[[ -n "$cursor" ]] && params+=(--data-urlencode "cursor=$cursor")
[[ -n "$since" ]] && params+=(--data-urlencode "since=$since")
[[ -n "$include_replies" ]] && params+=(--data-urlencode "includeReplies=$include_replies")
if [[ "$replies_only" == true ]]; then
  params+=(--data-urlencode "repliesOnly=1")
fi

curl --fail --show-error -sS \
  -G "${base_url}/api/vibeshift/latestCastsByFid" \
  "${params[@]}" \
  -H "x-api-key: ${api_key}"
