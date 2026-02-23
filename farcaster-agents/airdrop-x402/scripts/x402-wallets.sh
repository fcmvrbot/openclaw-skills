#!/usr/bin/env bash

unset BASH_ENV
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/../config.json"

usage() {
  cat <<'EOF' >&2
Usage: x402-wallets.sh --source <source> [options]

Calls /api/airdrop/x402/wallets (GET or POST) using x-api-key, x402 proof, or on-chain payment lookup.

Required:
  --source <source>

Options:
  --limit <1-1000>
  --cursor <n>
  --params-json <json-object>
  --method <GET|POST>                (default: GET)
  --auth <auto|api-key|x402-proof|onchain|none> (default: auto)
  --payer <0x...>                    (used for on-chain payment check)
  --reference-id <0x...>             (optional; endpoint can derive if omitted)
  --client <name>                    (config client profile)
  --bot <name>                       (alias for --client)
  --raw                              (do not pretty-print JSON)

Examples:
  x402-wallets.sh --source vibeshift_affinity --params-json '{"fid":2629848}' --limit 100
  x402-wallets.sh --source followers --params-json '{"fid":2629848,"top":500}' --auth none
  x402-wallets.sh --source poap_event --params-json '{"eventId":12345}' --method POST --client shared
EOF
  exit 1
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 not installed or not in PATH" >&2
    exit 1
  fi
}

source_name=""
limit=""
cursor=""
params_json=""
method="GET"
auth_mode="auto"
payer=""
reference_id=""
client_name=""
raw_output=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      shift
      source_name="${1:-}"
      ;;
    --limit)
      shift
      limit="${1:-}"
      ;;
    --cursor)
      shift
      cursor="${1:-}"
      ;;
    --params-json)
      shift
      params_json="${1:-}"
      ;;
    --method)
      shift
      method="${1:-}"
      ;;
    --auth)
      shift
      auth_mode="${1:-}"
      ;;
    --payer)
      shift
      payer="${1:-}"
      ;;
    --reference-id)
      shift
      reference_id="${1:-}"
      ;;
    --client|--bot)
      shift
      client_name="${1:-}"
      ;;
    --raw)
      raw_output=true
      ;;
    *)
      usage
      ;;
  esac
  shift || break
done

[[ -z "$source_name" ]] && usage

need_cmd curl
need_cmd jq

if [[ ! -f "$config_file" ]]; then
  echo "config.json not found at $config_file" >&2
  exit 1
fi

base_url="$(jq -r '.baseUrl // "https://api.farclaw.com"' "$config_file")"
request_timeout="$(jq -r '.requestTimeoutSeconds // 60' "$config_file")"
connect_timeout="$(jq -r '.connectTimeoutSeconds // 10' "$config_file")"
default_client="$(jq -r '.defaultClient // empty' "$config_file")"
client_count="$(jq -r '.clients | length // 0' "$config_file")"

if [[ -z "$client_name" ]]; then
  if [[ -n "$default_client" && "$default_client" != "null" ]]; then
    client_name="$default_client"
  elif [[ "$client_count" -eq 1 ]]; then
    client_name="$(jq -r '.clients[0].name // empty' "$config_file")"
  fi
fi

client_entry=""
if [[ -n "$client_name" ]]; then
  client_entry="$(jq -c --arg name "$client_name" '.clients[] | select(.name == $name)' "$config_file" || true)"
  if [[ -z "$client_entry" ]]; then
    echo "client '$client_name' not found in config.json" >&2
    exit 1
  fi
fi

api_key=""
x402_proof=""
client_base_url=""
client_request_timeout=""
client_connect_timeout=""
if [[ -n "$client_entry" ]]; then
  api_key="$(jq -r --arg name "$client_name" '.clients[] | select(.name == $name) | .apiKey // empty' "$config_file")"
  x402_proof="$(jq -r --arg name "$client_name" '.clients[] | select(.name == $name) | .x402Proof // empty' "$config_file")"
  client_base_url="$(jq -r --arg name "$client_name" '.clients[] | select(.name == $name) | .baseUrl // empty' "$config_file")"
  client_request_timeout="$(jq -r --arg name "$client_name" '.clients[] | select(.name == $name) | .requestTimeoutSeconds // empty' "$config_file")"
  client_connect_timeout="$(jq -r --arg name "$client_name" '.clients[] | select(.name == $name) | .connectTimeoutSeconds // empty' "$config_file")"
fi

if [[ -n "$client_base_url" && "$client_base_url" != "null" ]]; then
  base_url="$client_base_url"
fi
if [[ -n "$client_request_timeout" && "$client_request_timeout" != "null" ]]; then
  request_timeout="$client_request_timeout"
fi
if [[ -n "$client_connect_timeout" && "$client_connect_timeout" != "null" ]]; then
  connect_timeout="$client_connect_timeout"
fi

method="$(printf '%s' "$method" | tr '[:lower:]' '[:upper:]')"
case "$method" in
  GET|POST) ;;
  *) echo "invalid --method: $method (use GET or POST)" >&2; exit 1 ;;
esac

case "$auth_mode" in
  auto|api-key|x402-proof|onchain|none) ;;
  *) echo "invalid --auth: $auth_mode" >&2; exit 1 ;;
esac

params_json="${params_json:-{}}"
if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$params_json"; then
  echo "--params-json must be a JSON object" >&2
  exit 1
fi

endpoint="${base_url%/}/api/airdrop/x402/wallets"

declare -a headers
headers=(-H "Accept: application/json")
if [[ "$auth_mode" == "auto" || "$auth_mode" == "api-key" ]]; then
  if [[ -n "$api_key" ]]; then
    headers+=(-H "x-api-key: ${api_key}")
  elif [[ "$auth_mode" == "api-key" ]]; then
    echo "apiKey missing for client '${client_name:-<none>}'" >&2
    exit 1
  fi
fi

if [[ "$auth_mode" == "x402-proof" ]]; then
  if [[ -z "$x402_proof" ]]; then
    echo "x402Proof missing for client '${client_name:-<none>}'" >&2
    exit 1
  fi
  headers+=(-H "x-x402-proof: ${x402_proof}")
elif [[ "$auth_mode" == "auto" && -z "$api_key" && -n "$x402_proof" ]]; then
  headers+=(-H "x-x402-proof: ${x402_proof}")
fi

tmp_body="$(mktemp /tmp/x402-wallets-body.XXXXXX)"
cleanup() {
  rm -f "$tmp_body"
}
trap cleanup EXIT

http_code=""
if [[ "$method" == "GET" ]]; then
  declare -a params
  params=(--data-urlencode "source=$source_name" --data-urlencode "params=$params_json")
  [[ -n "$limit" ]] && params+=(--data-urlencode "limit=$limit")
  [[ -n "$cursor" ]] && params+=(--data-urlencode "cursor=$cursor")
  [[ -n "$payer" ]] && params+=(--data-urlencode "payer=$payer")
  [[ -n "$reference_id" ]] && params+=(--data-urlencode "referenceId=$reference_id")

  http_code="$(curl -sS --connect-timeout "${connect_timeout}" --max-time "${request_timeout}" \
    -o "$tmp_body" -w '%{http_code}' \
    -G "$endpoint" \
    "${params[@]}" \
    "${headers[@]}")"
else
  payload="$(jq -cn \
    --arg source "$source_name" \
    --arg limit "$limit" \
    --arg cursor "$cursor" \
    --arg payer "$payer" \
    --arg referenceId "$reference_id" \
    --argjson params "$params_json" \
    '
      {
        source: $source,
        params: $params
      }
      + (if $limit != "" then {limit: ($limit | tonumber)} else {} end)
      + (if $cursor != "" then {cursor: ($cursor | tonumber)} else {} end)
      + (if $payer != "" then {payer: $payer} else {} end)
      + (if $referenceId != "" then {referenceId: $referenceId} else {} end)
    ')"

  http_code="$(curl -sS --connect-timeout "${connect_timeout}" --max-time "${request_timeout}" \
    -o "$tmp_body" -w '%{http_code}' \
    -X POST "$endpoint" \
    -H "Content-Type: application/json" \
    "${headers[@]}" \
    -d "$payload")"
fi

if [[ "$raw_output" == true ]]; then
  cat "$tmp_body"
else
  if jq -e . >/dev/null 2>&1 <"$tmp_body"; then
    jq . <"$tmp_body"
  else
    cat "$tmp_body"
  fi
fi

case "$http_code" in
  2*|402)
    # 402 is expected when probing for x402 payment requirements.
    exit 0
    ;;
  *)
    echo "HTTP $http_code" >&2
    exit 1
    ;;
esac

