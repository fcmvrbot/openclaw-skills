# pages/api Reference

This reference lists every Next.js API route defined under `src/pages/api`. Each path below maps to `/api/...`. Dynamic segments are described with `:param` notation.

Use the information in this file to understand expected methods, required query/body parameters, authentication, and common response details so another LLM can consume these endpoints as a skill.
## Authentication helpers

### `/api/_auth/verify`
- **Methods**: any.
- **Usage**: looks for `x-api-key` header and runs `enforceApiKey`; returns `204` when key is valid, `401` when missing, and mirrors the `enforceApiKey` response when the key is explicitly denied.
- **Notes**: no body or query parameters, purely header-driven.
## Admin endpoints

### `/api/admin/auth`
- **Methods**: GET / POST.
- **Description**: GET says whether admin tokens are required and how many are configured. POST accepts `token` (either JSON body or `Authorization` header) and returns `authorized: true` when the token passes `isAdminTokenValid`.

### `/api/admin/api-usage`
- **Methods**: GET only.
- **Description**: returns rows from `api_usage_daily` joined with `api_keys`. Supports query filters `keyId`, `userId`, `from`, `to` (ISO `YYYY-MM-DD`), and `limit` (casts to `max(1, min(limit, 1000))`, default 200).
- **Response**: `{ total, limit, rows: [...] }` with counts per API key.
- **Auth**: gate-kept by `isRequestAdminAuthorized`.
## Airdrop helpers and exports

### `/api/airdrop/abi/export`
- **Methods**: GET / POST.
- **Description**: GET returns the configured ABI + contract address (`EXPORT_CONTRACT`). POST signs an `operatorPay(...)` call using `MINIAPP_OPERATOR_PRIVATE_KEY` for `payer`, `token`, `referenceId` and numeric `amount`/`multiplier`, plus optional chain/gas hints; persists the raw serialized tx for auditing.
- **Body (POST)**: `payer` (0x address), `token` (0x address), `referenceId` (0x32 bytes), `amount`, `multiplier`, optional `chainId`, `nonce`, `gasLimit`, `maxFeePerGas`, `maxPriorityFeePerGas`, and `meta`.

### `/api/airdrop/arttip`
- **Methods**: GET only.
- **Parameters**: optional `fid` query parameter.
- **Behavior**: when `fid` refers to a registered Arttip user, returns registration, tip count/list plus enriched Farcaster profile info; otherwise returns aggregated registration and tip stats.

### `/api/airdrop/arttip/arttip-filter`
- **Methods**: GET / POST.
- **Params**: `fids` (array or comma-separated string) and numeric `minTips`.
- **Description**: filters a provided fid list to those meeting the tip minimum via `filterArttipsUsers`.

### `/api/airdrop/bankr/leaderboard`
- **Methods**: GET only.
- **Description**: proxies the latest Bankr leaderboard snapshot from `bankrLeaderboard()`.

### `/api/airdrop/embeds`
- **Methods**: GET only.
- **Params**: optional `since` (ISO date without seconds), `label`, `csv=true`, `summary=true`.
- **Behavior**: when `summary` is truthy, returns shared embed stats; otherwise returns embed rows filtered by label. If `csv=true`, serializes share counts and wallet weights as plain text.

### `/api/airdrop/filter/bankr`
- **Methods**: GET / POST.
- **Params**: `fids` (array or comma-separated string): filters this list against the bankr leaderboard.

### `/api/airdrop/filter/profileToken`
- **Methods**: GET / POST.
- **Params**: `fids` plus `ca` (profile token CA string).
- **Description**: returns only the fids whose Warpcast profile token CA matches the supplied value.

### `/api/airdrop/leaderboard`
- **Methods**: GET only.
- **Params**: optional `fid`, `limit`, `forceUpdate`.
- **Behavior**: if `fid` is valid, returns stats via `getFidStats(fid)`; otherwise returns the summed `rewardr` posts capped by `limit` (default 100). Returns `404` when no data.

### `/api/airdrop/quotient/reputation`
- **Methods**: GET / POST.
- **Params**: `fids` (comma-separated string, array, or POST body array). Omitting `fids` yields a `404`-like reply.
- **Behavior**: fetches Quotient reputation for the supplied fids and returns the available data bucket.

### `/api/airdrop/rewardr/:fid`
- **Methods**: POST only.
- **Params**: path `fid` (query), body contains `holders`, `tags`, `sessionId`.
- **Description**: persists rewardr monitoring data by `persistRewardrData`; returns stored record.

### `/api/airdrop/rewardr/tba/:fid`
- **Methods**: GET only.
- **Params**: path `fid`, optional query `checkFeeOnly`.
- **Behavior**: returns TBA details for the fid via `fetchTbaDetails` and `rewardr.server` (returns 404 when absent).

### `/api/airdrop/tipn/affinity`
- **Methods**: GET / POST.
- **Params**: `fid` required; optional `limit`, `cursor`/`offset`.
- **Behavior**: GET returns an affinity preview and cursors; POST triggers and returns the full affinity airdrop build (posts still return `cursor` metadata).

### `/api/airdrop/vibeshift/affinity`
- **Methods**: GET / POST.
- **Params**: requires `fid`; optional `limit`, `cursor`, `deleted`, `onlyDeleted`, `affinityLimit`.
- **Behavior**: GET previews affinity entries, POST builds the affinity airdrop entries (emits `cursor`, `nextCursor`).
## Beeper waitlist

### `/api/beeper`
- **Methods**: GET only.
- **Params**: `limit`, `offset`, `order` (`asc`/`desc`, default `asc`), `wallet`, `fid`.
- **Description**: returns the beeper waitlist via `fetchBeeperWaitlist` with clamped `limit` (default 100, cap 500) and offset (>=0). optional filters for wallet and fid.
## Clanker airdrops

### `/api/clanker/airdrop`
- **Methods**: GET / POST.
- **Parameters**: Provide either `token` (or `contract`, `ca`, `address`, `tokenAddress`) or `fid`. `token` is normalized to a 0x ERC-20 address and accepts optional `network`, `includeDisabled`, `includeEnrichment`, `excludeClaimed`, and `connectedWallet`.
- **Behavior**: token requests return `clankerAirdropDetailsForToken`; fid requests return `clankerAirdrops` with optional connected wallet context and allow excluding already-claimed allocations.

### `/api/clanker/recipients`
- **Methods**: GET only.
- **Params**: `token` (ERC-20 address, required) plus optional `network`/`chain` and pagination `limit` (defaults to all) for results ordering.
- **Response**: aggregates allocations per wallet (USD conversion via cached token info), returns `farcasterRecipients`, `walletRecipients`, totals, and `formattedFarcasterTop` strings.

### `/api/clanker/admin/airdrops`
- **Methods**: GET / POST.
- **GET**: filters claimable Clanker airdrops via `includeDisabled`, `includeInactive`, and `network` (Base, Arbitrum, Monad, UniChain, Ethereum).
- **POST**: updates `flagged` (requires boolean) or `blockaidOverride` for a `token` plus optional `reason` and `network`; responds with the updated flags. requires `isRequestAdminAuthorized`.
## Dune / reward exports

### `/api/dune/dune`
- **Methods**: GET only.
- **Parameters**: query flags `export=geoff` (download raw spam labels as CSV), `rewardsHistory` (numeric page) plus `exportAllRewardsWinners` / `exportAllDeveloperRewardsWinners` to dump every winner, and optional `csv`/`label` for stats requests.
- **Behavior**: converts Warpcast reward history (regular or developer) or GitHub spam JSONL to streamed CSVs with explicit `Content-Disposition` headers. Requests with no flags receive a small `{ what: 'what' }` JSON placeholder.
## Farcaster helpers

### `/api/farcaster/blocks`
- **Methods**: GET only.
- **Params**: query `fid` (required) plus optional `limit` (parsed via `parseLimit`), returns block timeline from `fetchWarpcastBlocks`.
- **Responses**: `200` with block list, `404` when the fid is missing or `fetchWarpcastBlocks` returns nothing.

### `/api/farcaster/cast`
- **Methods**: GET only.
- **Params**: `hash` (cast hash, required).
- **Description**: proxies `getCastDetails` for the hash; `404` when no cast found.

### `/api/farcaster/fidwallets`
- **Methods**: GET only.
- **Params**: `fid`.
- **Description**: returns the wallet array from `allWalletsForFid`; `404` when there are no wallets.

### `/api/farcaster/followers-v2`
- **Methods**: GET only.
- **Params**: `fid` (required), optional `limit`, `level`, `totals`, `follows`, `strategy=best_effort`.
- **Behavior**: selects between `fetchLinksWithLevels`, `fetchLinksCount`, `fetchMyLinksWithLevels`, and `fetchLatestLinksByTargetFid`, with best-effort variants when requested. Adds `meta.strategy` and timing metadata.

### `/api/farcaster/followers`
- **Methods**: GET only.
- **Params**: `fid` (required), optional `limit`, `level`, `totals`, `follows`.
- **Description**: older follower helper that never triggers `best_effort` queries.

### `/api/farcaster/labels-filter`
- **Methods**: GET / POST.
- **Params**: `fids` array or comma list, plus numeric `level` (spam level filter).
- **Purpose**: returns the subset of fids whose label level meets or exceeds `level` via `filterFidsFarcasterLabel`.

### `/api/farcaster/labels`
- **Methods**: GET only.
- **Params**: `fid` (required).
- **Response**: `getFarcasterLabel(fid)` plus `labels` summary from `getFarcasterLabelSummary`. `404` when there is no label data.

### `/api/farcaster/names`
- **Methods**: GET / POST.
- **Params**: either `fid` or `name` (or both) and optional `tokenCA` when enriching with a profile token.
- **Behavior**: resolves who owns a Farcaster name (by fid or by name) and returns ownership metadata plus enriched profile data; returns `404` when the name or fid lacks ownership/domain owner.

### `/api/farcaster/pro`
- **Methods**: GET only.
- **Params**: optional `fid`, `limit`, `fidsOnly`, `preferFarcasterWallet` (legacy GET default true). When `fid` is valid, returns PRO subscription state for that fid; otherwise returns the leaderboard (`fetchApiData`).
- **Response**: optionally pruned projections when `fidsOnly` is truthy.

### `/api/farcaster/quotecasts`
- **Methods**: GET only.
- **Params**: `hash` (parent hash required).
- **Purpose**: returns the quote casts tied to the parent hash, enriched with usernames.

### `/api/farcaster/reactions`
- **Methods**: GET only.
- **Params**: `fid` and `hash`.
- **Description**: proxies `fetchCastReactions` to return the reaction counts and details; `404` when not found.

### `/api/farcaster/replies`
- **Methods**: GET only.
- **Params**: `fid`, `hash`, optional `withReplyHash` to include the parent reply hash.
- **Behavior**: returns replies fetched via `fetchCastReplies`.

### `/api/farcaster/rewards`
- **Methods**: GET only.
- **Params**: `fid`.
- **Description**: exposes `fetchRewards(fid)` and mirrors `404` when there are no rewards for the fid.

### `/api/farcaster/rewards/creator`
- **Methods**: GET only.
- **Params**: `variant` (`live`, `history`, `alltime`, `snapshots`), `format` (`json` or `csv`, defaults to `json`), optional `fid`, `limit`, `periodStart` (timestamp or ISO). Limits default to valid integers.
- **Behavior**: selects the correct dataset (`fetchCreatorLatestSnapshot`, `fetchCreatorRewardsHistory`, `fetchCreatorSnapshots`, `fetchCreatorAllTimeRewards`, etc.), returns CSV when requested, and includes metadata such as reward tiers, `variant`, and period start/end.

### `/api/farcaster/rewards/developer`
- **Methods**: GET only.
- **Params**: `variant` (`live`, `history`, `alltime`, `alltime-miniapps`, `snapshots`), optional `fid`, `limit`, `periodStart`.
- **Description**: mirrors the creator route but targets developer rewards; `alltime` aggregates totals or per-fid, `alltime-miniapps` returns aggregated mini-apps, `snapshots` requires a fid, and `history` returns enhanced history rows.

### `/api/farcaster/wallets`
- **Methods**: GET / POST.
- **Params**: supply one of `fids`, `wallets`, or `usernames` plus an optional `preferFarcasterWallet` (defaults to true). GET uses comma-separated queries; POST accepts JSON arrays.
- **Behavior**: depending on which identifier is supplied, returns the wallets for fids, fids for wallets, or wallets for usernames, honoring `MAX_WALLETS` (50 for GET, 1000 for POST) and rejecting oversized batches.

### `/api/farcaster/bots/[fid]`
- **Methods**: POST only.
- **Headers**: requires `x-api-key`, validated by `enforceApiKey`.
- **Body**: same contract as `/api/farcaster/bots/dickbot` (see below) so you can `like` or `post` with the usual `target`, `text`, optional `embedUrls`, `channelId`, and `disableAlreadyAnsweredCheck`. Reactions always need a `target` with both `fid` and `hash`; posts require `text`.
- **Behavior**: proxies `likeCast` or `replyOrCast` from `@martinvr/farcaster-shared`, passing the `fid` from the URL path so one handler can serve multiple bots while reusing the existing validation.
- **Access**: each bot has its own API plan so a key meant for one fid cannot talk to another. The defaults are:
    - fid `898337` (Dickbot): `DICKBOT_API_PLAN` (default `dickbot`)
    - fid `2629848` (Farclaw): `FARCLAW_API_PLAN` (default `farclaw`)
    - fid `2628464` (Farclawd): `FARCLAWD_API_PLAN` (default `farclawd`)
    - fid `663915` (Hamstart): `HAMSTART_API_PLAN` (default `hamstart`)
    - fid `879602` (Jutta): `JUTTA_API_PLAN` (default `jutta`)
    - fid `883378` (Meco): `MECO_API_PLAN` (default `meco`)
    - fid `1376261` (Purplerain): `PURPLERAIN_API_PLAN` (default `purplerain`)
    - fid `852811` (Referee): `REFEREE_API_PLAN` (default `referee`)
    - fid `891529` (Shebang): `SHEBANG_API_PLAN` (default `shebang`)
    - fid `1351215` (Vibeshift): `VIBESHIFT_API_PLAN` (default `vibeshift`)
    - fid `883003` (Angela): `ANGELA_API_PLAN` (default `angela`)
    - fid `874542` (Clanker): `CLANKER_API_PLAN` (default `clanker`)
    - fid `436577` (Kevinmfer): `KEVINMFER_API_PLAN` (default `kevinmfer`)
    - fid `248216` (Sarto): `SARTO_API_PLAN` (default `sarto`)
    - fid `230238` (MVR): `MVR_API_PLAN` (default `mvr`)
    Override the env var to remap the plan name, but one key can only satisfy the plan associated with the requested fid.

### `/api/farcaster/bots/dickbot`
- **Methods**: POST only.
- **Headers**: requires `x-api-key`, validated by `enforceApiKey`.
- **Body**: JSON object with `action` (`like` or `post`). When `action=like` the request must include `target` (`fid` positive number, `hash` string) for the cast to react to. When `action=post` the request requires `text` (the cast/reply text) and optionally `target` (same shape) to reply, `embedUrls`, `channelId`, and `disableAlreadyAnsweredCheck`. `target.hash` is optional when creating an original cast.
- **Behavior**: proxies `likeCast` or `replyOrCast` from `@martinvr/farcaster-shared`, always passing `DICKBOT_FID`. Response mirrors the Axios payload (`{ status, data }`) so callers get the hub response directly and see validation errors (400) when parameters are missing.
- **Access**: enforces `plan === ${process.env.DICKBOT_API_PLAN ?? 'dickbot'}` (override via `DICKBOT_API_PLAN` env var) so only keys created with that plan can hit this route. Create such a key with `npm run api:key:create -- --plan dickbot` (or the chosen plan) and share the resulting `x-api-key` value with consumers instead of a generic project-wide key.
## Tools & hunts

### `/api/hunt/claim`
- **Methods**: GET only.
- **Params**: `fid`.
- **Description**: returns hunt claim metadata for the fid if `fetchHuntClaim` succeeds, `404` otherwise.
## Mindshare (Inflynce)

### `/api/inflynce`
- **Methods**: GET / POST.
- **Params**: accepts `fid` single value or `fids` array/string, optional `duration` (3, 7, or 30 days; default 7), and `forceRefresh` boolean.
- **Behavior**: `fetchMindshareForFids` returns mindshare stats; returns `400` when no valid fids or duration are provided.
## LittleWins spotlight

### `/api/littlewins`
- **Methods**: GET only.
- **Params**: `mode` (`wins` or `leaderboard`), `limit`, `offset`, `order` (`likes` or `latest`), `fid`, `author`, `minLikes`.
- **Behavior**: when `mode=leaderboard`, returns leaderboard via `fetchLittleWinsLeaderboard`; otherwise fetches wins with pagination and filtering.
## Midly scores

### `/api/midly/rateme`
- **Methods**: GET only.
- **Params**: `fid` (required).
- **Description**: forwards to `rateMyCasts(fid)` to rate the fid's casts; returns `NO_RESULT` when nothing is scored yet.
## NFT helpers

### `/api/nft`
- **Methods**: GET only.
- **Params**: optional `contractAddress` and `chain` together; when both are supplied, returns the cached or freshly fetched NFT detail via `getOrFetchNftDetails`, otherwise returns `listStoredNfts()`.
- **Errors**: `400` when one is missing, `404` when the NFT cannot be found.

### `/api/nft/metadata`
- **Methods**: GET / POST.
- **Params**: `contractAddress`, `chain` (strings).
- **Description**: triggers `refreshNftFromSource` to re-fetch metadata for the NFT; returns the updated record with provided contract/chain.
## Notification services

### `/api/notifs/:fid`
- **Methods**: GET / POST / PUT / DELETE.
- **Description**: requires `authorization` header validated by `farcasterAuthContext` or the special `NOTIFICATION_SERVER_AUTH_KEY`. GET returns stored endpoints for the fid, POST/PUT update (with `type=update` toggles), and DELETE removes registrations. Must also supply `key` query parameter plus optional `appFid` body/query.

### `/api/notifs/installed`
- **Methods**: GET only.
- **Params**: `miniapp` (required).
- **Behavior**: returns all fids that installed the miniapp via the `VpsNotificationService`.

### `/api/notifs/tokens`
- **Methods**: POST only.
- **Headers**: requires `authorization` validated via `farcasterAuthContext`.
- **Params**: `miniapp` (query or body), pagination `limit`, `offset`, optional `fids` array/list to page client-provided IDs.
- **Response**: paginated list of notification values from `VpsNotificationService` along with `pageInfo` metadata.
## Onchat airdrop data

### `/api/onchat/airdrop`
- **Methods**: GET / POST.
- **Params**: `channel`/`slug` required; GET returns `getOnchatAirdropStats`, POST returns `getOnchatAirdropList` (body fields `type`=`members`/`posters`, `includeBanned`, `minMessages`).

### `/api/onchat/channels`
- **Methods**: GET only.
- **Params**: `limit` (default 100), `offset` (default 0).
- **Description**: returns paginated channel metadata.

### `/api/onchat/messages`
- **Methods**: GET only.
- **Params**: `channel` (slug, required), `limit`, `offset`, `replyTo` (message index).
- **Behavior**: returns the requested page of messages for the channel, optionally filtering by threaded replies.
## POAP lookups

### `/api/poap/details`
- **Methods**: GET / POST.
- **Params**: `id` of the POAP event.
- **Response**: detail object returned by `poapEventDetails`.

### `/api/poap/holders`
- **Methods**: GET / POST.
- **Params**: `id` of the POAP event.
- **Response**: list of collectors from `poapCollectors`.
## Profile & enrichment

### `/api/profile`
- **Methods**: GET / POST / PUT.
- **Parameters**: `name`, `fid`, `tokenCA`, `wallet`; supports bulk `fids` via POST body or GET query (caps `PROFILE_MAX_FIDS_POST` / `PROFILE_MAX_FIDS_GET`).
- **Behavior**: bulk requests return profiles augmented by `enrichFarcasterFids` (includes quotient, labels). Single requests resolve name/fid/wallet in that order, enrich and return the final profile.
## Quotient leaderboards

### `/api/quotient/leaderboard`
- **Methods**: GET / POST.
- **Params**: `leaderboardName`, `limit`, `offset`, `forceRefresh`.
- **Behavior**: returns up to 500 entries (default limit 200) for the given leaderboard and includes `total_count`, `run_timestamp`, `run_timestamps`.

### `/api/quotient/summary`
- **Methods**: GET / POST.
- **Params**: `leaderboardName`, `forceRefresh`.
- **Behavior**: same backend but always limits output to 10 entries and returns a derived `totalCount` plus the latest timestamps.

### `/api/quotient/user`
- **Methods**: GET / POST.
- **Params**: `fid` (required), `leaderboardName`, `forceRefresh`.
- **Behavior**: returns a single leaderboard entry for the fid or `404` when the fid is not ranked.
## Rewardr active claims

### `/api/rewardr/claims`
- **Methods**: GET only.
- **Params**: requires either `wallet` (0x) or numeric `fid` plus `includeTokenInfo` and `includePublisherInfo` flags (`true`/`1`).
- **Behavior**: returns `getRewardrActiveClaimsForFid` when `fid` is provided, otherwise `getRewardrActiveClaimsForWallet` for a wallet address. Validates fid as integer > 0; rejects invalid wallets with a `400`.
## Ripper engagement

### `/api/ripper/:fid`
- **Methods**: GET only.
- **Params**: numeric `fid`, optional `since` (e.g. `7d`), `byFid`, `type` (`from_fid`, `mutual`, or others), `limit`, `offset`/`cursor`.
- **Behavior**: fetches engagement data via `fetchEngagementByFid`, `fetchEngagementCombined`, or `fetchUserEngagementFor`, applies sanity limits, and paginates the resulting `users` array with `pageInfo` metadata.
## Temporary stash

### `/api/stash`
- **Methods**: GET / POST.
- **Authentication**: POST/GET use `farcasterAuthContext` (requires `authorization` header) or stash-level token for retrieval.
- **POST body**: arbitrary JSON `data` and optional `options.ttlSec` (or query `ttl`); stores the payload in Redis (fallback to memory) and returns `{ id, ttlSec, token }`.
- **GET**: requires `id` plus either valid `authorization` or the per-stash `token`; returns `{ id, data }` or `404`/`403` when missing.
## Vibeshift endpoints

### `/api/vibeshift/access/confirm`
- **Methods**: POST only.
- **Body**: `nonce` (32-byte hex), `wallet`/`buyer` (0x), `castHash` or `referenceId` (hex).
- **Behavior**: validates stored quote, checks on-chain nonce usage, and marks the quote as used; returns `accessGranted` to indicate whether the wallet still has access.

### `/api/vibeshift/access/quote`
- **Methods**: POST only.
- **Body**: `wallet`/`buyer`, `token` or `tokens`, `castHash`/`referenceId`, optional `multiplier`, `network`, `chainId`, `contract`.
- **Description**: builds undelete quotes via `buildUndeleteQuote` and returns one or multiple quotes with typed data for signing.

### `/api/vibeshift/bookmark/sign`
- **Methods**: POST only.
- **Body**: JSON object `{ fid, hash }` (hash is 0x string).
- **Response**: signed metadata for the cast from `signCastMetadata`.

### `/api/vibeshift/bookmarks`
- **Methods**: POST only.
- **Body**: array of cast objects `{ fid, hash }`.
- **Description**: forwards the array to `vibeshiftBookmarks`; rejects non-array input or empty casts list.

### `/api/vibeshift/engagement`
- **Methods**: GET only.
- **Params**: `fid` (required), optional `limit`, `cursor`, `minSpamLabel`.
- **Returns**: engagement details with cursor-based pagination.

### `/api/vibeshift/feed`
- **Methods**: GET only.
- **Params**: `fid`, optional `limit`, `cursor`, `deleted`, `onlyDeleted`, `feedType=affinity`, `affinity`, `affinityLimit`.
- **Behavior**: fetches the feed (regular or affinity) and triggers `triggerVibeshiftAffinitySync(fid)` before responding.

### `/api/vibeshift/replies-to-target`
- **Methods**: GET only.
- **Params**: `targetFid` (required), optional `limit` (1-200, default 30), optional `cursor` (base64 timestamp).
- **Behavior**: returns replies whose `target_fid` matches the request along with the parent cast and metadata. Each reply includes `alreadyReplied` (true if `DICKBOT_FID` has already replied to that script), `parentCast` (details for the target’s cast), `hasAccess`, and the usual text/embeds info. Use `cursor` (encoded `createdAt`) to page older replies without reprocessing duplicates.

### `/api/vibeshift/mentions-to-target`
- **Methods**: GET only.
- **Params**: `targetFid` (required), optional `limit` (1-200, default 30), optional `cursor` (base64 timestamp).
- **Behavior**: returns mentions whose `target_fid` matches the request along with metadata. Each mention includes `alreadyReplied` (true if `DICKBOT_FID` has already replied to that cast), `hasAccess`, and the usual text/embeds info. Use `cursor` (encoded `createdAt`) to page older mentions without reprocessing duplicates.

### `/api/vibeshift/quotes-to-target`
- **Methods**: GET only.
- **Params**: `targetFid` (required), optional `limit` (1-200, default 30), optional `cursor` (base64 timestamp).
- **Behavior**: returns quotes whose `target_fid` matches the request along with metadata. Each quote includes `quotedCast` (details for the target’s cast), `alreadyReplied` (true if `DICKBOT_FID` has already replied to that cast), `hasAccess`, and the usual text/embeds info. Use `cursor` (encoded `createdAt`) to page older quotes without reprocessing duplicates.

### `/api/vibeshift/feedAffinity`
- **Methods**: GET only.
- **Params**: same as `/feed`, but forces `feedType=affinity`.
- **Response**: affinity-specific feed data with optional deleted filters.

### `/api/vibeshift/feedByFid`
- **Methods**: GET / HEAD.
- **Params**: `fid`, `targetFid`, `limit`, `offset`.
- **Description**: returns deleted casts between two fids (with built-in pagination) from `vibeshiftDeletedCastsByFid`.

### `/api/vibeshift/feedByFids`
- **Methods**: POST / HEAD.
- **Body/Query**: `fids` (array or CSV) plus optional `limit` and `cursor`.
- **Behavior**: fetches deleted casts for a list of fids and responds with `Cache-Control: private, max-age=15`.

### `/api/vibeshift/feedByHash`
- **Methods**: GET only.
- **Params**: `fid`, `hash`.
- **Description**: returns a single cast record (deleted or not) matching `hash` for the given fid.

### `/api/vibeshift/feedByStarterPack`
- **Methods**: GET / POST / HEAD.
- **Params**: `starterPackId` or `fid` (fid must authenticate via `farcasterAuthContext` to discover starter pack from notification settings), optional `limit`, `cursor`, `viewers` extras; includes auto-detected `starterPackId`, `preferenceSource`, and `memberCount` in the response.
- **Behavior**: fetches starter pack members via `getStarterPackMembers` and returns their feed entries.

### `/api/vibeshift/latestCastsByFid`
- **Methods**: GET / HEAD.
- **Params**: `fid`, optional `limit`, `cursor`, `since`, `includeReplies`, `repliesOnly`.
- **Response**: newest casts for the fid (replies optionally filtered) and caching hints.

### `/api/vibeshift/replies`
- **Methods**: GET only.
- **Params**: `fid`, `targetFid`, optional `cursor`, `limit`.
- **Description**: returns mutual replies between two fids via `vibeshiftMutualRepliesFeed`.

### `/api/vibeshift/thread`
- **Methods**: GET only.
- **Params**: `fid`, `hash`, optional `limit` for replies.
- **Description**: fetches a thread keyed by the cast hash using `vibeshiftThreadByHash`.
## Warpl subdomains

### `/api/warpl/nft`
- **Methods**: GET only.
- **Params**: `fid`.
- **Description**: returns Warpl NFT data for the fid; `404` when missing.

### `/api/warpl/register`
- **Methods**: POST only.
- **Body**: `fid`, `label` (validated against `[a-z0-9-]` rules), optional `mintWallet`, `deadline`/`ttlSeconds`, `key`.
- **Auth**: requires `farcasterAuthContext(req, fid, 'warpleth')` (Farcaster JWT for warpleth domain).
- **Behavior**: enforces Purple Rain/Reign holdings, rejects numeric labels that do not match the fid, ensures the user has a warplet when claiming a custom label, enforces subdomain caps, then builds a signature for the registrar; returns registration eligibility, holdings, typed data, and expiry metadata.

### `/api/warpl/status`
- **Methods**: GET only.
- **Params**: `fid` (required).
- **Response**: wallet, enrichment (via `enrichFarcasterItem`), registration summary, warplet NFT data, Purple Rain/Reign holdings, per-token registration eligibility, and remaining subdomain allowances.
