#!/usr/bin/env bash

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'EOF' >&2
Usage: dickbot-post.sh --text "<text>" [--fid <fid>] [--hash <hash>] [--channel <channelId>] [--disable-already-answered]

Publishes a cast/reply as the configured bot (use `config.json` to change the fid/name). Omitting fid/hash creates an original cast.
EOF
  exit 1
}

text=""
target_fid=""
target_hash=""
channel_id=""
disable_already_answered=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --text)
      shift
      text="$1"
      ;;
    --fid)
      shift
      target_fid="$1"
      ;;
    --hash)
      shift
      target_hash="$1"
      ;;
    --channel)
      shift
      channel_id="$1"
      ;;
    --disable-already-answered)
      disable_already_answered=true
      ;;
    *)
      usage
      ;;
  esac
  shift || break
done

if [[ -z "$text" ]]; then
  echo "text is required" >&2
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

payload="$(jq -n \
  --arg action "post" \
  --arg text "$text" \
  --arg channel "$channel_id" \
  --arg fid "$target_fid" \
  --arg hash "$target_hash" \
  --argjson disable "$disable_already_answered" \
  '{
    action: $action,
    text: $text,
    disableAlreadyAnsweredCheck: $disable
  }
  | if ($fid != "") or ($hash != "") then
      .target = ({} | if ($fid != "") then .fid = ($fid | tonumber) else . end | if ($hash != "") then .hash = $hash else . end)
    else .
    end
  | if $channel != "" then .channelId = $channel else . end'
)"

curl --fail --show-error -sS \
  -X POST "${base_url}/api/farcaster/bots/${bot_fid}" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${api_key}" \
  -d "$payload"
