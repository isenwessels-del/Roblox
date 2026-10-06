# STEAL A HOUSE — furniture robbery launch build

**Steal. Escape. Build. Protect.** This Rojo project implements the launch version of the supplied [master specification](docs/MASTER_SPEC.md). It replaces the earlier whole-house theft prototype with furniture robberies.

## Play

You start with $500, a five-capacity backpack, a starter home, and one of eight exclusive plots. Find a **yellow NPC-house doorstep** on Starter Street and start a robbery. Hold a furniture prompt, then stay nearby through the server theft timer. Loot occupies your provisional backpack; only reaching your own **green home pad** and securing the bag moves it into permanent home storage.

Stealing and staying inside secured houses increase heat. Alarms and server-controlled police create a chase. Sprint with Shift, the touch button or the controller button. Leaving the target house is not enough: bring the bag home. If you die, are caught, time out, or disconnect, unsecured Common/Uncommon loot is lost; Rare and better loot is secured automatically when the profile is writable and has reserved space. Previously secured loot remains safe. Robberies expire after five minutes. Server crashes can lose unsaved session progress; temporary bags are not persisted across crashes.

Open **Inventory → Place** at home to position secured furniture on a grid. Mouse, touch arrows, and controller input support movement/rotation; green/red preview checks match the server's footprint, bounds, collision and doorway rules. Picking up furniture moves its existing unique ID back into storage. Displays raise the server-calculated house value. Visit the **Loot Exchange** to sell stored items; valuable sales require confirmation. Use proceeds for backpacks, tools, homes and themes. Counter-security tools can disable the NPC entrance panel for 25 seconds once the required tool level is reached.

## Implemented launch systems

- 8 multiplayer plots; 18 accessible, open-roof NPC houses across 6 progression-gated districts.
- 63 configured collectibles across Common, Uncommon, Rare, Epic, Legendary, Mythic and Secret rarities, including absurd furniture. Procedural silhouettes use category-specific geometry; no Toolbox assets are needed.
- Server-weighted loot selection, contested unique-item reservations, bounded physical loot and respawn timers.
- Provisional backpack versus secured inventory, capacity reservation, selling and atomic inventory/display movement.
- 10 house tiers, 7 backpack levels, 10 tool/security levels, 6 cosmetic themes.
- Heat, NPC alarms, counter-security panels, server-owned police rigs, cached pathfinding, home safe zones and cleanup.
- XP/levels, ordered interactive tutorial, daily/weekly quests, achievements, permanent collection discoveries and seven-day daily rewards.
- Live server standings and cached ordered global rankings when persistent mode is enabled.
- Blackout, Golden Hour, Police Raid, Double Cash and Double XP server events with actual gameplay modifiers and announcements.
- Responsive HUD, scrollable menus, valuable-sale confirmation, queued notifications, rare discoveries, accessibility settings and mouse/touch/gamepad placement.
- Versioned DataStore profiles with session leases, retries, autosave, leaving/shutdown saves, immutable save snapshots, safe migration and recoverable removed-content archives.
- Configurable optional audio and cosmetic purchase definitions. Audio IDs are unset; Robux purchases are disabled.

Player homes are safe in this launch build. Their security upgrades change visible devices and progression statistics; **player robberies and recovery mechanics are not active**. As scheduled by the specification's post-launch roadmap, trading, auctions, vehicles, pets, player robberies and seasonal content are excluded. Rich Neighbor and Alien Invasion are not scheduled because their complete event content is not implemented. Secrets are currently low-probability collectibles, not a full map-puzzle system. Art is procedural and needs a commercial art pass; audio needs assets you have permission to use.

## Architecture

`default.project.json` maps `src/shared` into ReplicatedStorage, `src/server` into ServerScriptService and `src/client` into StarterPlayerScripts. One bootstrap per side controls initialization; everything else is a ModuleScript.

- **Shared:** separate configuration modules, constants, exported Luau types, pure utilities, and `ProfileSchema`.
- **Server:** `DataService`, `PlayerService`, `InventoryService`, `EconomyService`, `HouseService`, `ItemService`, `RobberyService`, `HeatService`, `SecurityService`, `PoliceService`, `QuestService`, `EventService`, `LeaderboardService`, `AntiExploitService`, `AnalyticsService`, `WorldService`, `ModelFactory` and `NetworkService`.
- **Client:** UI, widgets, inventory, placement, camera, interaction, input, robbery feedback, progression, notifications and audio controllers.

Services receive one private dependency context. All client-to-server remotes and ProximityPrompt callbacks use the same allowlisted router and rate limiter. Prices, rarity, currency, ownership, capacity, claim dates, placement and completion timers are decided on the server. Core transactions do not yield between validation and mutation. See [architecture and security notes](docs/ARCHITECTURE.md).

## Build and automated checks

For Linux x86_64 with Python 3 and curl:

```sh
python scripts/setup.py
python scripts/check.py
python scripts/package.py
```

The helper downloads official pinned Rojo 7.6.1 and Luau 0.699 releases using TLS and SHA-256 verification. Build output and tools are ignored by Git. `check.py` builds `build/StealAHouse.rbxlx`, verifies that every current game script is exported exactly once, compiles all Luau sources and runs the actual-source test suites. The generated package contains the self-contained place, source, documentation and an offline Windows transfer script.

Tests cover pure content/schema utilities, real DataService against an injected atomic store, progression/events/leaderboards, integrated gameplay services, world/model construction and policing. Engine-dependent tests use labelled Roblox boundary adapters; they are not Roblox Studio tests. See [validation results and checklist](docs/VALIDATION.md).

On Windows/macOS, install the official matching Rojo CLI and build:

```sh
rojo build default.project.json -o StealAHouse.rbxlx
```

For live source editing, install the official Rojo Studio plugin, run `rojo serve default.project.json` on your local computer, and connect the plugin. Opening a built place does not need that plugin.

## Roblox Studio configuration

1. Open the built place. **The map appears when Play starts**, because its models are generated by the server.
2. Set the experience's **maximum player count to 8**. A player without a free plot is rejected safely.
3. Default Studio mode is `GameConfig.StudioPersistence = false`. The HUD explicitly says **Studio · temporary**, and stopping Play clears that practice progress. The game remains playable without publishing or enabling API access.
4. For actual persistence testing, publish a **separate test experience**, set a distinct `GameConfig.ProfileStore` such as `StealAHouse_test_v2`, enable Studio API Services access in that test experience, and set `StudioPersistence = true`. Production servers always require a real DataStore; a failed load blocks gameplay rather than overwriting the save with defaults.
5. Run Studio **Server & Clients** with at least two clients. Follow the full [Studio checklist](docs/VALIDATION.md), including saving/rejoining, contested theft, death, police, device input and shutdown. Inspect server and client Output.
6. Optional: assign licensed sound asset IDs in `GameConfig.Audio`. No HTTP permission, secrets, Marketplace IDs or outside packages are required for the launch loop. Marketplace definitions remain disabled until a separate receipt/entitlement integration is implemented and verified.

The game has not been executed in Roblox Studio from this Linux workspace. Real rendering, replication, physics, DataStore access, police movement and device performance remain release gates. Do not publish it as production-tested based only on the CLI checks.

## Getting the files onto Windows

1. Open the [launch branch on GitHub](https://github.com/isenwessels-del/Roblox/tree/codex/steal-a-house-launch).
2. Select **Code → Download ZIP**, then right-click the downloaded ZIP in Windows and select **Extract All**.
3. In Roblox Studio, select **File → Open from File** and choose `downloads/StealAHouse.rbxlx` inside the extracted project.
4. Press **Play** to generate the map and start the game. See the Studio configuration above before testing saved progress.

The branch also includes `downloads/StealAHouse-launch.zip`, a standalone bundle with the place, source and documentation. Extract that bundle and open its `StealAHouse/StealAHouse.rbxlx` file. The checked-in downloads represent this launch snapshot; after changing the game source, rebuild with `scripts/check.py` and regenerate the package with `scripts/package.py`.

The cloud chat's `/workspace/...` links may not support downloads. As an offline alternative, `scripts/package.py` prepares `build/StealAHouse-Windows.ps1`, a **complete, self-contained** transfer script also included in the standalone bundle. Transfer that script as plain text, paste its entire contents into PowerShell, and open the newly created `StealAHouse-launch-…rbxlx` file from your Desktop. It uses no network, checks GZip integrity and SHA-256, stops on errors, and never requires variables from a previous PowerShell window.

Opening this place starts a local Studio project. Publishing a Roblox experience is a separate step in Studio.
