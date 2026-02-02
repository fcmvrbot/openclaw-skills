#!/usr/bin/env bash

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'EOF' >&2
Usage: latest-casts.sh --fid <fid> [--limit <1-200>] [--cursor <cursor>] [--since <cursorOrDate>] [--include-replies <true|false>] [--replies-only]

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

api_key="$(jq -r '.apiKey // empty' "$config_file")"
base_url="$(jq -r '.baseUrl // "https://api.farclaw.com"' "$config_file")"

if [[ -z "$api_key" ]]; then
  echo "apiKey missing from config.json" >&2
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
