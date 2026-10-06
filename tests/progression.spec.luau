-- Deterministic tests against the actual modules, with only Roblox services injected.
local QuestService = require("../src/server/QuestService")
local EventService = require("../src/server/EventService")
local LeaderboardService = require("../src/server/LeaderboardService")
local AnalyticsService = require("../src/server/AnalyticsService")
local Config = {
    Economy = require("../src/shared/Config/EconomyConfig"),
    Game = require("../src/shared/Config/GameConfig"),
    Quests = require("../src/shared/Config/QuestConfig"),
    Events = require("../src/shared/Config/EventConfig"),
}

local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks += 1
end

local now = 20000 * 86400 + 120
local player = { UserId = 21, Name = "TestPlayer", DisplayName = "Test Player", Children = {} }
function player:FindFirstChild(name) return self.Children[name] end
local profile = {
    Cash = 500, XP = 0, Level = 1, FirstJoin = true, TutorialStep = 1,
    House = { HouseValue = 0 }, Statistics = {}, Quests = {},
    Achievements = {}, Inventory = {}, OwnedThemes = { Default = true },
}
local writable = true
local data = { Status = "StudioMemory" }
function data:Get(target) return target == player and profile or nil end
function data:IsWritable(_target) return writable end
local queue = {}
local function spawn(callback) table.insert(queue, callback) end
local function drain()
    local jobs = queue
    queue = {}
    for _, callback in ipairs(jobs) do callback() end
end
local telemetryCalls = 0
local ctx = {
    Config = Config, Data = data, Clock = function() return now end,
    Publish = function() end, Notify = function() end, Log = function() end, Spawn = spawn,
    AnalyticsBackend = { LogCustomEvent = function() telemetryCalls += 1 end },
}
ctx.Analytics = AnalyticsService.new(ctx)
local quests = QuestService.new(ctx)
quests:InitPlayer(player)
check(#profile.Quests.Daily == 3, "Exactly three daily quests are assigned")
check(#profile.Quests.Weekly == 2, "Weekly quests are assigned independently")
local snapshot = quests:Get(player)
for i, difficulty in ipairs({ "Easy", "Medium", "Hard" }) do
    check(snapshot.Daily[i].Difficulty == difficulty, "Daily quests span three difficulty groups")
end
check(not quests:Claim(player, "WeeklyCollector"), "Incomplete weekly claim is rejected")
check(not quests:Claim(player, {}), "Non-string quest claim is rejected")
local assigned = profile.Quests.Daily[1]
local definition = Config.Quests[assigned]
quests:Progress(player, definition.Type, definition.Target, definition.Rarity)
local beforeCash = profile.Cash
check(quests:Claim(player, assigned), "Completed assigned quest can be claimed")
check(profile.Cash == beforeCash + definition.Reward.Cash, "Exactly configured cash is granted")
local claimedCash, claimedXP = profile.Cash, profile.XP
check(not quests:Claim(player, assigned), "Quest cannot be claimed twice")
check(profile.Cash == claimedCash and profile.XP == claimedXP, "Repeated claim is currency-idempotent")

profile.Quests.Daily = { "FindRare" }
profile.Quests.Progress["Daily:FindRare"] = 0
quests:Progress(player, "FindRarity", 1, "Common")
check(profile.Quests.Progress["Daily:FindRare"] == 0, "Wrong rarity cannot satisfy rare quest")
quests:Progress(player, "FindRarity", 1, { Rarity = "Rare" })
check(profile.Quests.Progress["Daily:FindRare"] == 1, "Server-observed matching rarity progresses quest")
quests:Progress(player, "StealItems", 10)
local weeklyBefore = profile.Quests.Progress["Weekly:WeeklyCollector"]
local nextUtcDay = (math.floor(now / 86400) + 1) * 86400
now = nextUtcDay
quests:Tick(player, 10)
check(profile.Quests.Day == math.floor(now / 86400), "Daily rollover follows UTC server day")
check(profile.Quests.Claimed["Daily:" .. assigned] == nil, "Daily claim markers clear at rollover")
if profile.Quests.Week == math.floor((20000 + 3) / 7) then
    check(profile.Quests.Progress["Weekly:WeeklyCollector"] == weeklyBefore, "Daily rollover preserves same-week progress")
end

local dailyCash = profile.Cash
check(quests:ClaimDaily(player), "Initial daily reward can be claimed")
check(profile.Cash == dailyCash + Config.Economy.DailyRewards[1].Cash, "Day one grants configured cash")
check(profile.DailyReward.CurrentDay == 2, "Claim advances the seven-day cycle")
local claimAt = now
check(not quests:ClaimDaily(player), "Same-timestamp repeat daily claim is rejected")
now -= 10
check(not quests:ClaimDaily(player), "Clock moving backwards cannot grant another reward")
now = claimAt + 86400
check(quests:ClaimDaily(player), "Next reward becomes available only after interval")

local storageFull = true
local gifts = 0
ctx.Inventory = {}
function ctx.Inventory:CanStore(_target, _itemId) return not storageFull end
function ctx.Inventory:AddStoredItem(_target, itemId, _reason)
    gifts += 1
    local entry = { UniqueId = "gift" .. gifts, ItemId = itemId, AcquiredAt = now }
    profile.Inventory[entry.UniqueId] = entry
    return entry
end
now += 86400
local giftCash, giftClaim = profile.Cash, profile.DailyReward.LastClaim
check(not quests:ClaimDaily(player), "Gift reward rejects full storage")
check(profile.Cash == giftCash and profile.DailyReward.LastClaim == giftClaim and gifts == 0,
    "Rejected item gift does not partially award cash, consume day, or add an item")
storageFull = false
check(quests:ClaimDaily(player), "Item gift succeeds after freeing storage")
check(gifts == 1 and profile.Inventory.gift1.ItemId == "GamingChair", "One correct item gift is created")
check(not quests:ClaimDaily(player) and gifts == 1, "Item gift cannot be duplicated by repeating claim")
profile.DailyReward.CurrentDay = 7
now += 86400
check(quests:ClaimDaily(player), "Day seven can be claimed")
check(profile.OwnedThemes.Midnight == true and profile.DailyReward.CurrentDay == 1, "Theme unlock and seven-day wrap persist")
profile.DailyReward.CurrentDay = 5
now += 172800
check(quests:Get(player).DailyReward.Day == 1, "Missing the configured streak window resets the reward day")

profile.FirstJoin = true
profile.TutorialStep = 1
check(not quests:UpdateTutorial(player, "StealItems"), "Tutorial cannot skip server-observed prerequisite")
for _, action in ipairs({ "VisitHouses", "StealItems", "CompleteRobbery", "PlaceItem", "Upgrade" }) do
    check(quests:UpdateTutorial(player, action), "Validated tutorial action advances one step")
end
check(profile.FirstJoin == false and quests:Get(player).Tutorial.Complete, "Tutorial completion is persistent")
check(not quests:UpdateTutorial(player, "Upgrade"), "Tutorial completion cannot replay")

profile.Statistics.ItemsStolen = 100
quests:Progress(player, "StealItems", 1)
check(profile.Achievements.Thief.Unlocked == true, "Achievement reads authoritative lifetime stats")
check(quests:Claim(player, "Achievement:Thief"), "Unlocked achievement has a claimable reward")
local achievementCash = profile.Cash
check(not quests:Claim(player, "Achievement:Thief") and profile.Cash == achievementCash, "Achievement reward is idempotent")
profile.Quests.Daily = { "EscapeOnce" }
profile.Quests.Progress["Daily:EscapeOnce"] = 1
profile.Quests.Claimed["Daily:EscapeOnce"] = nil
local originalCash = profile.Cash
profile.Cash = Config.Economy.MaxCash or 1000000000000
check(not quests:Claim(player, "EscapeOnce"), "Cash cap rejects an ungrantable quest reward")
check(profile.Quests.Claimed["Daily:EscapeOnce"] == nil, "Failed reward leaves quest available")
profile.Cash = originalCash
check(not quests:AwardXP(player, math.huge) and not quests:AwardXP(player, 0 / 0), "Non-finite XP is rejected")
writable = false
local unavailableCash = profile.Cash
check(not quests:ClaimDaily(player) and not quests:AwardXP(player, 10), "Read-only/unloaded profiles cannot receive progression rewards")
check(profile.Cash == unavailableCash, "Read-only progression never mutates cash")
writable = true

local originalAmbient = { Original = true }
ctx.Lighting = { ClockTime = 12, Brightness = 2, Ambient = originalAmbient, OutdoorAmbient = originalAmbient }
ctx.Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }
ctx.Players = { GetPlayers = function() return {} end }
ctx.Events = EventService.new(ctx)
check(not ctx.Events:StartEvent("RichNeighbor"), "Unimplemented special-house event is disabled")
check(not ctx.Events:StartEvent("AlienInvasion"), "Unimplemented special-loot event is disabled")
check(ctx.Events:StartEvent("Blackout"), "Supported blackout starts")
check(ctx.Events:Multiplier("Security") == 0.5 and ctx.Lighting.Brightness < 2, "Blackout weakens security and changes lighting")
now += 60
check(not ctx.Events:IsActive("Blackout") and ctx.Events:Multiplier("Security") == 1, "Expired event cannot retain gameplay multiplier")
ctx.Events:Tick(60)
check(ctx.Lighting.ClockTime == 12 and ctx.Lighting.Ambient == originalAmbient, "Event stop restores original lighting")
check(ctx.Events:StartEvent("DoubleXP"), "Double XP event starts")
quests:Progress(player, "StealItems", 1)
quests:Progress(player, "CompleteRobbery", 1)
check(profile.Statistics.EventsParticipated == 1, "Validated play during an event counts participation once per event")
profile.XP, profile.Level = 0, 1
check(quests:AwardXP(player, 50) and profile.Level == 2 and profile.XP == 0, "XP multiplier and configurable level costs apply server-side")
ctx.Events:StopEvent()
now += Config.Game.EventIntervalSeconds
ctx.Events:Tick(Config.Game.EventIntervalSeconds)
check(ctx.Events:GetActive() ~= nil, "Scheduler automatically starts a supported event on its cadence")
ctx.Events:Destroy()
check(ctx.Events:GetActive() == nil and ctx.Lighting.ClockTime == 12, "Destroy removes event and restores lighting")

local analytics = AnalyticsService.new(ctx)
analytics:InitPlayer(player)
analytics:Emit(player, "CashSource", { Amount = 300, Reason = "Sell" })
analytics:Emit(player, "CashSink", { Amount = 100, Reason = "Upgrade" })
check(analytics:Get().CashCreated == 300 and analytics:Get().CashDestroyed == 100, "Economy sources and sinks are counted")
analytics:Emit(player, "invalid label!", {})
check(analytics:Get().Counters["invalid label!"] == nil, "Unbounded/invalid telemetry event labels are rejected")
analytics:Milestone(player, "FirstItem")
analytics:Milestone(player, "FirstItem")
check(analytics:Get().Counters.FirstItem == 1, "First-session milestone emits once")
for i = 1, 100 do analytics:Emit(player, "Event" .. i, {}) end
check(analytics.eventCount == 64, "Metric label cardinality is bounded")
Config.Game.EnableRobloxAnalytics = true
ctx.Analytics:Emit(player, "RealBackendCheck", { Reason = "Test" })
check(telemetryCalls == 0, "Backend telemetry never yields inside Emit")
drain()
check(telemetryCalls == 1, "Explicitly enabled telemetry is submitted asynchronously")
Config.Game.EnableRobloxAnalytics = nil

ctx.CreateInstance = function(class)
    return setmetatable({ ClassName = class, Children = {} }, {
        __index = { FindFirstChild = function(self, name) return self.Children[name] end },
        __newindex = function(self, key, value)
            rawset(self, key, value)
            if key == "Parent" then value.Children[self.Name] = self end
        end,
    })
end
local board = LeaderboardService.new(ctx)
board:InitPlayer(player)
check(player.Children.leaderstats.Children.Cash.Value == profile.Cash, "Leaderstats reflect server cash")
check(board:Get().PersistenceEnabled == false, "Studio-memory leaderboard does not access live data stores")
board:Tick(120)
check(#queue == 0, "Studio-memory leaderboard schedules no persistence jobs")
local exposed = board:Get()
exposed.Live[1].Cash = -100
check(board:Get().Live[1].Cash == profile.Cash, "Leaderboard snapshots cannot mutate cached standings")

data.Status = "Persistent"
local stores, writeCalls, readCalls = {}, 0, 0
local failure = false
ctx.DataStoreService = {}
function ctx.DataStoreService:GetOrderedDataStore(name)
    stores[name] = stores[name] or { Entries = {} }
    local store = stores[name]
    function store:UpdateAsync(key, callback)
        writeCalls += 1
        if failure and string.find(name, "Robberies", 1, true) then error("simulated outage") end
        self.Entries[key] = callback(self.Entries[key])
        return self.Entries[key]
    end
    function store:GetSortedAsync(_ascending, _count)
        readCalls += 1
        local rows = {}
        for key, value in pairs(self.Entries) do table.insert(rows, { key = key, value = value }) end
        table.sort(rows, function(a, b) return a.value > b.value end)
        return { GetCurrentPage = function() return rows end }
    end
    return store
end
profile.House.HouseValue = 500
profile.Statistics.TotalCashEarned = 2000
profile.Statistics.SuccessfulRobberies = 5
local persistent = LeaderboardService.new(ctx)
persistent:InitPlayer(player)
check(writeCalls == 0 and readCalls == 0, "Initializing live stats performs no yielding data calls")
persistent:Tick(90)
check(writeCalls == 0 and #queue == 2, "Scheduled ordered-store I/O is deferred")
drain()
check(writeCalls == 4 and readCalls == 4, "Four global metrics are saved/read on a coarse cadence")
local peakName = Config.Game.ProfileStore .. "_Rank_HouseValue"
check(stores[peakName].Entries[tostring(player.UserId)] == 500, "Global house value records highest-ever value")
profile.House.HouseValue = 100
profile.Statistics.TotalCashEarned += 100
persistent:Update(player)
persistent:Flush()
drain()
check(stores[peakName].Entries[tostring(player.UserId)] == 500, "Lower house value cannot erase lifetime record")
local readsBefore = readCalls
persistent:Tick(1)
drain()
check(readCalls == readsBefore, "Global leaderboard reads are cached between refreshes")

failure = true
profile.Statistics.SuccessfulRobberies += 1
persistent:Update(player)
persistent:Flush()
drain()
check(persistent.pending[player.UserId] ~= nil, "Failed ordered-store writes remain pending")
failure = false
persistent:Update(player)
persistent:Flush()
drain()
check(persistent.pending[player.UserId] == nil, "Failed metric write retries without regranting gameplay rewards")
persistent:Remove(player)
check(#persistent:Get().Live == 0, "Leaving player is removed from live standings")
drain()
print("Passed " .. checks .. " progression, event, analytics, and leaderboard checks")
