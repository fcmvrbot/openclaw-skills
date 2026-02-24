---
name: airdrop-x402
description: |
  Use this skill when an agent needs to export wallet audiences for airdrops through the paid x402 endpoint (`/api/airdrop/x402/wallets`) on Snapchain infra. It provides a reusable shell client, auth/header handling (`x-api-key`, x402 proof headers, or on-chain paid lookup), and examples for each supported source (`bankr_leaderboard`, `tipn_affinity`, `vibeshift_affinity`, `poap_event`, `empire_builder`, `airdrop_leaderboard`, `followers`).
---

# Airdrop x402 Skill

Use this skill to fetch wallet lists for airdrop campaigns from the shared infra endpoint:

- `GET/POST /api/airdrop/x402/wallets`

The endpoint supports three access modes:

- `x-api-key` header (`auth.mode = "api_key"`)
- x402 payment proof header (`auth.mode = "x402_proof"`)
- on-chain paid check via `payer` + `referenceId` (`auth.mode = "onchain_paid"`)

If no valid auth/proof/payment is provided, the endpoint returns `402` with an `x402` object describing accepted headers, quote options, and `referenceId`.

## Agent Payment Flow (402 -> pay -> fetch)

When an agent does not have an API key or x402 proof header, use the `402` response to drive payment:

1. Request the export with `--auth none` (or no auth) to get a `402` challenge.
2. Read `x402.referenceId` and choose one entry from `x402.accepts[]`.
3. For `pricingModel = "airdrop_export_contract_quote"`, pay the contract in `accepts[].contract` (or `x402.paymentContract`) using the selected token and quoted amount.
4. Re-fetch the same export request with `payer` and `referenceId` (or the same request params so the endpoint derives the same `referenceId`).

### Token Selection (important)

- Treat `x402.accepts[].tokenAddress` as the source of truth for the payment token.
- Do not ask a swap tool (for example, Bankr) to buy by symbol/name only (for example, `"HAMSTER"`), because multiple tokens can share the same symbol/name.
- If you need to acquire the payment token first, pass the exact `tokenAddress` from the selected `x402.accepts[]` entry to the swap tool, then use that same address for `approve` and `pay(...)`.

Important field meanings in `402`:

- `x402.referenceId`: payment key for this exact export request (derived from `source`, `limit`, `cursor`, `params`)
- `x402.paymentContract`: canonical payment contract address
- `x402.accepts[].tokenAddress`: token to pay with
- `x402.accepts[].amountAtomic`: exact token amount to pay for the quote
- `x402.accepts[].contract`: contract to call for contract-quote payments
- `x402.walletCount`: quote multiplier (matches request `limit`)

### Contract vs Receiver (important)

- If `accepts[].pricingModel` is `airdrop_export_contract_quote`, the agent should pay `accepts[].contract` and should not directly transfer tokens to `receiver`.
- `receiver` may be `null` for tokens whose configured sink is a burn/dead address (or when no direct receiver is exposed). This does not block contract-based payment.

## Scripts

- `scripts/x402-wallets.sh`: Generic client for the x402 wallet export endpoint. Supports `GET` or `POST`, source params, and auth selection.

## Config

The skill uses `skills/airdrop-x402/config.json`:

- `baseUrl`: API origin (for example `https://api.farclaw.com`)
- `requestTimeoutSeconds`, `connectTimeoutSeconds`: optional curl timeouts
- `defaultClient`: optional profile name
- `clients[]`: named auth profiles for agents (`apiKey`, `x402Proof`, optional per-client `baseUrl`)

## Common Usage

```bash
# 1) Get a 402 challenge/quote (no auth)
scripts/x402-wallets.sh --source vibeshift_affinity --params-json '{"fid":2629848}' --limit 100 --auth none

# 2) Fetch with API key
scripts/x402-wallets.sh --source vibeshift_affinity --params-json '{"fid":2629848}' --limit 100 --client shared

# 3) Fetch using x402 proof header (if your agent has a proof string)
scripts/x402-wallets.sh --source followers --params-json '{"fid":2629848,"top":500}' --limit 200 --auth x402-proof --client paidproof

# 4) Fetch after on-chain payment was recorded for payer+referenceId
scripts/x402-wallets.sh --source poap_event --params-json '{"eventId":123456}' --payer 0xabc... --reference-id 0xdef... --auth onchain
```

## On-Chain Payment Example (Agent)

This example shows the exact fields an agent should extract from the `402` response and then use for the paid fetch.

```bash
# 1) Get a 402 challenge and save it
skills/airdrop-x402/scripts/x402-wallets.sh \
  --source bankr_leaderboard \
  --limit 100 \
  --auth none \
  --raw > /tmp/x402-challenge.json

# 2) Extract the referenceId + one offer (example: HAMSTER)
# IMPORTANT: symbols can be ambiguous. Use the x402-provided tokenAddress when swapping/buying.
REFERENCE_ID="$(jq -r '.x402.referenceId' /tmp/x402-challenge.json)"
PAYMENT_CONTRACT="$(jq -r '.x402.paymentContract' /tmp/x402-challenge.json)"
TOKEN="$(jq -r '.x402.accepts[] | select(.asset=="HAMSTER") | .tokenAddress' /tmp/x402-challenge.json)"
AMOUNT="$(jq -r '.x402.accepts[] | select(.asset=="HAMSTER") | .amountAtomic' /tmp/x402-challenge.json)"
MULTIPLIER="$(jq -r '.x402.walletCount' /tmp/x402-challenge.json)" # usually equals --limit

# If using a swap agent/tool (e.g. Bankr), request the token by address, not symbol:
# "Swap to token 0x... (exact tokenAddress from x402 quote)", not just "swap to HAMSTER".

# 3) Pay on-chain (example with Foundry cast; payer should be your agent wallet)
# cast send "$TOKEN" "approve(address,uint256)" "$PAYMENT_CONTRACT" "$AMOUNT" --rpc-url "$BASE_RPC_URL" --private-key "$PK"
# cast send "$PAYMENT_CONTRACT" "pay(address,uint256,bytes32,uint256)" "$TOKEN" "$AMOUNT" "$REFERENCE_ID" "$MULTIPLIER" --rpc-url "$BASE_RPC_URL" --private-key "$PK"

# 4) Fetch the list after payment is recorded (on-chain auth mode)
skills/airdrop-x402/scripts/x402-wallets.sh \
  --source bankr_leaderboard \
  --limit 100 \
  --auth onchain \
  --payer 0xYourAgentWallet \
  --reference-id "$REFERENCE_ID"
```

## Supported Sources And Params

All requests require:

- `source` (query/body): one of the sources below
- optional `limit` (default 100, max 1000)
- optional `cursor` (numeric offset, default 0)
- optional `params` (object)

Source-specific `params`:

- `bankr_leaderboard`
  - optional `timeframe`: `"24h"` (default) or `"7d"`
  - optional `metricType`: `"total"` (default) or supported Bankr metrics
  - optional `top`: fetch depth before slicing (`limit + cursor` is default)
- `tipn_affinity`
  - required `fid`
- `vibeshift_affinity`
  - required `fid`
- `poap_event` / `poap`
  - required `eventId`
- `empire_builder`
  - optional `fids`: explicit array of fids (otherwise uses top builders)
- `airdrop_leaderboard` / `leaderboard`
  - optional `forceUpdate`: boolean
- `followers`
  - required `fid`
  - optional `top`: fetch depth before slicing (`limit + cursor` is default)

## Response Notes

Success responses include:

- `wallets[]`: normalized wallet addresses
- `entries[]`: enriched rows (`wallet`, optional `fid`, `username`, `score`, `rank`, `sourceData`)
- `meta`: includes `source`, `total`, `deduped`, `limit`, `cursor`, `nextCursor`, `generatedAt`
- `payment.referenceId`
- `auth.mode`

`402` (payment required) responses include an `x402` object with:

- `referenceId`
- `paymentContract`
- `walletCount`
- `accepts[]` (payment options, token/amount/contract/pricingModel)
- `acceptedHeaders`

For agent loops:

- Use `meta.nextCursor` to page.
- Persist `(source, params, cursor)` externally if you want resumable batches.
- Deduping is already performed server-side by wallet address (`meta.total` vs `meta.deduped`).
