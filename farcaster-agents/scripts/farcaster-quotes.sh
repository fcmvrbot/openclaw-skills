#!/usr/bin/env bash

unset BASH_ENV

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'EOF' >&2
Usage: farcaster-quotes.sh --target-fid <fid> [--limit <1-200>] [--cursor <cursor>] [--bot <name>]

Returns quotes whose target is the supplied fid via /api/vibeshift/quotes-to-target.
EOF
  exit 1
}

target_fid=""
limit=""
cursor=""
bot_name=""

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

if [[ -z "$target_fid" ]]; then
  echo "target-fid is required" >&2
  usage
fi

if [[ ! -f "$config_file" ]]; then
  echo "config.json not found at $config_file" >&2
  exit 1
fi

base_url="$(jq -r '.baseUrl // "https://ham.cooking"' "$config_file")"
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

params=(--data-urlencode "targetFid=$target_fid")
[[ -n "$limit" ]] && params+=(--data-urlencode "limit=$limit")
[[ -n "$cursor" ]] && params+=(--data-urlencode "cursor=$cursor")

response_file="$(mktemp)"
headers_file="$(mktemp)"
http_status=""

set +e
http_status="$(curl --fail --show-error -sS \
  -G "${base_url}/api/vibeshift/quotes-to-target" \
  "${params[@]}" \
  -H "x-api-key: ${api_key}" \
  -H "Accept: application/json" \
  -D "$headers_file" \
  -o "$response_file" \
  -w "%{http_code}")"
curl_exit=$?
set -e

response_body="$(cat "$response_file")"
rm -f "$response_file"

if [[ $curl_exit -ne 0 ]]; then
  printf '{"error":"request_failed","status":%s}' "${http_status:-0}"
  echo "[farcaster] request failed (curl exit ${curl_exit})" >&2
  cat "$headers_file" >&2 || true
  echo "$response_body" >&2
  rm -f "$headers_file"
  exit 1
fi

if ! echo "$response_body" | jq -e . >/dev/null 2>&1; then
  printf '{"error":"invalid_json","status":%s}' "${http_status:-0}"
  echo "[farcaster] invalid JSON response" >&2
  cat "$headers_file" >&2 || true
  echo "$response_body" >&2
  rm -f "$headers_file"
  exit 1
fi

rm -f "$headers_file"
echo "$response_body"
