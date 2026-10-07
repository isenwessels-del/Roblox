# Active service contracts

All server modules receive one private context with shared Config/Schema/Validation, Players, Workspace, ReplicatedStorage, HttpService, Clock=os.time, Now=os.clock, Ready, Closing, Notify, Publish and Request. Services are constructed before world initialization and player loading. Exactly one server/client bootstrap is exported.

## Data

Profiles: Version2, HasStarter, Cash, Bank, BaseLevel, TreadmillLevel, SpeedXP, SecurityLevel, Rebirths=0, Collection, Income keyed by house UID, five Statistics, three Settings, LastSeen, DailyDay, DailyStreak, CreatedAt, optional Pending. Schema exposes New/Migrate/Validate/Clone and rejects unsupported/malformed saved records. Game.StudioPersistence=false isolates both profile and ownership storage in memory; live servers always require real stores.

House records: Id, DefinitionId, Variant, Size, OwnerId, Slot, Revision>=1, CreatedAt, OwnedSince, BuildReadyAt, OperationId. UID length is at most44 for Roblox's fifty-character DataStore key limit. House definition, variant and size resolve only through server Config. Ownership exposes List/Get/Create/Transfer/Remove; list failure never returns a partial playable inventory. A tombstone has OwnerId=0 and Slot=0.

Pending intents: Buy/Sell/Starter/Wild with Id, DefinitionId, Variant, Size, Slot, Price, OperationId, CreatedAt; Sell additionally requires ExpectedRevision. Each intent is acknowledged by a profile save before its independent ownership mutation. Intent recovery is idempotent.

## Gameplay

HouseService exposes Records[player], Busy[player], Reserved[player], List, Capacity, FreeSlot, Rate, Attach, Buy, Sell, Collect, SecureWild, ApplyTransfer, Refresh, Tick and Release. UID ownership comes from the ledger; profile.Income is only accrued cash. ApplyTransfer moves earlier source income to their bank and is idempotent for the committed revision/operation.

WildHouseService exposes Offers and Sites, Get, Claim, Release, Finish, Start and Tick. A site has at most one offer. Offers contain an authoritative definition/mutation, growth size, creation time, site position and Busy owner. Size freezes while carried. Returning preserves the same offer UID/site. Finishing schedules one replacement after twenty seconds.

StealService exposes Carriers and Held, IsHeld, SourceHousesBusy, Attempt, AttemptWild, CanCommit, Cancel, CancelForOwner, Bat, Tick and Release. State phases are Hold, Carry and Committing. Hold uses server elapsed time; carry reserves a destination pad. The canonical record remains with its original owner until delivery. A prepared wild intent or unknown CAS outcome cannot be cancelled into a second copy.

Progression exposes Locks/Training/Sprinting, Speed, MovementSpeed, UpdateSpeed, Multiplier, LockDuration, IsLocked, OnJoin, Lock, SetSprint, Train, BaseUpgrade, TreadmillUpgrade, SecurityUpgrade, ClaimDaily, Tick and Release. A retained Rebirth method only returns an unavailable message; no active rebirth action exists. Training checks the owned treadmill and writable live player every tick; speed XP is server-owned.

World exposes Init/Assign/GetPlot/Inside/AtHome, SlotPosition, RenderHouse/RemoveHouse/GetHouseModel/UpdateIncome, CarryModel/ClearCarry, CreatePrefab/RemovePrefab/MovePrefab/UpdateWild, SetOwner/SetLock/SetCharacterGroup, UpdateSlots/UpdateTreadmill/UpdateStandings/RestoreGuard, Tick/Release/Shutdown. Plot fields include Owner, Origin, Frame, Entry, Spawn, CollectPosition, LockPosition and TreadmillPosition. Native prompts start a request immediately; the server performs the two-second hold, so the timer is not duplicated.

GuardService exposes Tick and Shutdown; landlords only pursue their own provisional wild prefab, use a finite territory/grace period, and never own clients' characters or decision state.

## Network and client

`HouseRemotes` has Request, Snapshot, Notification and Announcement RemoteEvents. Request accepts action plus at most two payload arguments. Allowed actions: Sync, Buy, Steal, WildSteal, Sell, Collect, CollectAll, Lock, Bat, Sprint, Train, BaseUpgrade, TreadmillUpgrade, SecurityUpgrade, Daily, Setting and OpenShop. Remotes and prompts use the same server router/rate/movement checks. Stopping training/sprint is allowed even while data is frozen.

Snapshot contains a cloned Profile, Houses array, fixed-config Market array, live Standings, ServerTime and Runtime. Runtime includes DataMode, Writable, PlotId, Slots, Multiplier, IncomePerSecond, LockRemaining, LockCooldown, optional Carry/StealHold, Training, Speed, SpeedXP, TrainingRate, NextSpeedXP, BaseLevel, TreadmillLevel, optional NextBase/NextTreadmill/NextSecurity, and AtHome. Houses include UID, definition, mutation, size, slot, accrued income and build countdown.

Notification accepts text, kind and optional extra UID. Kind ConfirmSell opens a client confirmation; confirmed requests still revalidate ownership/price/proximity on the server. Kind Shop opens the shop. Audio IDs are optional and empty by default; client settings gate sound playback and reduce toast animation. See REFERENCE.md for the researched facts and README.md for actual gameplay and manual Studio configuration.
