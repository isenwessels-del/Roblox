# Validation and Studio release checklist

## Automated results

Run `python scripts/check.py` to refresh these results. All suites exercise current source files; adapters replace engine/service boundaries only.

| Suite | Passing checks | Boundary |
| --- | ---: | --- |
| Shared content, schema, utilities |359|Pure Luau, current63-item data and migration logic |
| Persistence |75|Actual DataService, injected atomic DataStore and scheduling |
| Progression/events/rankings/analytics |76|Actual services, injected services and clocks |
| Integrated robbery/inventory/economy/houses/remotes/movement |88|Actual services, mocked character/world primitives |
| World and furniture factory |632|Actual generation source, mocked Roblox Instance/math APIs |
| Police |24|Actual controller decisions, mocked physics/pathfinding boundaries |
| **Total** |**1,254**|**Does not include Studio engine validation** |

Rojo build, exact source export and Luau compilation are separate checks. Tests executed, rather than only being listed. There are no claims that mocked navigation/rendering prove Roblox physics or device usability.

## Required real Studio checks

- [ ] Play creates the map without server/client Output errors; HUD finishes loading.
- [ ] Two clients get unique plots, separate $500 balances, backpacks and homes.
- [ ] Enter Starter Street, steal a small item; timer/heat/alarm/UI synchronize.
- [ ] Two clients request the same loot: only one can reserve and consume it.
- [ ] Leaving reach, obstructing LOS, death and disconnect cancel pending theft.
- [ ] Escape on own green pad secures bag exactly once; another player's pad does not.
- [ ] Police spawn at a safe distance, walk/path around walls, lose/search targets, return/despawn, catch only when appropriate, and cannot catch a player on their own home pad.
- [ ] Catch/death loses only unsecured low rarity loot and protects rare loot when saving is writable; stored/displayed items remain.
- [ ] Placement preview, rotated footprints, doorway margin, invalid/occupied coordinates and storage pickup match the server.
- [ ] Sell at the shop, confirm valuables, replay requests, and verify exact currency/item ownership.
- [ ] Upgrade house/backpack/tool/security and purchase/apply themes; count/statistics/value update.
- [ ] Higher districts reject low-level robbery entry; higher tools alter security timing and panel disable works.
- [ ] Tutorial advances in order and completes; quests/achievements/daily gifts cannot claim twice.
- [ ] Collection persists secured discoveries and hides undiscovered Secret identities.
- [ ] Five supported events start/end with correct modifiers and restore lighting.
- [ ] Test persistent save/rejoin in a separate test experience/store namespace; verify furniture rotations, cash, quests, collection and level/XP remainder.
- [ ] Test load denial/unavailable store without overwriting data; test two servers contesting a session and shutdown/autosave.
- [ ] Global ordered rankings update on their coarse cadence; temporary Studio mode does not write leaderboards.
- [ ] Phone/tablet portrait/landscape and gamepad can navigate menus, confirm sales, sprint, rotate/place/cancel, reset and return camera control.
- [ ] Settings persist and reduce effects; add permitted audio IDs and verify sound toggles if enabling audio.
- [ ] Use MicroProfiler/Script Performance and simulate network latency with eight clients. Inspect world/police counters; confirm acceptable frame time, network traffic and memory during repeat join/leave/robbery cycles.

## Unexecuted external checks

This cloud host has no Roblox Studio/runtime. Published DataStore permissions, actual Roblox physics/AI paths, model/UI appearance, replication, mobile/console usability and MicroProfiler measurements remain unexecuted. These are concrete release gates, not optional evidence of production readiness. Paid products are disabled and have not been tested.
