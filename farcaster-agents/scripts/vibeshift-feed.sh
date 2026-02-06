#!/usr/bin/env bash

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'USAGE' >&2
Usage: vibeshift-feed.sh --fid <fid> [--limit <1-200>] [--cursor <cursor>] [--deleted <true|false>] [--only-deleted <true|false>] [--feed-type <affinity>] [--affinity <true>] [--affinity-limit <n>] [--bot <name>]

Fetches /api/vibeshift/feed with optional pagination and affinity flags.
USAGE
  exit 1
}

fid=""
limit=""
cursor=""
deleted=""
only_deleted=""
feed_type=""
affinity=""
affinity_limit=""
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
    --deleted)
      shift
      deleted="$1"
      ;;
    --only-deleted)
      shift
      only_deleted="$1"
      ;;
    --feed-type)
      shift
      feed_type="$1"
      ;;
    --affinity)
      shift
      affinity="$1"
      ;;
    --affinity-limit)
      shift
      affinity_limit="$1"
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
[[ -n "$deleted" ]] && params+=(--data-urlencode "deleted=$deleted")
[[ -n "$only_deleted" ]] && params+=(--data-urlencode "onlyDeleted=$only_deleted")
[[ -n "$feed_type" ]] && params+=(--data-urlencode "feedType=$feed_type")
[[ -n "$affinity" ]] && params+=(--data-urlencode "affinity=$affinity")
[[ -n "$affinity_limit" ]] && params+=(--data-urlencode "affinityLimit=$affinity_limit")

curl --fail --show-error -sS \
  -G "${base_url}/api/vibeshift/feed" \
  "${params[@]}" \
  -H "x-api-key: ${api_key}"
