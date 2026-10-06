# Architecture and security review

## Ownership and persistence

Every live profile is protected by an UpdateAsync lease containing a unique server/session token and wall-clock expiry. The same token must match on every save and release. Expired renewal freezes transactions before the lease can be taken by another server. Load failures, invalid saves, newer unknown schemas and active foreign sessions never produce a playable replacement default. Save snapshots do not replace the live in-memory table. Idempotent write markers support a committed request whose network response was lost.

Schema version2 separates UID-keyed Inventory and House.Furniture maps. Removed item definitions are archived recoverably. Root lifecycle hooks settle protected provisional loot before a profile freezes on departure/shutdown. Autosave defaults to90 seconds with180-second lease and safety margin. The system cannot promise durability through platform outages or a crash before a successful save. Ordered leaderboard records are secondary caches, not the source of currency or items.

## Item transitions

NPC world record → exclusive timed reservation → provisional robbery bag → home storage → display OR sale.

Reservations use attempt identity, so a stale coroutine cannot cancel a newer reservation from the same player. Source records are consumed only once. All callers recheck character health, raycast line of sight, distance, target membership, active robbery, storage/backpack capacity and data writability. Provisional loot reserves storage so a gift cannot displace an already carried item. No asynchronous DataStore calls occur inside the validated in-memory item/currency transition.

Placement uses server-rounded grid coordinates and approved rotations. Entire rotated footprints must fit within the tier's floor margin, clear the doorway, and avoid another placed item. IDs are moved rather than copied. Rare selling checks explicit confirmation and server shop proximity; prices are never accepted from the client.

## Remotes and movement

Remotes are grouped by gameplay/house/quests/settings/UI. Server callbacks bind an allowlisted action; callers cannot choose arbitrary functions. Global and per-action token buckets bound request frequency. Prompts use the same router. Server-to-client notifications/snapshots have no reward callbacks.

Horizontal movement uses a cumulative distance budget replenished at the maximum authorized sprint speed. A20-stud burst covers latency; it is not reset per request. Legitimate delayed samples accrue their elapsed movement allowance. Server teleports are explicitly seeded. Suspicion logs are rate limited and create short gameplay restrictions, not permanent bans.

This is an anti-exploit foundation, not complete commercial anti-cheat. Vertical flight, noclip and sophisticated replication manipulation are not comprehensively detected. Server line-of-sight and location checks limit immediate theft rewards but cannot prove all character motion is legitimate. Evaluate false positives and tune movement tolerance in real multiplayer sessions before launch.

## Performance and cleanup

Runtime is event/timer based, with one0.5-second gameplay scheduler. Snapshots run approximately once per second per player. World loot is bounded by predefined spawn points; home storage is capped at200 items and each tier caps displayed furniture. Police have a global cap, safe spawn positions and cached path requests. Delayed paths check unit/generation validity before applying. Failed/past reservations, police, plot models, death connections, player caches and event lighting have cleanup paths.

WorldService.Metrics and PoliceService.Metrics expose part/spawn/render/path/capture counters for Studio profiling. CLI adapters verify construction bounds and cleanup decisions; they cannot measure Roblox network or mobile rendering performance.

## Deliberate launch boundaries

NPC robberies are fully implemented. Player homes cannot be robbed; house security devices are visible customization/progression, while NPC security and counter-tools affect real heat/alarm timing. Trading, auctions, player loot recovery, premium transactions and licensed audio content are separate post-launch integrations. No placeholder remote awards rewards for them.
