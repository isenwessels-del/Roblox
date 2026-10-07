# STEAL A HOUSE
## ULTIMATE ROBLOX STUDIO + LUAU DEVELOPMENT MASTER PROMPT

You are an expert Roblox game-development team consisting of:

- Senior Roblox/Luau engineer
- Gameplay programmer
- UI/UX designer
- Economy designer
- Multiplayer/networking engineer
- Anti-exploit engineer
- Data persistence engineer
- Level designer
- Technical artist
- Game designer
- Monetization designer
- QA engineer

Your task is to **design and implement a complete production-quality Roblox experience called `STEAL A HOUSE`**.

Do not merely provide a concept.

Do not create pseudocode when working code can be provided.

Do not leave major systems as placeholders.

Build the game as a modular, scalable Roblox experience using **Luau**, Roblox Studio best practices, server-authoritative multiplayer architecture, secure RemoteEvents/RemoteFunctions, and persistent DataStores.

The game should be designed so that additional content can be added without rewriting the core architecture.

---

# ============================================================
# 1. GAME IDENTITY
# ============================================================

## GAME NAME

**STEAL A HOUSE**

## CORE PROMISE

> Steal amazing stuff. Build an insane house. Protect your loot. Become the richest player on the server.

## CORE LOOP

```text
SPAWN
 ↓
GET BACKPACK
 ↓
ENTER HOUSE
 ↓
FIND LOOT
 ↓
STEAL LOOT
 ↓
HEAT INCREASES
 ↓
ESCAPE
 ↓
RETURN HOME
 ↓
DISPLAY / SELL LOOT
 ↓
EARN CASH
 ↓
UPGRADE HOUSE
 ↓
UPGRADE BACKPACK / TOOLS / SECURITY
 ↓
ENTER HARDER AREAS
 ↓
FIND BETTER LOOT
 ↓
REPEAT
```

The loop must be fun even if the player never spends Robux.

---

# ============================================================
# 2. DESIGN PHILOSOPHY
# ============================================================

The game should produce this emotional sequence:

> "I found something."

↓

> "WAIT, THIS IS RARE."

↓

> "Oh no, the alarm went off."

↓

> "I need to get out."

↓

> "YES! I MADE IT!"

↓

> "My house is worth $500,000 now."

↓

> "That guy has a $20M house."

↓

> "I NEED THAT."

↓

> "One more robbery."

The "one more robbery" feeling is the primary retention objective.

---

# ============================================================
# 3. TECHNICAL PRINCIPLES
# ============================================================

Follow these rules throughout development.

## SERVER AUTHORITY

The server owns all important game state.

The client must NEVER be trusted for:

- Cash
- Gems
- XP
- Inventory
- Item ownership
- Item rarity
- Item values
- House ownership
- House value
- Trading
- Robbery rewards
- Quest completion
- Developer-product rewards
- Gamepass rewards
- Security upgrades

The client may request an action.

The server decides whether that action is valid.

Example:

CLIENT:

```text
RequestSteal(item)
```

SERVER:

```text
Is player close enough?
Is item stealable?
Does house belong to valid target?
Is player currently robbing?
Does player have capacity?
Is item already stolen?
Is player alive?
Is the player rate-limited?
```

Only then should the server execute the action.

---

# ============================================================
# 4. PROJECT STRUCTURE
# ============================================================

Create the following structure.

```text
ReplicatedStorage
│
├── Shared
│   ├── Config
│   │   ├── GameConfig
│   │   ├── EconomyConfig
│   │   ├── ItemConfig
│   │   ├── RarityConfig
│   │   ├── HouseConfig
│   │   ├── BackpackConfig
│   │   ├── SecurityConfig
│   │   ├── ToolConfig
│   │   ├── QuestConfig
│   │   ├── EventConfig
│   │   └── MonetizationConfig
│   │
│   ├── Types
│   │   ├── PlayerDataTypes
│   │   ├── ItemTypes
│   │   ├── HouseTypes
│   │   ├── QuestTypes
│   │   └── TradeTypes
│   │
│   ├── Constants
│   │   ├── Rarities
│   │   ├── ItemCategories
│   │   ├── HouseTiers
│   │   └── EventTypes
│   │
│   └── Utilities
│       ├── FormatNumber
│       ├── WeightedRandom
│       ├── TableUtils
│       ├── MathUtils
│       └── Validation
│
├── Remotes
│   ├── Gameplay
│   │   ├── RequestSteal
│   │   ├── RequestSell
│   │   ├── RequestPlaceItem
│   │   ├── RequestPickupItem
│   │   ├── RequestUpgrade
│   │   └── RequestEscape
│   │
│   ├── House
│   │   ├── RequestHouseUpgrade
│   │   ├── RequestHouseCustomization
│   │   ├── RequestSecurityUpgrade
│   │   └── RequestHouseVisit
│   │
│   ├── Inventory
│   │   ├── RequestEquip
│   │   ├── RequestUnequip
│   │   └── RequestSort
│   │
│   ├── Trading
│   │   ├── RequestTrade
│   │   ├── AcceptTrade
│   │   ├── DeclineTrade
│   │   └── ConfirmTrade
│   │
│   ├── Quests
│   │   ├── RequestQuestClaim
│   │   └── QuestUpdated
│   │
│   └── UI
│       ├── Notification
│       ├── RareItemFound
│       ├── AlarmTriggered
│       ├── HeatChanged
│       └── Announcement
│
└── Assets
    ├── Furniture
    ├── Houses
    ├── Vehicles
    ├── Tools
    ├── VFX
    ├── SFX
    └── UI
```

Server:

```text
ServerScriptService
│
├── Server
│   ├── PlayerService
│   ├── DataService
│   ├── InventoryService
│   ├── EconomyService
│   ├── HouseService
│   ├── ItemService
│   ├── RobberyService
│   ├── HeatService
│   ├── SecurityService
│   ├── QuestService
│   ├── TradingService
│   ├── EventService
│   ├── LeaderboardService
│   ├── MonetizationService
│   ├── AntiExploitService
│   └── AnalyticsService
│
└── ServerBootstrap
```

Client:

```text
StarterPlayer
└── StarterPlayerScripts
    └── Client
        ├── ClientBootstrap
        ├── UIController
        ├── InteractionController
        ├── RobberyController
        ├── InventoryController
        ├── HouseController
        ├── CameraController
        ├── NotificationController
        ├── AudioController
        └── InputController
```

UI:

```text
StarterGui
└── MainUI
    ├── HUD
    ├── Inventory
    ├── HouseMenu
    ├── Shop
    ├── CollectionBook
    ├── Quests
    ├── Trading
    ├── Settings
    ├── Notifications
    ├── RareItemPopup
    ├── RobberyUI
    ├── SecurityUI
    ├── AuctionUI
    └── EventAnnouncement
```

---

# ============================================================
# 5. PLAYER DATA MODEL
# ============================================================

Create a robust persistent player profile.

Example:

```lua
PlayerData = {

    Version = 1,

    Cash = 500,

    Gems = 0,

    XP = 0,

    Level = 1,

    House = {
        Tier = 1,

        Theme = "Default",

        Exterior = {
            Wall = "Default",
            Floor = "Default",
            Roof = "Default",
            Door = "Default"
        },

        Furniture = {},

        SecurityLevel = 1,

        HouseValue = 0
    },

    Inventory = {},

    Collection = {},

    Tools = {
        LockpickLevel = 1
    },

    Backpack = {
        Level = 1
    },

    Vehicles = {},

    Quests = {
        Daily = {},
        Weekly = {}
    },

    Achievements = {},

    Statistics = {
        ItemsStolen = 0,
        SuccessfulRobberies = 0,
        FailedRobberies = 0,
        RareItemsFound = 0,
        LegendaryItemsFound = 0,
        MythicItemsFound = 0,
        SecretItemsFound = 0,
        TotalCashEarned = 0,
        TotalCashSpent = 0,
        HousesRobbed = 0,
        TimesRobbed = 0
    },

    Settings = {
        Music = true,
        SFX = true,
        Notifications = true
    },

    DailyReward = {
        CurrentDay = 1,
        LastClaim = 0
    },

    Playtime = 0,

    FirstJoin = true
}
```

Make the data system versioned.

If the game data schema changes, migrate old profiles safely.

---

# ============================================================
# 6. DATA SERVICE
# ============================================================

Create a dedicated `DataService`.

Responsibilities:

- Load profile
- Save profile
- Autosave
- PlayerRemoving save
- BindToClose save
- Data migration
- Session locking
- Failure recovery
- Retry logic
- Default data creation

Never save every tiny action directly to DataStore.

Modify the in-memory profile first.

Autosave approximately every 60–120 seconds.

Save immediately for important transactions when appropriate.

Never allow duplicate sessions to overwrite each other.

---

# ============================================================
# 7. ITEM DATA ARCHITECTURE
# ============================================================

Items must be data-driven.

Do not hardcode item behavior throughout random scripts.

Example:

```lua
ItemConfig["PlasticChair"] = {

    Id = "PlasticChair",

    Name = "Plastic Chair",

    Category = "Furniture",

    Rarity = "Common",

    Value = 25,

    Weight = 1,

    InventorySize = 1,

    Sellable = true,

    Tradeable = true,

    Displayable = true,

    ModelName = "PlasticChair",

    SpawnWeight = 100,

    RequiredArea = 1
}
```

Example Legendary:

```lua
ItemConfig["GoldenThrone"] = {

    Id = "GoldenThrone",

    Name = "Golden Throne",

    Category = "Furniture",

    Rarity = "Legendary",

    Value = 50000,

    Weight = 15,

    InventorySize = 15,

    Sellable = true,

    Tradeable = true,

    Displayable = true,

    ModelName = "GoldenThrone",

    SpawnWeight = 1,

    RequiredArea = 4
}
```

---

# ============================================================
# 8. RARITY CONFIGURATION
# ============================================================

Create:

```lua
RarityConfig = {

    Common = {
        Color = ...,
        Multiplier = 1,
        SpawnWeight = 1000
    },

    Uncommon = {
        Multiplier = 2
    },

    Rare = {
        Multiplier = 5
    },

    Epic = {
        Multiplier = 15
    },

    Legendary = {
        Multiplier = 50
    },

    Mythic = {
        Multiplier = 250
    },

    Secret = {
        Multiplier = 1000
    }
}
```

Do not use purely random rarity.

Use weighted random generation.

The probability should also depend on:

- Area
- House difficulty
- Event
- Special conditions

---

# ============================================================
# 9. ITEM SPAWN SYSTEM
# ============================================================

Create an item spawning system.

Each NPC house has predefined spawn points.

Example:

```text
House
├── SpawnPoints
│   ├── LivingRoom_01
│   ├── LivingRoom_02
│   ├── Kitchen_01
│   ├── Bedroom_01
│   └── Garage_01
```

Each spawn point has:

- Allowed categories
- Minimum rarity
- Maximum rarity
- Spawn probability
- Current item

When an item is stolen:

1. Remove item.
2. Record robbery.
3. Begin respawn timer.
4. Select new item.
5. Spawn item.

Do not spawn unlimited physical objects.

Use controlled spawn limits for performance.

---

# ============================================================
# 10. INTERACTION SYSTEM
# ============================================================

Use Roblox `ProximityPrompt` or an optimized interaction system.

When player approaches a stealable object:

Display:

```text
[ E ] STEAL
Gaming PC
Epic
$4,500
```

For mobile:

Display a touch interaction button.

The client can display the prompt.

The server must validate the actual theft.

---

# ============================================================
# 11. STEAL REQUEST VALIDATION
# ============================================================

When:

```lua
RequestSteal:FireServer(item)
```

is called, validate:

### CHECK 1

Player exists.

### CHECK 2

Character exists.

### CHECK 3

Humanoid exists.

### CHECK 4

Player is alive.

### CHECK 5

Item exists.

### CHECK 6

Item belongs to a valid robbery location.

### CHECK 7

Player is within a legitimate distance.

### CHECK 8

Item has not already been stolen.

### CHECK 9

Player has enough backpack capacity.

### CHECK 10

Player isn't currently performing another incompatible action.

### CHECK 11

Request isn't rate-limited.

### CHECK 12

Player hasn't been flagged for suspicious behavior.

Only then:

- Add item
- Remove physical item
- Increase Heat
- Increase statistics
- Award XP
- Trigger sound
- Trigger VFX
- Start respawn timer

---

# ============================================================
# 12. BACKPACK SYSTEM
# ============================================================

Backpack levels:

```text
Level 1 = 5 capacity
Level 2 = 10
Level 3 = 20
Level 4 = 35
Level 5 = 50
Level 6 = 75
Level 7 = 100
```

Capacity should be calculated from item weight/size.

UI:

```text
BACKPACK

████████░░

8 / 10

[ITEM]
[ITEM]
[ITEM]
...
```

If full:

> Backpack full!

The player must return home or sell/store items.

---

# ============================================================
# 13. HEAT SYSTEM
# ============================================================

Heat is a server-side value.

Range:

```text
0–100
```

Example:

```text
0–20   SAFE
21–40  SUSPICIOUS
41–60  ALERT
61–80  WANTED
81–100 CRITICAL
```

Stealing increases Heat.

Rare items increase more Heat.

Remaining inside high-security areas increases Heat.

Successfully escaping gradually reduces Heat.

---

# ============================================================
# 14. POLICE SYSTEM
# ============================================================

At higher Heat:

### 40+

Police may investigate.

### 60+

Police begin pursuing.

### 80+

Multiple police spawn.

### 100

Critical chase.

Police should not spawn directly on top of players.

Use sensible spawn points.

Police AI should:

- Detect
- Chase
- Navigate
- Lose target
- Search
- Return

Avoid expensive AI calculations on every frame.

Use pathfinding intelligently.

---

# ============================================================
# 15. ROBBERY STATE
# ============================================================

The player has:

```lua
RobberyState = {
    Active = false,
    TargetHouse = nil,
    StartTime = 0,
    Heat = 0,
    ItemsStolen = 0
}
```

A player can only have one active robbery at a time.

When the player successfully reaches their home:

```text
Robbery SUCCESS
```

Trigger:

- Cash opportunity
- XP
- Achievement progress
- Statistics
- Heat reduction
- Success VFX
- Sound

---

# ============================================================
# 16. PLAYER ROBBERY SYSTEM
# ============================================================

Allow players to rob other players under controlled rules.

Important:

Do not allow permanent destruction.

Player-owned displayed items should enter a temporary protected/robbery state.

For example:

```text
Player A steals Player B's Legendary TV.

The item becomes:

"Stolen"

Player A must escape.

If successful:
Player A receives temporary possession.

Player B receives a recovery opportunity.

```

Create counterplay.

The victim should not feel helpless.

---

# ============================================================
# 17. HOUSE OWNERSHIP
# ============================================================

Every player receives one plot.

When a player joins:

1. Find available plot.
2. Assign plot.
3. Load house tier.
4. Load furniture.
5. Load customization.
6. Load security.
7. Recalculate House Value.

When player leaves:

- Save house state
- Release plot
- Clean physical objects

Never allow two players to own the same plot.

---

# ============================================================
# 18. HOUSE PLACEMENT SYSTEM
# ============================================================

Players can place inventory items in their house.

Client:

```text
Select item
 ↓
Enter placement mode
 ↓
Ghost preview
 ↓
Rotate
 ↓
Move
 ↓
Confirm
```

Server:

- Validates item ownership
- Validates plot ownership
- Validates placement boundaries
- Validates collision rules
- Validates item isn't already placed elsewhere
- Saves placement

Furniture data:

```lua
{
    UniqueId = "uuid",
    ItemId = "GoldenThrone",
    Position = {...},
    Rotation = {...},
    Room = "LivingRoom"
}
```

Never trust client-provided arbitrary coordinates.

---

# ============================================================
# 19. HOUSE VALUE CALCULATION
# ============================================================

House Value should be server calculated.

Example:

```text
Displayed item values
+
House tier value
+
Rare-item bonuses
+
Decoration bonuses
=
House Value
```

Do not let the client tell the server:

> "My house is worth $100 million."

The server calculates it.

---

# ============================================================
# 20. HOUSE UPGRADE SYSTEM
# ============================================================

Create 10 house tiers.

Example:

```text
Tier 1
Cardboard Shack
Cost: FREE

Tier 2
Tiny House
Cost: $2,500

Tier 3
Small House
Cost: $15,000

Tier 4
Suburban House
Cost: $75,000

Tier 5
Large House
Cost: $300,000

Tier 6
Luxury House
Cost: $1,000,000

Tier 7
Mansion
Cost: $5,000,000

Tier 8
Mega Mansion
Cost: $25,000,000

Tier 9
Billionaire Estate
Cost: $100,000,000

Tier 10
Secret Estate
Cost: $1,000,000,000
```

These values are balancing starting points and should be adjustable through configuration.

---

# ============================================================
# 21. SECURITY SYSTEM
# ============================================================

Security levels:

```text
1 Basic Lock
2 Camera
3 Alarm
4 Motion Sensor
5 Guard
6 Laser
7 Drone
8 Advanced AI Security
9 Vault
10 Secret Defense
```

Each level should have:

- Cost
- Detection radius
- Detection delay
- Counterplay
- Upgrade requirement

Do not make high-level security impossible to defeat.

It should be difficult, not frustrating.

---

# ============================================================
# 22. SECURITY COUNTERPLAY
# ============================================================

Create tools that counter security.

Example:

Camera:

→ Hacking Device

Alarm:

→ Alarm Disabler

Laser:

→ Laser Cutter

Guard:

→ Distraction

Vault:

→ Advanced Tool

This creates meaningful progression.

---

# ============================================================
# 23. QUEST SYSTEM
# ============================================================

Quest data must be configurable.

Example:

```lua
{
    Id = "StealFiveItems",

    Type = "StealItems",

    Target = 5,

    Reward = {
        Cash = 1000,
        XP = 250
    }
}
```

Quest types:

- StealItems
- FindRarity
- SellItems
- EarnCash
- VisitHouses
- UpgradeHouse
- UpgradeSecurity
- CompleteRobbery
- TradeItems
- DiscoverSecret
- ParticipateInEvent

---

# ============================================================
# 24. DAILY QUESTS
# ============================================================

Generate 3 daily quests.

Difficulty:

- Easy
- Medium
- Hard

Rewards scale accordingly.

Example:

Easy:

Steal 5 items.

Medium:

Steal 1 Rare item.

Hard:

Successfully rob 3 difficult houses.

---

# ============================================================
# 25. COLLECTION SYSTEM
# ============================================================

Every item discovered should be permanently recorded.

Collection entry:

```lua
{
    Discovered = true,
    FirstFound = timestamp,
    Count = 3
}
```

Collection UI:

```text
FURNITURE

COMMON
✓ Plastic Chair
✓ Old TV
□ Wooden Table

RARE
✓ Gaming Chair
□ Arcade Machine

LEGENDARY
□ Golden Throne

MYTHIC
□ Dragon Statue

SECRET
???
```

Use question marks for undiscovered Secret items.

---

# ============================================================
# 26. TRADING SYSTEM
# ============================================================

Trading must be server authoritative.

Trade flow:

```text
Player A requests trade
 ↓
Player B accepts
 ↓
Both add items
 ↓
Both lock trade
 ↓
5-second confirmation period
 ↓
Both confirm
 ↓
Server validates again
 ↓
Atomic exchange
```

If anything changes during the confirmation:

Cancel the trade.

Prevent:

- Duplication
- Item cloning
- Negative inventory
- Fake client items
- Race conditions

---

# ============================================================
# 27. AUCTION SYSTEM
# ============================================================

Allow players to auction items.

Auction data:

```lua
{
    AuctionId = "uuid",
    Seller = userId,
    Item = itemId,
    StartingPrice = 5000,
    CurrentBid = 12000,
    CurrentBidder = userId,
    EndTime = timestamp
}
```

Server controls all bids.

Reject:

- Invalid bids
- Insufficient funds
- Self-bidding
- Expired auctions

---

# ============================================================
# 28. ECONOMY
# ============================================================

Primary currency:

### CASH

Use cash for:

- House upgrades
- Security
- Backpack
- Tools
- Vehicles
- Some cosmetics

Secondary currency:

### GEMS

Use Gems mainly for:

- Cosmetics
- Special effects
- Premium customization
- Limited cosmetic items

Keep the economy simple.

Do not create unnecessary currencies.

---

# ============================================================
# 29. ECONOMY BALANCING
# ============================================================

The player should experience approximately:

### First 5 minutes

First meaningful upgrade.

### First 20 minutes

Several upgrades.

### First hour

Noticeable house progression.

### Several hours

Rare items become realistic.

### Long-term

Mansion progression.

Do not make progression so fast that players have nothing left to achieve.

Do not make progression so slow that new players quit.

All economy values must be configurable.

---

# ============================================================
# 30. SELLING
# ============================================================

Create a central:

### FURNITURE SHOP

Players can sell unwanted items.

Selling should require server validation.

Do not automatically delete valuable items without confirmation.

For rare items:

Display:

> Are you sure you want to sell this Legendary item for $50,000?

Require confirmation.

---

# ============================================================
# 31. NPC HOUSE DIFFICULTY
# ============================================================

Create:

```text
Easy
Medium
Hard
Extreme
Secret
```

Each difficulty modifies:

- Item quality
- Security
- House size
- Heat
- Reward
- Rare spawn chance

---

# ============================================================
# 32. MAP AREAS
# ============================================================

Create the following areas.

## AREA 1
Starter Street

## AREA 2
Suburbs

## AREA 3
Downtown

## AREA 4
Luxury District

## AREA 5
Billionaire Hills

## AREA 6
Secret Underground

Each area requires increasing progression.

Use gates where appropriate.

---

# ============================================================
# 33. MAP NAVIGATION
# ============================================================

Add:

- Signs
- Road markings
- Distinct landmarks
- Area names
- Simple map
- Spawn points
- Teleport/fast travel later

Do not make the map confusing.

Players should always understand where they are.

---

# ============================================================
# 34. RANDOM EVENTS
# ============================================================

Create an EventService.

Events:

### BLACKOUT

Duration:
60 seconds.

Effect:
Security temporarily weakened.

### GOLDEN HOUR

Duration:
120 seconds.

Effect:
Golden furniture has increased spawn rate.

### RICH NEIGHBOR

Special NPC house appears.

### POLICE RAID

Police activity increases.

### ALIEN INVASION

Alien furniture can spawn.

### DOUBLE CASH

Selling rewards doubled.

### DOUBLE XP

XP rewards doubled.

Events should have:

- Start announcement
- Countdown
- Visual effect
- Server-wide notification
- End announcement

---

# ============================================================
# 35. EVENT ARCHITECTURE
# ============================================================

Create:

```lua
EventService:StartEvent("GoldenHour")
EventService:StopEvent("GoldenHour")
EventService:GetActiveEvent()
```

Do not hardcode events into unrelated systems.

Other systems should query EventService.

Example:

```lua
if EventService:IsActive("GoldenHour") then
    -- modify spawn weighting
end
```

---

# ============================================================
# 36. DAILY REWARD SYSTEM
# ============================================================

7-day cycle.

Example:

```text
Day 1 — $500
Day 2 — $1,000
Day 3 — Rare item
Day 4 — $2,500
Day 5 — Tool
Day 6 — Boost
Day 7 — Special cosmetic
```

Use server timestamps.

Do not trust the client's clock.

Prevent easy reward manipulation by changing device time.

---

# ============================================================
# 37. PLAYER LEVEL
# ============================================================

XP sources:

- Successful robbery
- Item discovery
- Rare item discovery
- Quests
- Events
- House upgrades
- Collection milestones

Level formula should be configurable.

Do not require millions of XP at early levels.

---

# ============================================================
# 38. ACHIEVEMENTS
# ============================================================

Examples:

### FIRST ROBBERY

Complete your first robbery.

### THIEF

Steal 100 items.

### PROFESSIONAL

Steal 1,000 items.

### RICH

Earn $1M.

### MILLIONAIRE

Earn $10M.

### LEGEND

Find your first Legendary.

### MYTHICAL

Find your first Mythic.

### SECRET AGENT

Find a Secret item.

### HOUSE FLIPPER

Upgrade your house 5 times.

### FORTRESS

Reach maximum security.

---

# ============================================================
# 39. LEADERBOARDS
# ============================================================

Server leaderboard:

- House Value
- Cash
- Rare Items
- Items Stolen

Global leaderboard:

- Lifetime House Value
- Lifetime Cash Earned
- Total Robberies
- Rare Items Found

Use Roblox's ordered data mechanisms appropriately.

Do not constantly query global leaderboards every frame.

Cache results.

---

# ============================================================
# 40. UI HIERARCHY
# ============================================================

Main HUD:

```text
MainUI
│
├── TopBar
│   ├── Cash
│   ├── Gems
│   ├── Level
│   └── Settings
│
├── BottomBar
│   ├── BackpackButton
│   ├── HouseButton
│   ├── CollectionButton
│   ├── QuestButton
│   └── ShopButton
│
├── HeatMeter
│
├── Objective
│
├── InteractionPrompt
│
├── Notifications
│
└── EventAnnouncement
```

Use responsive scaling.

Make the UI work on mobile.

---

# ============================================================
# 41. RARE ITEM UI
# ============================================================

When a player discovers:

### RARE

Small notification.

### EPIC

Larger notification.

### LEGENDARY

Full-screen dramatic popup.

### MYTHIC

Very dramatic server-visible announcement.

### SECRET

Special animation.

Example:

```text
━━━━━━━━━━━━━━━━━━━━

       SECRET!

   ??? MYSTERY ITEM

       FOUND BY

         PLAYER

━━━━━━━━━━━━━━━━━━━━
```

Only use major screen effects for truly rare discoveries.

---

# ============================================================
# 42. ROBUX MONETIZATION
# ============================================================

Use Roblox MarketplaceService correctly.

Potential Gamepasses:

### VIP

Cosmetics + VIP area.

### Extra Backpack

Convenience.

### House Themes

Cosmetic.

### Special Effects

Cosmetic.

### Build Tools

Convenience.

### Custom Name Tag

Cosmetic.

Developer products:

- Temporary Cash Boost
- Temporary XP Boost
- Event Tickets
- Cosmetic bundles

Avoid aggressive pay-to-win.

Never give Robux players exclusive unbeatable gameplay advantages.

---

# ============================================================
# 43. PURCHASE VALIDATION
# ============================================================

All purchases must be granted server-side.

Use `MarketplaceService.ProcessReceipt` for developer products.

Never grant currency because the client says:

> "I bought this."

Verify the receipt.

Prevent duplicate grants.

Store processed purchase identifiers where necessary.

---

# ============================================================
# 44. ANTI-EXPLOIT SYSTEM
# ============================================================

Create an `AntiExploitService`.

Detect suspicious:

- Remote spam
- Impossible movement
- Impossible distance
- Impossible inventory changes
- Impossible Cash changes
- Impossible item ownership
- Invalid trade requests
- Excessive interaction frequency

Do not automatically permanently ban players based on a single suspicious signal.

Use:

- Logging
- Temporary restrictions
- Server validation
- Escalation

Avoid false positives.

---

# ============================================================
# 45. REMOTE RATE LIMITING
# ============================================================

Every RemoteEvent must have rate limits.

Example:

```text
RequestSteal
maximum legitimate frequency: configurable

RequestTrade
maximum frequency: configurable

RequestPlaceItem
maximum frequency: configurable
```

If a client repeatedly fires invalid requests:

- Ignore
- Log
- Increase suspicion score
- Potentially disconnect if extreme

Never let a malicious client cause server performance problems.

---

# ============================================================
# 46. NETWORK OWNERSHIP
# ============================================================

Be careful with physics.

Do not allow clients to control important physics objects that determine rewards.

For stealable furniture:

Prefer controlled server state.

Avoid physics-heavy objects where unnecessary.

---

# ============================================================
# 47. PERFORMANCE
# ============================================================

Target smooth performance on:

- Low-end mobile
- Mid-range mobile
- PC
- Console

Avoid:

```lua
while true do
    -- expensive work
end
```

Use events and controlled loops.

Do not run expensive logic every frame unless absolutely necessary.

Avoid excessive:

- Particle emitters
- Dynamic lights
- NPCs
- Physics
- Pathfinding
- RemoteEvents
- Instance creation/destruction

Clean up objects using a reliable cleanup system.

---

# ============================================================
# 48. MEMORY / INSTANCE CLEANUP
# ============================================================

Every temporary object must have a cleanup path.

Examples:

- Robbery VFX
- Police NPCs
- Temporary UI
- Event objects
- Dropped items
- Temporary security effects

Do not allow abandoned connections or instances to accumulate.

---

# ============================================================
# 49. NPC ARCHITECTURE
# ============================================================

Create reusable NPC controllers.

NPC types:

- Police
- Security Guard
- Rich Neighbor
- Shopkeeper
- Tutorial NPC

Use state machines.

Example:

```text
Idle
 ↓
Investigating
 ↓
Chasing
 ↓
Searching
 ↓
Returning
```

Avoid having every NPC constantly calculate pathfinding.

---

# ============================================================
# 50. HOUSE AI / SECURITY
# ============================================================

Security devices should have states:

```text
Inactive
Scanning
Suspicious
Triggered
Cooldown
```

Example camera:

1. Scan nearby player.
2. Check whether player is authorized.
3. Check whether player is stealing.
4. Trigger alarm.
5. Notify owner.
6. Increase Heat.
7. Begin cooldown.

---

# ============================================================
# 51. NOTIFICATION SYSTEM
# ============================================================

Create a centralized notification system.

Examples:

```text
💰 +$500

⭐ RARE ITEM FOUND!

🚨 ALARM TRIGGERED!

🏠 HOUSE UPGRADED!

🎒 BACKPACK UPGRADED!

🔥 HEAT: CRITICAL

🚨 YOUR HOUSE WAS ROBBED!
```

Notifications should be queued rather than overlapping uncontrollably.

---

# ============================================================
# 52. SOUND SYSTEM
# ============================================================

Create centralized AudioController.

Categories:

- Music
- UI
- Robbery
- Security
- Rare discovery
- House upgrade
- Environment
- Events

Allow players to disable music/SFX separately.

---

# ============================================================
# 53. MUSIC
# ============================================================

Music should change based on context.

Normal:

Relaxed neighborhood music.

Robbery:

Tension increases.

High Heat:

Faster music.

Escape:

Intense music.

Successful escape:

Short reward sting.

Rare discovery:

Special sound.

Do not make music annoying through repetition.

---

# ============================================================
# 54. TUTORIAL
# ============================================================

Build an interactive tutorial.

NPC:

> "You're broke."

Then:

> "Let's fix that."

Arrow points to NPC house.

Player enters.

Highlight stealable object.

Prompt:

```text
PRESS E TO STEAL
```

Player steals.

Alarm triggers.

NPC:

> "RUN!"

Player escapes.

Then:

> "Bring it home."

Player places item.

Then:

> "Now make your house better."

Upgrade button highlights.

Tutorial ends.

Do not force players through a long tutorial.

---

# ============================================================
# 55. FIRST SERVER EXPERIENCE
# ============================================================

New players should spawn near:

- Tutorial
- Starter house
- First NPC house
- Shop
- Upgrade station

Do not spawn them far away from the action.

---

# ============================================================
# 56. SPAWN SAFETY
# ============================================================

Players cannot be robbed immediately after spawning.

Give a short protection period.

Example:

```text
30 seconds
```

Likewise, prevent players from spawning inside active robbery zones.

---

# ============================================================
# 57. PLAYER DEATH
# ============================================================

If a player dies during a robbery:

Decide clearly what happens.

Recommended:

- Some low-value loot drops.
- Rare loot is protected.
- Heat resets partially.
- Player respawns at home.

Never make death destroy hours of progress.

---

# ============================================================
# 58. SERVER SHUTDOWN
# ============================================================

Before shutdown:

1. Stop new transactions.
2. Save all profiles.
3. Save house states.
4. Complete critical trade/purchase operations safely.
5. Release plots.
6. Shut down.

Use `BindToClose`.

---

# ============================================================
# 59. ERROR HANDLING
# ============================================================

Every important service should handle failure.

Examples:

DataStore unavailable:

> Retry.

Failed house load:

> Use safe fallback.

Failed item spawn:

> Log and retry.

Failed trade:

> Cancel safely.

Failed purchase:

> Do not grant duplicate reward.

Never allow a single error to crash the server.

---

# ============================================================
# 60. LOGGING
# ============================================================

Create structured server logs for:

- Data errors
- Invalid remotes
- Trade failures
- Purchase processing
- Rare item discoveries
- Suspicious activity
- Economy anomalies

Avoid logging excessively every frame.

---

# ============================================================
# 61. ADMIN / DEVELOPER TOOLS
# ============================================================

Create a secure developer/admin system.

Commands could include:

```text
/givecash
/giveitem
/setlevel
/start_event
/stop_event
/reset_player
/teleport
/reload_house
```

These must be server-side and restricted by UserId.

Never rely solely on display names.

---

# ============================================================
# 62. TEST COMMANDS
# ============================================================

Create a development-only testing system.

Examples:

```text
/testspawnitem
/testrobbery
/testevent
/testtrade
/testsave
/testload
/testsecurity
```

Ensure test tools are disabled in production.

---

# ============================================================
# 63. TESTING PLAN
# ============================================================

Test:

### PLAYER

- Join
- Leave
- Rejoin
- Respawn

### DATA

- Load
- Save
- Autosave
- Migration
- Failure recovery

### INVENTORY

- Add
- Remove
- Equip
- Place
- Sell

### ROBBERY

- Steal
- Escape
- Fail
- Heat
- Police
- Death

### HOUSE

- Load
- Upgrade
- Customize
- Place furniture
- Visit

### TRADING

- Request
- Accept
- Confirm
- Cancel
- Disconnect
- Duplicate prevention

### MONETIZATION

- Gamepass
- Developer product
- Receipt handling

### SECURITY

- Camera
- Alarm
- Guard
- Counter tools

### MOBILE

- Touch controls
- UI scaling
- Placement

---

# ============================================================
# 64. EDGE CASES
# ============================================================

Explicitly test:

### Player disconnects during trade.

Trade must cancel safely.

### Player disconnects while carrying loot.

Loot should follow defined server rules.

### Player disconnects immediately after buying.

Purchase must not be lost or duplicated.

### Player disconnects while upgrading.

Upgrade must either complete safely or revert safely.

### Server crashes during transaction.

Never duplicate currency.

### Two players attempt to steal the same object.

Only one succeeds.

### Two players attempt to purchase the same limited item.

Server decides the winner.

### Player sends fake item ID.

Reject.

### Player sends fake price.

Reject.

### Player sends fake position.

Validate against server position.

---

# ============================================================
# 65. SECURITY PRINCIPLE
# ============================================================

Treat every client request as:

> "The player is asking if they are allowed to do this."

Never:

> "The player says they already did this."

This principle must apply everywhere.

---

# ============================================================
# 66. CONTENT PIPELINE
# ============================================================

All items should be easy to add.

Adding a new item should ideally require:

1. Add model.
2. Add configuration entry.
3. Assign rarity.
4. Assign value.
5. Assign spawn weights.
6. Assign category.

Do not require editing ten different scripts.

---

# ============================================================
# 67. CONTENT EXAMPLES
# ============================================================

Create at least 50 initial collectible objects.

### COMMON

Plastic Chair

Old TV

Basic Table

Lamp

Mattress

Microwave

Small Plant

Wooden Chair

Cheap Sofa

Alarm Clock

### UNCOMMON

Modern TV

Office Chair

Computer

Bookshelf

Coffee Machine

Gaming Console

Large Bed

Speaker

### RARE

Gaming PC

Gaming Chair

Arcade Machine

Large Aquarium

Designer Sofa

Luxury Fridge

Rare Painting

### EPIC

RGB Gaming Setup

Golden Lamp

Luxury Bed

Diamond Speaker

Rare Statue

### LEGENDARY

Golden Throne

Golden Piano

Diamond Bathtub

Luxury Car Display

Giant Aquarium

### MYTHIC

Dragon Statue

UFO

Giant Golden Dinosaur

Alien Computer

### SECRET

Mystery Box

??? Statue

Glitched TV

Invisible Furniture

Secret Golden Toilet

---

# ============================================================
# 68. FUNNY ITEMS
# ============================================================

The game should contain absurd items.

Examples:

- Giant toilet
- Giant rubber duck
- Banana statue
- Giant chicken
- Inflatable dinosaur
- Golden toaster
- 500-inch TV
- Tiny car
- Giant spoon
- Alien fridge
- Singing toilet
- Diamond microwave
- Nuclear couch

Funny items create shareable moments.

---

# ============================================================
# 69. SECRET ITEMS
# ============================================================

Secret items should not be fully documented.

Examples:

### GLITCHED TV

Found by interacting with a specific TV 100 times.

### GOLDEN TOILET

Tiny chance in an extremely difficult house.

### UFO

Requires secret combination.

### ??? STATUE

Requires solving a map puzzle.

Secrets should encourage community discovery.

---

# ============================================================
# 70. VIRAL MECHANICS
# ============================================================

Design moments that naturally produce short-form videos.

Examples:

- Player steals Legendary item.
- Police chase begins.
- Player escapes with 1 HP.
- Player discovers Secret room.
- Player finds Mythic item.
- Player enters another player's mansion.
- Player discovers someone has hidden an item.
- Player gets robbed.
- Player recovers stolen item.
- Player reaches $1 billion House Value.

The game should create stories.

---

# ============================================================
# 71. HOUSE SHOWCASE
# ============================================================

Create a central showcase.

Top houses can appear on pedestals.

Display:

```text
#1
PLAYER NAME

HOUSE VALUE

$125,000,000
```

Players can enter showcase houses.

---

# ============================================================
# 72. HOUSE RATING
# ============================================================

Visitors can rate:

⭐ 1–5 stars.

Do not allow unlimited rating spam.

Use cooldowns.

Calculate:

- Average rating
- Number of ratings
- Trending score

---

# ============================================================
# 73. SOCIAL PROOF
# ============================================================

Display accomplishments visibly.

Examples:

```text
🏆 LEGENDARY THIEF
```

```text
💰 $100M HOUSE
```

```text
👑 TOP 10 HOMEOWNER
```

This creates status.

---

# ============================================================
# 74. MOBILE DESIGN
# ============================================================

Mobile controls:

Left:

Virtual joystick.

Right:

Interaction.

Buttons:

- Backpack
- Jump
- Sprint
- House
- Shop

Do not require precise mouse interactions.

Furniture placement should have large controls.

---

# ============================================================
# 75. CONSOLE DESIGN
# ============================================================

Use controller navigation.

Important menus must support:

- D-pad
- Analog stick
- A/X confirm
- B/O back

Do not create UI that requires a mouse.

---

# ============================================================
# 76. ACCESSIBILITY
# ============================================================

Include:

- UI scale
- Reduced screen effects
- Music toggle
- SFX toggle
- Notification toggle
- Camera shake toggle
- Color-friendly rarity indicators
- Clear text labels

Do not rely only on color to communicate rarity.

---

# ============================================================
# 77. ANALYTICS
# ============================================================

Track useful gameplay analytics.

Examples:

- Tutorial completion
- First robbery time
- First item stolen
- First upgrade
- Session length
- Day 1 retention
- Day 7 retention
- Average robberies
- Most stolen items
- Most abandoned areas
- Most popular house tiers
- Average House Value
- Economy inflation

Do not collect unnecessary personal information.

---

# ============================================================
# 78. BALANCING METRICS
# ============================================================

Important metrics:

### TIME TO FIRST FUN

Target:

< 60 seconds.

### TIME TO FIRST UPGRADE

Target:

< 10 minutes.

### FIRST RARE ITEM

Should be achievable without excessive grinding.

### SESSION LENGTH

Aim to encourage:

15–60+ minute sessions.

These are targets for testing, not guaranteed outcomes.

---

# ============================================================
# 79. ECONOMY PROTECTION
# ============================================================

Monitor:

- Cash creation
- Cash destruction
- Item duplication
- Item deletion
- Average player wealth
- Rare item supply
- Auction prices

If inflation becomes excessive, rebalance configuration rather than rewriting systems.

---

# ============================================================
# 80. UPDATE ARCHITECTURE
# ============================================================

The codebase must support future updates.

Possible future systems:

- Pets
- Vehicles
- Clans
- Teams
- Seasons
- Battle Pass
- Events
- New maps
- New robbery types
- New house styles
- New item categories

Do not build the initial architecture in a way that makes these impossible.

---

# ============================================================
# 81. LAUNCH VERSION
# ============================================================

Do NOT attempt to launch with every planned feature.

Minimum viable launch:

### CORE

✓ Stealing

✓ Inventory

✓ NPC houses

✓ Player houses

✓ Furniture placement

✓ Selling

✓ Cash

✓ House upgrades

✓ Backpack upgrades

✓ Basic security

✓ Heat

✓ Police

✓ Collection book

✓ Quests

✓ Leaderboards

✓ Daily rewards

✓ Basic cosmetics

---

# ============================================================
# 82. POST-LAUNCH VERSION
# ============================================================

Update 1:

50 new items.

Update 2:

Trading.

Update 3:

Luxury District.

Update 4:

Vehicles.

Update 5:

Player robberies.

Update 6:

Auction House.

Update 7:

Halloween.

Update 8:

Secret Underground.

Update 9:

Pets.

Update 10:

Major new region.

---

# ============================================================
# 83. DEVELOPMENT PHASES
# ============================================================

## PHASE 1 — FOUNDATION

Create:

- Project structure
- Config architecture
- Data types
- Remote architecture
- DataService
- PlayerService

Do not build content yet.

---

## PHASE 2 — CORE ROBBERY

Create:

- NPC houses
- Items
- Pickups
- Inventory
- Backpack
- Stealing
- Heat
- Escape
- Selling

This is the first playable build.

---

## PHASE 3 — HOUSE

Create:

- Plot allocation
- House loading
- House upgrades
- Furniture placement
- House value
- Security

---

## PHASE 4 — PROGRESSION

Create:

- XP
- Levels
- Quests
- Collection
- Achievements
- Daily rewards

---

## PHASE 5 — SOCIAL

Create:

- House visits
- Ratings
- Trading
- Leaderboards
- Showcase

---

## PHASE 6 — CONTENT

Create:

- More areas
- More houses
- More furniture
- Secrets
- Events
- NPCs

---

## PHASE 7 — MONETIZATION

Create:

- Gamepasses
- Developer products
- Cosmetics
- VIP

---

## PHASE 8 — POLISH

Improve:

- VFX
- SFX
- Animations
- UI
- Tutorial
- Mobile controls
- Performance
- Loading
- Error handling

---

# ============================================================
# 84. CODE QUALITY
# ============================================================

Write clean, maintainable Luau.

Use:

- ModuleScripts
- Type annotations
- Clear naming
- Small functions
- Server/client separation
- Comments for complex logic
- Central configuration
- Reusable services

Avoid:

- Giant scripts
- Global mutable state
- Repeated code
- Hardcoded economy values everywhere
- Client-authoritative rewards
- Circular dependencies

---

# ============================================================
# 85. TYPE SAFETY
# ============================================================

Use Luau type annotations where practical.

Example:

```lua
export type ItemData = {
    Id: string,
    Name: string,
    Rarity: string,
    Value: number,
    Weight: number,
    Category: string,
}
```

Use types consistently for services and data structures.

---

# ============================================================
# 86. SERVICE INITIALIZATION
# ============================================================

Create a controlled startup process.

Example:

```text
ServerBootstrap
 ↓
Initialize DataService
 ↓
Initialize EconomyService
 ↓
Initialize InventoryService
 ↓
Initialize HouseService
 ↓
Initialize RobberyService
 ↓
Initialize QuestService
 ↓
Initialize EventService
 ↓
Initialize TradingService
 ↓
Start runtime
```

Do not allow services to randomly initialize in unpredictable order.

---

# ============================================================
# 87. DEPENDENCY MANAGEMENT
# ============================================================

Services should expose clear APIs.

Example:

```lua
InventoryService:AddItem(player, itemId)
InventoryService:RemoveItem(player, uniqueId)
InventoryService:HasCapacity(player, itemId)
InventoryService:GetInventory(player)
```

HouseService:

```lua
HouseService:GetHouse(player)
HouseService:UpgradeHouse(player)
HouseService:PlaceItem(player, item)
HouseService:RemoveItem(player, item)
HouseService:GetHouseValue(player)
```

EconomyService:

```lua
EconomyService:AddCash(player, amount, reason)
EconomyService:RemoveCash(player, amount, reason)
EconomyService:CanAfford(player, amount)
```

Keep APIs predictable.

---

# ============================================================
# 88. TRANSACTION SYSTEM
# ============================================================

Important operations should be treated as transactions.

Example:

SELL ITEM:

```text
Validate ownership
 ↓
Validate item exists
 ↓
Validate item is sellable
 ↓
Calculate server-side value
 ↓
Remove item
 ↓
Add cash
 ↓
Update statistics
 ↓
Save eventually
 ↓
Notify client
```

If a step fails, do not partially complete the transaction.

---

# ============================================================
# 89. DUPLICATION PREVENTION
# ============================================================

Every unique item should have a unique identifier.

Example:

```text
ITEM-7f82-19ab-4c01
```

Never identify a unique item only by:

```text
"GoldenThrone"
```

because multiple Golden Thrones may exist.

Use:

```lua
UniqueId
ItemId
```

separately.

---

# ============================================================
# 90. INVENTORY MODEL
# ============================================================

Example:

```lua
Inventory = {

    {
        UniqueId = "abc123",
        ItemId = "GoldenThrone",
        AcquiredAt = 1760000000
    },

    {
        UniqueId = "def456",
        ItemId = "GamingPC",
        AcquiredAt = 1760000100
    }
}
```

This allows individual item tracking.

---

# ============================================================
# 91. PLACED ITEM MODEL
# ============================================================

When an item is placed:

```lua
PlacedFurniture = {

    {
        UniqueId = "abc123",
        ItemId = "GoldenThrone",
        Position = {...},
        Rotation = {...}
    }
}
```

The item should no longer exist simultaneously in the inventory.

---

# ============================================================
# 92. ATOMIC ITEM MOVEMENT
# ============================================================

When moving an item:

```text
Inventory
→
Placed
```

or:

```text
Placed
→
Inventory
```

perform this atomically on the server.

Never allow both references to exist permanently.

---

# ============================================================
# 93. LOADING
# ============================================================

Create loading UI.

Example:

```text
STEAL A HOUSE

Loading your house...

████████████░░

Loading furniture...
```

Do not freeze the player without feedback.

---

# ============================================================
# 94. SERVER PERFORMANCE TARGET
# ============================================================

Aim for stable server performance.

Avoid unnecessary work every frame.

Prefer:

- Events
- Timers
- Signals
- Controlled loops
- Caching

Profile expensive systems.

---

# ============================================================
# 95. QA CHECKLIST
# ============================================================

Before release, verify:

[ ] Player can join.

[ ] Player can leave safely.

[ ] Data saves.

[ ] Data loads.

[ ] First-time tutorial works.

[ ] Item can be stolen.

[ ] Inventory updates.

[ ] Backpack capacity works.

[ ] Heat works.

[ ] Police works.

[ ] Player can escape.

[ ] Item can be sold.

[ ] Cash updates.

[ ] House upgrades.

[ ] Furniture placement works.

[ ] House value works.

[ ] Security works.

[ ] Collection works.

[ ] Quests work.

[ ] Daily rewards work.

[ ] Trading works.

[ ] No item duplication.

[ ] No currency duplication.

[ ] Mobile controls work.

[ ] Console controls work.

[ ] UI scales correctly.

[ ] Server shutdown saves data.

[ ] Purchase receipts work.

[ ] Anti-exploit validation works.

[ ] Performance is acceptable.

---

# ============================================================
# 96. IMPORTANT: DO NOT OVERBUILD THE FIRST VERSION
# ============================================================

The first playable version should prioritize:

### FUN > FEATURES

Do not spend weeks creating:

- Huge maps
- 500 items
- Complicated vehicles
- Massive UI
- Advanced clans
- Complex auction systems

before the core robbery loop is fun.

The prototype should answer one question:

> **Is stealing something, escaping with it, and putting it in your house genuinely fun?**

If the answer is yes, expand.

If the answer is no, improve the core loop before adding features.

---

# ============================================================
# 97. MVP CORE LOOP
# ============================================================

The absolute minimum playable loop is:

```text
PLAYER SPAWNS

↓

PLAYER RECEIVES BACKPACK

↓

PLAYER ENTERS NPC HOUSE

↓

PLAYER SEES:
"Gaming Chair — Rare — $500"

↓

PLAYER STEALS IT

↓

ALARM ACTIVATES

↓

PLAYER RUNS

↓

POLICE CHASE

↓

PLAYER ESCAPES

↓

PLAYER RETURNS HOME

↓

PLAYER PLACES GAMING CHAIR

↓

HOUSE VALUE INCREASES

↓

PLAYER EARNS REWARD

↓

PLAYER UPGRADES BACKPACK

↓

PLAYER ENTERS HARDER HOUSE

↓

REPEAT
```

This must feel good before anything else is considered complete.

---

# ============================================================
# 98. DESIGN FOR FUTURE CONTENT
# ============================================================

The following must be easy to add later:

```text
New Item
New Rarity
New House
New Area
New Event
New Quest
New Security
New Tool
New Vehicle
New Cosmetic
New Season
New Gamepass
```

Adding a new item should not require rewriting core systems.

Adding a new event should not require rewriting the robbery system.

Adding a new area should not require rewriting the inventory system.

Use configuration-driven architecture.

---

# ============================================================
# 99. FINAL IMPLEMENTATION REQUIREMENT
# ============================================================

Do not respond with only an explanation of how the game could be built.

Actually create the implementation when the environment allows it.

If working inside Roblox Studio or an AI coding environment:

1. Create the required folders.
2. Create the required ModuleScripts.
3. Create RemoteEvents.
4. Create configuration modules.
5. Implement server services.
6. Implement client controllers.
7. Implement UI.
8. Implement the MVP gameplay loop.
9. Test every core system.
10. Fix errors.
11. Profile performance.
12. Only then expand the feature set.

If a requested feature cannot safely be implemented yet, explicitly isolate it behind a clean interface rather than inserting fake functionality.

Never pretend a feature is working when it is only mocked.

---

# ============================================================
# 100. FINAL QUALITY STANDARD
# ============================================================

The finished game should feel like a real Roblox commercial experience.

It should be:

- Fun
- Fast
- Social
- Funny
- Competitive
- Collectible
- Replayable
- Mobile-friendly
- Secure
- Performant
- Expandable
- Monetizable without being aggressively pay-to-win

The player should immediately understand:

> **STEAL. ESCAPE. BUILD. PROTECT.**

The ultimate progression should be:

```text
BROKE PLAYER
      ↓
SMALL HOUSE
      ↓
BETTER LOOT
      ↓
BETTER HOUSE
      ↓
RARE ITEMS
      ↓
SECURITY
      ↓
MANSION
      ↓
LEGENDARY COLLECTION
      ↓
BILLIONAIRE ESTATE
      ↓
TOP PLAYER ON THE SERVER
```

And the game should constantly create the thought:

# “ONE MORE ROBBERY.”

That is the core product objective.

Build everything around it.