#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

if [[ ! -f "$config_file" ]]; then
  echo "config.json not found at $config_file" >&2
  exit 1
fi

BASE_URL="$(jq -r '.baseUrl // "https://ncvpsapi.onchain.cooking/api"' "$config_file")"
API_KEY="$(jq -r '.apiKey // empty' "$config_file")"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl not installed or not in PATH" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not installed or not in PATH" >&2
  exit 1
fi

declare -a ENDPOINTS=(
  "airdrop/leaderboard?limit=3|airdrop leaderboard snapshot (limited)"
  "airdrop/embeds?summary=true|mini app embeds summary"
  "airdrop/quotient/reputation?fids=1,2,3|quotient reputation for sample fids"
  "farcaster/blocks?fid=1&limit=2|latest Warpcast blocks"
  "farcaster/cast?hash=0x0000000000000000000000000000000000000000000000000000000000000000|cast detail (example hash)"
  "farcaster/rewards?fid=1|reward info for fid 1"
  "farcaster/wallets?fids=1|wallets for fid 1"
  "inflynce?fids=1,2|mindshare for sample fids"
  "littlewins?mode=leaderboard&limit=5|little wins leaderboard"
  "nft|list stored NFTs"
  "notifs/tokens?miniapp=airdrop|notification tokens page (requires auth if deployed)"
  "quotient/leaderboard?leaderboardName=default&limit=5|quotient leaderboard"
  "rewardr/claims?fid=1&includeTokenInfo=1|rewardr claims for fid"
  "stash?limit=1|stash GET requires id/token, POST not run"
  "vibeshift/feed?fid=1&limit=2|basic vibeshift feed"
  "warpl/status?fid=1|warpl status for fid 1"
)

echo "Using base URL: $BASE_URL"

for entry in "${ENDPOINTS[@]}"; do
  path="${entry%%|*}"
  label="${entry#*|}"
  url="$BASE_URL/$path"

  echo
  echo "==== $label ===="
  echo "GET $url"

  cmd=(curl -sS "$url" -H "Accept: application/json")
  if [[ -n "$API_KEY" ]]; then
    cmd+=(-H "x-api-key: $API_KEY")
  fi

  if ! response="$("${cmd[@]}")"; then
    echo "request failed for $path" >&2
    continue
  fi

  if jq -e . >/dev/null 2>&1 <<<"$response"; then
    jq . <<<"$response"
  else
    echo "$response"
  fi
done
