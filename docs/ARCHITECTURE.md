# Neighborhood architecture and security

`default.project.json` exports shared configuration/schema/utilities to ReplicatedStorage, server modules under one server Script, and client modules under one LocalScript. The previous furniture game is preserved on the earlier Git branch; its inactive services are not exported into this place.

## Services

- `DataService`: private Version2 profiles, UpdateAsync session leases, immutable save snapshots, autosave, bounded retries, ambiguous-write markers, leaving and shutdown saves. The new schema uses separate neighborhood store names.
- `OwnershipService`: one canonical house record per UID, expected-owner/revision compare-and-swap, idempotent operation IDs, uncached reads, and a durable per-owner discovery index.
- `HouseService`: income, collection, house purchases/sales, starter gifts, wild awards, capacity, reserved slots and persisted transaction intents.
- `WildHouseService`: bounded eighteen-site production, weighted designs/mutations, monotonic growth and exclusive provisional claims.
- `StealService`: timestamped hold, LOS/distance validation, provisional carry, destination reservations, interruption, canonical transfer and uncertain-outcome reconciliation.
- `ProgressionService`: earned speed, training, sprint, base/treadmill/security upgrades, finite base shields and UTC daily rewards.
- `WorldService` / `ModelFactory`: procedural town, plots, pads, prefabs, models, labels, prompts, per-base gate collision groups and cleanup.
- `GuardService`: server-controlled anchored landlords, grace period, territory radius, LOS catches and cached asynchronous pathfinding.
- `PlayerService`: guarded load/plot assignment/ownership recovery, spawn, defense tool, death and cleanup. Duplicate join callbacks cannot claim another base or overwrite a loading profile.
- `AntiExploitService` / `NetworkService`: one allowlisted request route, common rate buckets, living-character checks, finite position checks, cumulative movement allowance and server raycasts. Both remotes and prompts use the same router.
- Client controllers display snapshots, confirmations, progress, menus and notifications, handle keyboard/touch/gamepad requests, and apply optional audio/accessibility preferences.

## Ownership and economic recovery

Player profiles do **not** decide house ownership. `House_<UID>` is the canonical record containing owner, slot and revision. A recipient's durable `Owner_<UserId>` index receives the UID reference before a create/transfer commits. Loading an index verifies each canonical record; stale references cannot grant ownership. Incoming index references carry the target revision so an in-flight transfer is not mistakenly pruned by a concurrent load. UID records remain as tombstones after selling.

Purchases save the cash debit and exact UID intent before creation. Starter/wild awards also save their intended UID before creation. Sales save their intended payout and expected revision before tombstoning, then credit once when recovering that same operation. Repeated responses or rejoining finish the same operation. A failed initial save retains the intent instead of assuming nothing committed. The canonical ledger resolves duplicate profile references after crashes, and discovery does not depend on both profiles saving at the same instant.

During player theft, the victim remains the canonical owner until delivery. A held UID and destination slot remain reserved during storage requests. Unknown outcomes freeze that transfer; a known unchanged record returns the house, a committed record applies ownership, and a later canonical operation refreshes the affected bases without rendering an old copy. Earlier uncollected rent stays with its earner. The transfer ledger is atomic per UID; cash/training/rent still use periodic profile saves and may lose unsaved increments on crashes.

A departed player may have a prepared wild intent whose store outcome is unknown. That exact site remains reserved until canonical outcome recovery; the server does not release another copy on the assumption that a missing in-memory profile means no durable intent. Persistent storage failures can therefore leave a prefab/pad unavailable until recovery or server restart. This is a deliberate consistency tradeoff.

## Validation boundaries and limits

Clients submit only allowlisted actions and bounded IDs/booleans. They cannot supply an income amount, price, rarity, size, owner, UID creation, world position, XP amount, claim day or completed theft. Purchases/sales/upgrades/claims revalidate server configuration, writable profiles and own-base position. Theft validates actual target models, distance, speed requirements, source ownership/revision, base locks, capacity, live characters and destination presence before committing. A loading victim is protected until join initialization completes. Locks have expiration and a cooldown after expiration; repeated activation cannot create perpetual protection.

Movement enforcement rejects impossible horizontal travel against a replenishing allowance derived from the actual server-earned movement mode. This is not comprehensive flight/noclip detection; physical gate collision and interaction raycasts support the checks, and competitive release still needs dedicated engine testing. Bat targets are chosen on the server with range, LOS, grounded-state and cooldown checks.

Owner indexes are capped at **256 references**. Verified old references are pruned, but references for permanently abandoned future revisions are intentionally retained because deleting an in-flight reference could orphan a house. A sufficiently large accumulation of abandoned incoming operations can block further ownership writes safely. Large-scale release needs a durable abandonment/maintenance protocol and real DataStore budget/latency testing. Do not clear canonical keys or only one of the profile/ownership stores to work around this.

Models, offers, reservations, guard routes and notifications are bounded. NPC path requests are cached and limited to active carries; stale yielding results are discarded. The implementation has not been performance-profiled in Roblox. CLI source tests use labelled engine adapters and do not establish real rendering, physics, native input, replication or service availability.
