---
name: snapchain-pages-api
description: Reference for the Next.js `src/pages/api` surface (Snapchain Subscriber) so Clawdbot/Moltbot can explain how to call, filter, and authenticate against every exposed endpoint; use whenever a user asks about the available APIs, required parameters, or expected responses.
---

# Snapchain /pages/api Skill

Use this skill when you need to explain, summarize, or troubleshoot any HTTP endpoint defined under `src/pages/api`. It is especially valuable when a user asks:

1. "What endpoints do we expose for Mini-apps or Farcaster data?"
2. "How do I call `/api/airdrop/leaderboard` with query limits?"
3. "What headers/bodies does `/api/stash` expect?"

## Strategy

- Always consult `API_DOCS.md` at the repository root before writing a response; it lists every route, allowed methods, parameters, authentication expectations, and response behavior.
- Identify the most relevant module folder (e.g., `airdrop/`, `farcaster/`, `vibeshift/`, `warpl/`) and quote the exact route signature (`/api/<module>/<path>`).
- When parameters are optional or have defaults, highlight both the default and any clamping behavior (e.g., `limit` is clamped between 1 and 500 where noted).
- Note any authentication/authorization requirements (API keys, `farcasterAuthContext`, admin tokens, special headers, stash tokens) so callers know when to include them. Remember the global `withLogger` now rejects any request that carries `x-api-key` unless it validates via `enforceApiKey`, so invalid or revoked keys trigger the same 401/429/403 response that the individual endpoints would have returned before.
- If the question references multiple endpoints, handle each separately and clearly label them.

## Resources

- `API_DOCS.md` (root file): the canonical reference containing every endpoint, method, and parameters documented above. Load it if you need specifics about filters, payloads, or helper notes.

# Access & config

- The root-level `skills/onchain-cooking/config.json` holds the base URL and the preferred API key for demo scripts. Update it with the `full-access` plan key you intend to share with helpers (`apiKey`) and the appropriate `baseUrl` (e.g., `https://ncvpsapi.onchain.cooking/api` or staging). Scripts automatically pull from this config; you can also override by setting `SNAPCHAIN_API_KEY` before running them.
- To issue a “full access” key, run `npm run api:key:create -- --plan full-access --status active` (add `--rate`/`--quota` arguments if you want throttling). That command prints both the key ID and the raw secret. Give that secret as the `x-api-key` to any tool that needs to hit the API surface. If you need a separate Dickbot-only key, reuse the `dickbot` plan described earlier instead.
- If you want to bind a key to a specific origin/domain, enhance `withLogger` by checking `req.headers.origin` (or `referer`) right after the API-key validation and short-circuit with `403` when it does not match an allowlist stored in Redis, Postgres, or a config map.
