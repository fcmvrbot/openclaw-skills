---
name: dickbot
description: |
  Farcaster task helpers for whichever bot is configured in this skill. Use the scripts whenever the request must act as or query data for that configured fid (posting casts/replies, reading the vibeshift feed, or looking up profiles), and rely on the helper shell scripts to avoid re-implementing the HTTP details.
---

# Dickbot Skill

This skill is primarily for OpenClaw agents that need to:

- **post casts/replies on behalf of the configured bot** (`POST /api/farcaster/bots/{fid}` using the fid from `config.json`); fall back to the general `POST /api/farcaster/bots/[fid]` handler only when you explicitly need a different bot.
- **fetch the most recent vibeshift casts for a fid** (`GET /api/vibeshift/latestCastsByFid`)
- **look up a Farcaster profile or batch of fids** (`GET /api/profile`)

The `config.json` in the skill root stores the `x-api-key`, `baseUrl`, and the target bot's `fid`/`name` so every script knows which credentials and endpoint to hit without hardcoding secrets. Keep that file synced to the plan-scoped key described above and reuse the provided shell scripts under `scripts/` whenever you want to call these endpoints from OpenClaw.

## Endpoints

### `POST /api/farcaster/bots/{fid}`

- **Purpose**: React as or post a new cast for the bot defined in `config.json` using the shared `likeCast`/`replyOrCast` helpers.
- **Required headers**: `x-api-key` matching the plan name that corresponds to the configured `name` (see `BOT_SPECS` for the allowed names) plus `Content-Type: application/json`. The scripts pull the configured `fid` and `name` so they always call the right endpoint.
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

### `GET /api/vibeshift/replies-to-target`

- **Purpose**: List casts that mention/target a fid (e.g., Dickbot) without specifying the source fid, so you can see everything that was replied to that fid.
- **Query parameters**: `targetFid` (required, the fid that received replies), optional `limit` (1–200, defaults to 30), and `cursor` (base64 timestamp from the previous response).
- **Response**: `{ replies: [...], nextCursor }`. Each reply includes the incoming cast data plus `parentCast` (the cast the reply answered), `alreadyReplied` (true when DICKBOT has already replied to that cast), `hasAccess`, and `textPreview`. Use `alreadyReplied` to avoid replying multiple times to the same cast and `parentCast` to inspect the original thread context. The cursor allows paging older replies (`encodeCursor(createdAt)`).

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

All scripts look for `config.json` in the skill root. The file must define the API key, base URL, and the bot the script should act as:

```json
{
  "apiKey": "<x-api-key-for-your-bot-plan>",
  "baseUrl": "https://api.farclaw.com",
  "fid": 2629848,
  "name": "farclaw"
}
```

Set `name` to the plan name that corresponds to the bot you want to drive (see the names in `BOT_SPECS`), and `fid` to that bot's numeric fid.

`baseUrl` can be overridden if you want to hit staging (`https://staging.farclaw.com`) or another deployment. The scripts require `curl` and `jq`; install them on the runner if the OpenClaw environment is bare.

- `scripts/dickbot-like.sh <fid> <hash>`: Posts `{"action":"like","target":{"fid":<fid>,"hash":"<hash>"}}` on behalf of the configured bot. This script errors if either argument is missing.
- `scripts/dickbot-post.sh --text '<text>' [--fid <targetFid>] [--hash <targetHash>] [--channel <channelId>] [--disable-already-answered]`: Builds the `post` payload, optional target info, channel metadata, and the flag to skip duplicate-reply checks. If you omit `--fid`/`--hash`, the configured bot publishes an original cast.
- `scripts/profile.sh --fid <fid> | --name <name> | --wallet <wallet> | --fids <fid1,fid2,...> [--token-ca <tokenCA>]`: Covers every lookup route described above. Use `--token-ca` only when you pair it with `--fid`.
- `scripts/latest-casts.sh --fid <fid> [--limit <1-200>] [--cursor <cursor>] [--since <cursorOrDate>] [--include-replies false] [--replies-only]`: Fetches the vibeshift feed with optional pagination and reply filtering so you can display the last casts that Dickbot might reply to.
- `scripts/dickbot-replies.sh --target-fid <fid> [--limit <1-200>] [--cursor <cursor>]`: Fetches `/api/vibeshift/replies-to-target`, returning every incoming reply to the target fid along with the parent cast, `alreadyReplied` flag, `hasAccess`, and pagination cursor. `limit` defaults to 30; use the cursor from the previous response to page. 

Use the scripts within OpenClaw when you need deterministic HTTP calls; they automatically add `x-api-key` (plan scoped) and the base URL from `config.json`, so you never have to rewrite those headers yourself.
