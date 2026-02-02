---
name: dickbot
description: |
  Farcaster task helpers for the Dickbot service. Use this skill whenever the request must act as or query data for the DICKBOT_FID (the Dickbot service posting endpoint, vibeshift latest casts by fid, or the general profile lookup). It also includes OpenClaw helper scripts so the agent can call those APIs without re-implementing the HTTP details.
---

# Dickbot Skill

This skill is primarily for OpenClaw agents that need to:

- **post casts/replies on behalf of DICKBOT_FID** (`POST /api/farcaster/bots/dickbot`)
- **fetch the most recent vibeshift casts for a fid** (`GET /api/vibeshift/latestCastsByFid`)
- **look up a Farcaster profile or batch of fids** (`GET /api/profile`)

The `config.json` in the skill root stores the `x-api-key` and `baseUrl` that every script reads, so you do not need to inline secrets. Keep that file updated with the plan-scoped key described above and reuse the provided shell scripts under `scripts/` whenever you want to call these endpoints from OpenClaw.

## Endpoints

### `POST /api/farcaster/bots/dickbot`

- **Purpose**: React as or post a new cast for `DICKBOT_FID` using the shared `likeCast`/`replyOrCast` helpers.
- **Required headers**: `x-api-key` matching the plan name defined by `DICKBOT_API_PLAN` (default `dickbot`), plus `Content-Type: application/json`.
- **Body options**:
  - `action`: `"like"` to react with a like, `"post"` to publish a cast or reply.
  - `target`: when acting on an existing cast (`like` or reply) include `{ fid: number, hash: string }`. `hash` is optional only when posting a new original cast.
  - `text`: required when `action="post"`; the cast/reply text.
  - `embedUrls[]`: optional array of URLs to embed (max 2 total links).
  - `channelId`: optional Warpcast channel slug when posting to a channel (`replyOrCast` passes this through).
  - `disableAlreadyAnsweredCheck`: optional boolean to skip the Redis “already replied” guard.

The service returns the hub response directly (e.g., `{ status: 200, data: { hash, signature, castAddBody } }`). For likes the `data` can be `null`; a `200` means Warpcast accepted the reaction even if no body is returned.

### `GET /api/vibeshift/latestCastsByFid`

- **Purpose**: Read the most recent cast activity for a fid, including optional replies or filters.
- **Query parameters**:
  - `fid` (required): numeric fid to inspect.
  - `limit` (optional): [1,200] number of casts (defaults to 10).
  - `cursor` (optional): vibeshift cursor string to page forward/backward.
  - `since` (optional): vibeshift cursor or ISO string to restrict to newer casts.
  - `includeReplies`: defaults to `true`. Set to `false`, `0`, or `no` to strip replies from the feed.
  - `repliesOnly`: send `1`, `true`, or `yes` to return only replies.

The handler caches responses for 15 seconds (`Cache-Control: private, max-age=15`) and mirrors the vibeshift feed structure so you can iterate payloads, cursors, and cast metadata directly.

### `GET /api/profile`

- **Purpose**: Fetch a single enriched profile (by `name`, `fid`, or `wallet`) or batch multiple fids.
- **Query options**:
  - `name`: Warpcast username lookup.
  - `fid`: numeric fid (can include `tokenCA` to enrich with that profile token).
  - `wallet`: Ethereum wallet address.
  - `fids`: comma-separated list (GET) or JSON array (POST/PUT). GET caps at 50 fids; body POST caps at `PROFILE_MAX_FIDS_POST` (default 1000).
  - `tokenCA`: optional when combining with `fid` to enrich with a specific profile token contract.

The response always includes enrichment (labels, quotient score) when available. Batch responses are arrays of profiles in the same order as the requested fids; single lookups return a single profile object.

## Scripts

All scripts look for `config.json` in the skill root. The file must define:

```json
{
  "apiKey": "<x-api-key-for-dickbot-plan>",
  "baseUrl": "https://api.farclaw.com"
}
```

`baseUrl` can be overridden if you want to hit staging (`https://staging.farclaw.com`) or another deployment. The scripts require `curl` and `jq`; install them on the runner if the OpenClaw environment is bare.

- `scripts/dickbot-like.sh <fid> <hash>`: Posts `{"action":"like","target":{"fid":<fid>,"hash":"<hash>"}}`. Use this when you want Dickbot to like an existing cast. The script errors if either argument is missing.
- `scripts/dickbot-post.sh --text '<text>' [--fid <targetFid>] [--hash <targetHash>] [--channel <channelId>] [--disable-already-answered]`: Builds the `post` payload, optional target info, channel metadata, and the flag to skip duplicate-reply checks. If you omit `--fid`/`--hash`, Dickbot will publish an original cast.
- `scripts/profile.sh --fid <fid> | --name <name> | --wallet <wallet> | --fids <fid1,fid2,...> [--token-ca <tokenCA>]`: Covers every lookup route described above. Use `--token-ca` only when you pair it with `--fid`.
- `scripts/latest-casts.sh --fid <fid> [--limit <1-200>] [--cursor <cursor>] [--since <cursorOrDate>] [--include-replies false] [--replies-only]`: Fetches the vibeshift feed with optional pagination and reply filtering so you can display the last casts that Dickbot might reply to.

Use the scripts within OpenClaw when you need deterministic HTTP calls; they automatically add `x-api-key` (plan scoped) and the base URL from `config.json`, so you never have to rewrite those headers yourself.
