#!/usr/bin/env bash

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'EOF' >&2
Usage: profile.sh [--fid <fid> | --name <name> | --wallet <wallet> | --fids <fid,fid,...>] [--token-ca <tokenCA>]

Fetches profiles through /api/profile. GET requests hit the query string so keep fids <= 50.
EOF
  exit 1
}

fid=""
name=""
wallet=""
fids=""
token_ca=""

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

api_key="$(jq -r '.apiKey // empty' "$config_file")"
base_url="$(jq -r '.baseUrl // "https://api.farclaw.com"' "$config_file")"

if [[ -z "$api_key" ]]; then
  echo "apiKey missing from config.json" >&2
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
