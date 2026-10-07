# Validation

The Linux cloud build compiled and exported **23 game scripts**, with exactly one server Script and one client LocalScript. Embedded place sources are compared as a multiset against all current source files. Rojo7.6.1 and Luau0.699 are pinned and their downloaded archives are checksum-verified.

Run `python3 scripts/check.py` for the complete current suite. **3,374 checks pass:**

| Suite | Checks | Evidence |
| --- | ---: | --- |
| Shared config/schema | 635 | Actual definitions, balancing invariants, strict profile/intent validation and cloning. |
| DataService | 75 | Actual service with injected atomic store: leases, retries, ambiguous writes, release and shutdown. |
| OwnershipService | 127 | Actual canonical ledger: replay, CAS, owner discovery, incoming index races and unavailable stores. |
| ProgressionService | 401 | Server clocks, lock expiry/cooldown, costs, capacity/training upgrades, XP and UTC daily claims. |
| StealService | 96 | Holds, range/LOS, locks, contested carry, prepared wild intents, uncertain outcomes, reconciliation and bat checks. |
| HouseService | 140 | Actual source and canonical ledger: saved debits, starter/wild recovery, tombstone sales, income banking, offline bounds and reserved capacity. |
| NetworkService | 196 | Actual allowlisted routing, malformed arguments, sender identity, paused data and discarded client prices/stat values. |
| WildHouseService | 143 | Weighted eligibility, monotonic growth, exclusive claims, frozen size, return and replacement timing. |
| PlayerService | 45 | Duplicate joins, departed players, load/ownership errors, exhausted bases and bounded cleanup. |
| World/ModelFactory | 1,498 | Production models with primitive engine adapters: seven bases, slots, footprints, gates, visible prompts, growth/build/carry cleanup. |
| GuardService | 18 | Actual chase state: grace/radius, home/death/cancellation, LOS and cached/stale path handling. |

Engine-dependent tests use explicit adapters for Instances, vectors, raycasts, characters, pathfinding and services. Counts refer to assertions, not Studio play sessions. They do not prove rendering, native input, real collision/network behavior, DataStore budgets or device performance. No Roblox Studio session was run from this workspace.

## Studio checklist — still required

- [ ] Set maximum players7 and R15; open the checked-in place and confirm town generation, source startup and clean server/client Output.
- [ ] Start at least two Server & Clients. Verify distinct bases, $500 and exactly one Starter Cottage per new player.
- [ ] Collect rent physically and through HUD; buy a house at home; verify six-second construction and correct rent afterward.
- [ ] Pick up a wild prefab after a two-second server hold; leave range mid-hold, contest it with a second player, die, get caught, time out and disconnect. Verify the original site/UID returns without an extra model.
- [ ] Observe Big/Giant growth and mutations, freeze size at pickup, and verify higher income after construction. Train and upgrade a treadmill; confirm XP stops away from the station, on death or when data is unavailable.
- [ ] Verify speed-gated districts, base slot upgrades and rejected full-base pickups/purchases.
- [ ] Verify 30-second join shield, owner-only barrier passage, manual lock duration and expiry+cooldown; confirm repeatedly pressing Lock cannot extend an active lock.
- [ ] Steal a completed rival house from an unlocked base. Interrupt with lock/bat/death/leave; then complete another theft and verify exactly one current owner and the victim's earlier rent retained.
- [ ] Sell with confirmation, cancel sale, try during building/carry, and confirm payout matches design×mutation×size/2.
- [ ] Test touch prompts/actions and compact screens. Test controller X interactions, D-pad Up menu, B close, selection, R2 defense, L3 run and Y train. Test optional sound IDs and ReducedEffects.
- [ ] In a separate published test experience, change **both** store names, enable Studio API Services, enable StudioPersistence, and verify rejoining restores cash, speed, house UIDs, slots and claims.
- [ ] Restart the server after purchase/sale/transfer and inspect saved canonical ownership. Verify data outages pause uncertain operations, never overwrite profiles, and recover pending intents after rejoin.
- [ ] Validate offline rent boundaries, UTC daily rollover and streaks. Test seven-player occupancy and rejection of another player.
- [ ] Profile seven-client rendering, replication, pathfinding and DataStore latency/budget. Check long sessions, shutdown timing and abandoned ownership-index maintenance before a public release.

Do not use the earlier furniture game's1,254 checks to describe this implementation; they apply to the previous branch. This suite targets the current neighborhood game.
