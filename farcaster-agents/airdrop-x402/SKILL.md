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

For agent loops:

- Use `meta.nextCursor` to page.
- Persist `(source, params, cursor)` externally if you want resumable batches.
- Deduping is already performed server-side by wallet address (`meta.total` vs `meta.deduped`).

