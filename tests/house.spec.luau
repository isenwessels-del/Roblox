-- Production house economy + production ownership ledger. Only profile I/O,
-- server scheduler, clock and engine rendering/proximity boundaries are faked.
-- This does not simulate Roblox replication, physics or live DataStore limits.
local Config = require("../src/shared/Config")
local Schema = require("../src/shared/ProfileSchema")
local scheduled = {}
local task = { spawn = function(callback) table.insert(scheduled, callback) end,
    wait = function() end }
local Houses = require("../src/server/HouseService")
local Ownership = require("../src/server/OwnershipService")
local Progression = require("../src/server/ProgressionService")
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks += 1
end
local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end
local function count(value)
    local result = 0
    for _ in pairs(value) do result += 1 end
    return result
end
local function drain()
    local callbacks = scheduled
    scheduled = {}
    for _, callback in ipairs(callbacks) do callback() end
end

local function fixture()
    local player, other = { UserId = 11 }, { UserId = 22 }
    local f = { Player = player, Other = other, Clock = 1000, Now = 0,
        Profiles = { [player] = Schema.New(1000), [other] = Schema.New(1000) },
        Durable = {}, Writable = true, Home = true, PlotAvailable = true,
        SourceBusy = {}, Held = {}, SaveModes = {}, Saves = {}, Ledger = {}, Events = {},
        Renders = {}, Removes = {}, Incomes = {}, SlotUpdates = {}, Notices = {}, Publications = 0 }
    local ctx = { Config = Config, Data = { Status = "Persistent" }, Steal = { Carriers = {} },
        World = {}, HttpService = {}, AntiExploit = {} }
    f.Context = ctx
    ctx.Clock = function() return f.Clock end
    ctx.Now = function() return f.Now end
    function ctx.Data:Get(p) return f.Profiles[p] end
    function ctx.Data:IsWritable(p) return f.Writable and f.Profiles[p] ~= nil end
    function ctx.Data:Save(p)
        local profile = f.Profiles[p]
        assert(Schema.Validate(profile), "House economy produced a profile rejected by the real schema")
        local snapshot = Schema.Clone(profile)
        table.insert(f.Saves, snapshot)
        table.insert(f.Events, "profile-save")
        local mode = table.remove(f.SaveModes, 1)
        if mode ~= "fail" then f.Durable[p] = snapshot end
        if mode == "fail" or mode == "ambiguous" then return false, "ProfileStoreUnavailable" end
        return true
    end
    local store = {}
    function store:GetAsync(key)
        if f.ReadFailure == key then error("Injected ownership read outage") end
        return clone(f.Ledger[key])
    end
    function store:UpdateAsync(key, callback)
        table.insert(f.Events, "ledger-write:" .. key)
        if f.WriteFailure == key or f.WriteFailure == "all" then error("Injected ownership write outage") end
        callback(clone(f.Ledger[key])) -- DataStore may discard/replay transforms.
        local result = callback(clone(f.Ledger[key]))
        if result == nil then return nil end
        f.Ledger[key] = clone(result)
        if f.AmbiguousWrite == key then f.AmbiguousWrite = nil; error("Committed; response lost") end
        return clone(result)
    end
    ctx.Ownership = Ownership.new(ctx, { Store = store, RetryCount = 1,
        Now = ctx.Clock, Wait = function() end })
    function ctx.Steal:SourceHousesBusy(p) return f.SourceBusy[p] == true end
    function ctx.Steal:IsHeld(uid) return f.Held[uid] == true end
    function ctx.Steal:_valid(state) return state.Valid ~= false end
    function ctx.World:AtHome(p) return f.Home and f.Profiles[p] ~= nil end
    function ctx.World:GetPlot(p)
        return if f.PlotAvailable and f.Profiles[p] then { Owner = p } else nil
    end
    function ctx.World:RenderHouse(p, record)
        table.insert(f.Renders, { Player = p, Record = clone(record) })
    end
    function ctx.World:RemoveHouse(p, uid) table.insert(f.Removes, { Player = p, Id = uid }) end
    function ctx.World:UpdateIncome(p, uid, amount)
        table.insert(f.Incomes, { Player = p, Id = uid, Amount = amount })
    end
    function ctx.World:UpdateSlots(p, slots) f.SlotUpdates[p] = slots end
    function ctx.AntiExploit:Character(p) return if f.Profiles[p] then {} else nil end
    function ctx.HttpService:GenerateGUID()
        f.Guid = (f.Guid or 0) + 1
        return "test-" .. f.Guid
    end
    ctx.Notify = function(p, message, kind, id)
        table.insert(f.Notices, { Player = p, Message = message, Kind = kind, Id = id })
    end
    ctx.Publish = function() f.Publications += 1 end
    f.Houses = Houses.new(ctx)
    ctx.Houses = f.Houses
    f.Progression = Progression.new(ctx)
    return f
end
local function attached()
    local f = fixture()
    assert(f.Houses:Attach(f.Player), "Fixture starter attachment failed")
    return f
end
local function seed(f, uid, slot, definition, variant, size, owner)
    local record = { Id = uid, Slot = slot, DefinitionId = definition or "starter_cottage",
        Variant = variant or "Normal", Size = size or "Normal", OwnerId = (owner or f.Player).UserId,
        Revision = 1, CreatedAt = 900, OwnedSince = 900, BuildReadyAt = 906, OperationId = "create-" .. uid }
    assert(f.Context.Ownership:Create(record))
    return record
end
local function reload(f, player)
    f.Profiles[player] = Schema.Clone(assert(f.Durable[player], "No durable profile"))
    f.Houses = Houses.new(f.Context)
    f.Context.Houses = f.Houses
    return f.Houses:Attach(player)
end

do
    local f = fixture()
    check(f.Houses:Attach(f.Player), "first join attaches starter without ownership-schema conflict")
    local profile, list = f.Profiles[f.Player], f.Houses:List(f.Player)
    check(#list == 1 and list[1].DefinitionId == Config.Houses[1].Id, "exactly one configured starter")
    check(list[1].Revision == 1 and list[1].OwnerId == f.Player.UserId,
        "starter is accepted by canonical ledger at revision one")
    check(list[1].BuildReadyAt == f.Clock and profile.Cash == Config.Game.StartingCash,
        "starter ready immediately and does not debit joining cash")
    check(profile.HasStarter and profile.Collection[list[1].DefinitionId] and profile.Pending == nil,
        "starter ownership finalized with collection and no pending intent")
    check(f.Saves[1].Pending.Kind == "Starter" and not f.Saves[1].HasStarter,
        "starter intent durable before creation rather than marked granted early")
    check(f.Events[1] == "profile-save" and f.Events[2]:match("^ledger%-write:Owner_"),
        "profile intent persisted before independent ownership record")
    check(f.SlotUpdates[f.Player] == Config.Game.StartingSlots, "initial base enables configured ten pads")
    local uid = list[1].Id
    check(reload(f, f.Player) and #f.Houses:List(f.Player) == 1 and f.Houses:List(f.Player)[1].Id == uid,
        "rejoin cannot mint a second starter")
    local removed = f.Context.Ownership:Remove(uid, f.Player.UserId, 1, "sold-starter")
    check(removed and reload(f, f.Player) and #f.Houses:List(f.Player) == 0,
        "losing/selling all houses does not reset the once-only starter grant")
end

do
    local f = attached()
    f.Profiles[f.Player].Cash = 1e6
    f.Events, f.Saves = {}, {}
    check(f.Houses:Buy(f.Player, "garden_cottage", -1, "Void", "Giant"),
        "extra caller arguments cannot choose prices or mutations")
    local profile, list = f.Profiles[f.Player], f.Houses:List(f.Player)
    local bought = list[2]
    check(profile.Cash == 1e6 - Config.HouseById.garden_cottage.Price,
        "configured server price debited exactly")
    check(bought.Variant == "Normal" and bought.Size == "Normal" and bought.Slot == 2,
        "store purchase uses server normal variant/size and first free pad")
    check(bought.BuildReadyAt == f.Clock + Config.Game.ConstructionSeconds,
        "construction deadline is persistent server timestamp")
    check(f.Saves[1].Cash == profile.Cash and f.Saves[1].Pending.Id == bought.Id,
        "debit and specific UID intent saved together before ownership create")
    check(f.Events[1] == "profile-save", "purchase cannot write canonical ownership before saved debit")
    check(profile.Statistics.Bought == 1 and profile.Statistics.TotalSpent == Config.HouseById.garden_cottage.Price,
        "completed purchase updates stats once")
    local starter = list[1]
    f.Houses:Tick(2)
    check(profile.Income[starter.Id] == 4 and profile.Income[bought.Id] == 0,
        "starter earns while new house construction suppresses rent")
    f.Clock += Config.Game.ConstructionSeconds
    f.Houses:Tick(2)
    check(profile.Income[bought.Id] == 10, "construction completion allows configured rate once")
    f.Held[bought.Id] = true
    f.Houses:Tick(3)
    check(profile.Income[bought.Id] == 10, "house carried by a thief generates no extra source rent")
    f.Held[bought.Id] = nil
    f.Writable = false
    f.Houses:Tick(3)
    check(profile.Income[bought.Id] == 10, "lease-frozen profiles cannot accrue unsavable income")
end

do
    for _, mode in ipairs({ "fail", "ambiguous" }) do
        local f = attached()
        local profile = f.Profiles[f.Player]
        local starting = profile.Cash
        f.SaveModes = { mode }
        check(not f.Houses:Buy(f.Player, "starter_cottage"), "failed/ambiguous intent save postpones purchase: " .. mode)
        local intent = clone(profile.Pending)
        check(intent and intent.Kind == "Buy" and profile.Cash == starting - 250,
            "failed save retains debit with recovery intent; no unsafe rollback: " .. mode)
        check(f.Context.Ownership:Get(intent.Id) == nil and #f.Houses:List(f.Player) == 1,
            "unacknowledged profile save cannot create ownership: " .. mode)
        check(not f.Houses:Buy(f.Player, "starter_cottage") and profile.Cash == starting - 250,
            "pending buy prevents second charge or another purchase: " .. mode)
        if mode == "ambiguous" then
            check(f.Durable[f.Player].Pending.Id == intent.Id, "committed but lost profile response retained exact recovery UID")
            check(reload(f, f.Player), "ambiguous intent recovers on fresh house service")
        else
            f.Houses:Tick(1)
            check(#scheduled == 1, "server schedules pending purchase retry")
            f.Houses:Tick(1)
            check(#scheduled == 1, "parallel income ticks do not launch duplicate recovery")
            drain()
        end
        local recovered = f.Profiles[f.Player]
        check(recovered.Pending == nil and recovered.Cash == starting - 250,
            "retry completes same intent with exactly one debit: " .. mode)
        check(#f.Houses:List(f.Player) == 2 and f.Context.Ownership:Get(intent.Id).OwnerId == f.Player.UserId,
            "retry owns one new canonical UID: " .. mode)
        check(recovered.Statistics.Bought == 1, "recovery counts one completed buy: " .. mode)
    end
end

do
    local f = attached()
    f.WriteFailure = "all"
    local profile, cash = f.Profiles[f.Player], f.Profiles[f.Player].Cash
    check(not f.Houses:Buy(f.Player, "starter_cottage"), "ownership outage retains saved purchase")
    local intent = clone(profile.Pending)
    check(intent and f.Durable[f.Player].Pending.Id == intent.Id and profile.Cash == cash - 250,
        "ownership failure keeps durable debit and known UID")
    f.WriteFailure = nil
    f.Houses:Tick(1); drain()
    check(profile.Pending == nil and #f.Houses:List(f.Player) == 2 and profile.Cash == cash - 250,
        "ownership outage retry grants original purchase without refund/duplication")
end

do
    local f = attached()
    f.SaveModes = { "success", "fail" }
    check(f.Houses:Buy(f.Player, "starter_cottage"), "canonical purchase success survives final profile-save failure")
    local pending = clone(f.Durable[f.Player].Pending)
    check(pending and f.Profiles[f.Player].Pending == nil and f.Profiles[f.Player].Cash == 250,
        "only durable profile remains pre-finalization after final-save outage")
    check(reload(f, f.Player) and #f.Houses:List(f.Player) == 2,
        "rejoin replays committed creation rather than minting another UID")
    check(f.Profiles[f.Player].Cash == 250 and f.Profiles[f.Player].Statistics.Bought == 1,
        "replayed finalization debits and counts purchase once")
    check(f.Context.Ownership:Get(pending.Id).Revision == 1, "idempotent creation keeps revision one")
end

do
    local f = attached()
    local offer = { Id = "wild-original", DefinitionId = "garden_cottage", Variant = "Gold" }
    local state = { Token = "wild-operation", Record = { Size = "Big" }, Slot = 2, Valid = true }
    local cash = f.Profiles[f.Player].Cash
    f.SaveModes = { "ambiguous" }
    check(not f.Houses:SecureWild(f.Player, offer, state), "wild claim postpones creation after ambiguous profile save")
    check(state.IntentPrepared and f.Profiles[f.Player].Pending.Kind == "Wild"
        and f.Profiles[f.Player].Pending.Id == offer.Id and f.Profiles[f.Player].Cash == cash,
        "free wild claim retains source UID/operation/size without charging cash")
    local intruder = { Token = "other-carry-token", Record = { Size = "Giant" }, Slot = 3, Valid = true }
    check(not f.Houses:SecureWild(f.Player, offer, intruder),
        "same offer UID with foreign carry token cannot resume another claim")
    local created = f.Houses:SecureWild(f.Player, offer, state)
    check(created and created.Id == offer.Id and created.Variant == "Gold" and created.Size == "Big"
        and created.Slot == 2, "retry preserves server-captured wild size, mutation and reserved destination")
    check(f.Profiles[f.Player].Cash == cash and f.Profiles[f.Player].Statistics.Stolen == 1
        and f.Profiles[f.Player].Pending == nil, "wild handoff completes once with no debit")
    local invalid = attached()
    check(not invalid.Houses:SecureWild(invalid.Player, offer, { Valid = false })
        and invalid.Profiles[invalid.Player].Pending == nil, "interrupted carry never prepares ownership intent")
    invalid.Writable = false
    check(not invalid.Houses:SecureWild(invalid.Player, offer, state)
        and invalid.Profiles[invalid.Player].Pending == nil, "lease-frozen carry cannot prepare wild claim")
end

do
    local f = attached()
    f.SaveModes = { "success", "fail" }
    check(f.Houses:Buy(f.Player, "starter_cottage"), "create before stolen-during-recovery test")
    local pending = clone(f.Durable[f.Player].Pending)
    local moved = f.Context.Ownership:Transfer(pending.Id, f.Player.UserId, 1, f.Other.UserId, 1, "steal-before-recover")
    check(moved ~= nil, "canonical house changed owner before purchase profile recovered")
    check(reload(f, f.Player), "matching old purchase intent recovers even when canonical owner has changed")
    check(#f.Houses:List(f.Player) == 1 and #f.Context.Ownership:List(f.Other.UserId) == 1,
        "old purchase recovery neither steals back canonical house nor mints replacement")
    check(f.Profiles[f.Player].Cash == 250 and f.Profiles[f.Player].Statistics.Bought == 1
        and f.Profiles[f.Player].Pending == nil,
        "already-stolen purchase remains paid, credited once, and clears recovery intent")
end

do
    local f = attached()
    local profile, house = f.Profiles[f.Player], f.Houses:List(f.Player)[1]
    profile.Income[house.Id] = 37
    check(f.Houses:Sell(f.Player, house.Id, "true") and #f.Notices > 0 and f.Notices[#f.Notices].Kind == "ConfirmSell",
        "selling requires literal server confirmation boolean")
    check(#f.Houses:List(f.Player) == 1 and profile.Cash == 500, "confirmation request does not sell or pay")
    f.SaveModes = { "success", "fail" }
    check(f.Houses:Sell(f.Player, house.Id, true), "sale commits canonical removal before profile finalization")
    local pending = clone(f.Durable[f.Player].Pending)
    check(pending.Kind == "Sell" and pending.ExpectedRevision == 1 and pending.Price == 125,
        "sale persists exact revision, server half-price and operation marker")
    check(f.Context.Ownership:Get(house.Id).OwnerId == 0 and f.Context.Ownership:Get(house.Id).Revision == 2,
        "sale creates revisioned canonical tombstone")
    check(profile.Cash == 625 and profile.Bank == 37 and profile.Income[house.Id] == nil,
        "sale moves old rent to bank and credits only price once")
    check(not f.Houses:Sell(f.Player, house.Id, true), "repeat sell cannot repay removed cache record")
    check(reload(f, f.Player) and #f.Houses:List(f.Player) == 0,
        "saved sale intent recovers committed tombstone on rejoin")
    profile = f.Profiles[f.Player]
    check(profile.Cash == 625 and profile.Bank == 37 and profile.Statistics.TotalEarned == 125,
        "ambiguous sale finalization neither duplicates proceeds nor prior rent")
    check(reload(f, f.Player) and f.Profiles[f.Player].Cash == 625 and f.Profiles[f.Player].Bank == 37,
        "fully finalized sale remains idempotent on later joins")
end

do
    local f = attached()
    local house, profile = f.Houses:List(f.Player)[1], f.Profiles[f.Player]
    f.WriteFailure = "House_" .. house.Id
    check(not f.Houses:Sell(f.Player, house.Id, true), "canonical sale outage does not pay money")
    check(profile.Pending and profile.Cash == 500 and f.Durable[f.Player].Pending.Kind == "Sell",
        "uncommitted sale retains durable intent without credit")
    f.WriteFailure = nil
    check(f.Context.Ownership:Transfer(house.Id, f.Player.UserId, 1, f.Other.UserId, 1, "winner-after-sale-outage"),
        "other owner can win canonical race before conflicted sale retry")
    f.Houses:Tick(1); drain()
    check(profile.Pending == nil and profile.Cash == 500 and profile.Statistics.TotalEarned == 0,
        "conflicted sale recovery cannot pay for someone else's canonical house")
end

do
    local f = fixture()
    local old = seed(f, "income-transfer", 1, "garden_cottage", "Gold", "Giant")
    check(f.Houses:Attach(f.Player) and f.Houses:Attach(f.Other), "attach both transfer profiles")
    f.Profiles[f.Player].Income[old.Id] = 123.5
    f.Clock += 25
    local moved = f.Context.Ownership:Transfer(old.Id, f.Player.UserId, 1, f.Other.UserId, 2, "income-move")
    check(moved and f.Houses:Rate(moved) == 40, "gold giant rent multiplier applied once")
    f.Houses:ApplyTransfer(f.Player, f.Other, old, moved)
    check(f.Profiles[f.Player].Bank == 123.5 and f.Profiles[f.Player].Income[old.Id] == nil,
        "all already-earned source rent stays in victim bank")
    check(f.Profiles[f.Other].Income[old.Id] == 0 and f.Profiles[f.Other].Statistics.Stolen == 1,
        "new owner receives zero prior rent and one steal statistic")
    check(not f.Houses.Records[f.Player][old.Id] and f.Houses.Records[f.Other][old.Id].OwnerId == f.Other.UserId,
        "single cached owner matches canonical transfer")
    f.Houses:Tick(1)
    check(f.Profiles[f.Other].Income[old.Id] == 40 and f.Profiles[f.Player].Bank == 123.5,
        "post-transfer passive income accrues only to new owner")
    check(f.Profiles[f.Other].Collection.garden_cottage, "stolen house unlocks new owner collection")
end

do
    local f = fixture()
    local record = seed(f, "refresh-transfer", 1, "garden_cottage")
    check(f.Houses:Attach(f.Player) and f.Houses:Attach(f.Other), "attach canonical refresh participants")
    f.Profiles[f.Player].Income[record.Id] = 33
    local moved = f.Context.Ownership:Transfer(record.Id, f.Player.UserId, 1, f.Other.UserId, 2, "refresh-new-owner")
    check(moved ~= nil, "ledger may commit transfer before local display handoff")
    f.ReadFailure = "Owner_" .. f.Player.UserId
    check(not f.Houses:Refresh(f.Player) and f.Houses.Records[f.Player][record.Id]
        and f.Profiles[f.Player].Income[record.Id] == 33,
        "refresh read outage retains source cache and rent instead of treating missing read as loss")
    f.ReadFailure = nil
    check(f.Houses:Refresh(f.Player) and not f.Houses.Records[f.Player][record.Id]
        and f.Profiles[f.Player].Bank == 33 and f.Profiles[f.Player].Income[record.Id] == nil,
        "canonical refresh banks removed source rent and removes stale house")
    check(f.Houses:Refresh(f.Other) and f.Houses.Records[f.Other][record.Id].OwnerId == f.Other.UserId
        and f.Profiles[f.Other].Income[record.Id] == 0 and f.Profiles[f.Other].Collection.garden_cottage,
        "recipient refresh discovers canonical ownership with fresh rent and collection")
    check(f.Houses:Refresh(f.Player) and f.Profiles[f.Player].Bank == 33,
        "repeat refresh cannot re-bank already removed source income")
end

do
    local f = fixture()
    local record = seed(f, "offline-bounds", 1, "garden_cottage")
    f.Profiles[f.Player].HasStarter = true
    f.Profiles[f.Player].LastSeen = 100
    f.Ledger["House_offline-bounds"].OwnedSince = 1900
    f.Ledger["House_offline-bounds"].BuildReadyAt = 1950
    f.Clock = 2000
    check(f.Houses:Attach(f.Player), "offline calculation loads canonical ownership")
    check(f.Profiles[f.Player].Bank == 5 * 50 * Config.Game.OfflineMultiplier,
        "offline income starts after both ownership transfer and construction")
    check(f.Profiles[f.Player].LastSeen == 2000 and f.Profiles[f.Player].Income[record.Id] == 0,
        "offline reward advances accrual watermark and stays banked")
    local bounded = fixture()
    seed(bounded, "offline-cap", 1, "garden_cottage")
    bounded.Profiles[bounded.Player].HasStarter = true
    bounded.Profiles[bounded.Player].LastSeen = 0
    bounded.Clock = 100000
    check(bounded.Houses:Attach(bounded.Player) and bounded.Profiles[bounded.Player].Bank
        == 5 * Config.Game.OfflineMaxSeconds * Config.Game.OfflineMultiplier,
        "offline accrual cannot exceed configured four-hour cap")
    local future = fixture()
    seed(future, "future-build", 1)
    future.Profiles[future.Player].HasStarter = true
    future.Ledger["House_future-build"].BuildReadyAt = future.Clock + 60
    check(future.Houses:Attach(future.Player) and future.Profiles[future.Player].Bank == 0,
        "future construction yields zero offline income without negative balances")
    local missing = fixture()
    missing.Profiles[missing.Player].HasStarter = true
    missing.Profiles[missing.Player].Bank = 7
    missing.Profiles[missing.Player].Income["stolen-offline"] = 19
    check(missing.Houses:Attach(missing.Player) and missing.Profiles[missing.Player].Bank == 26
        and missing.Profiles[missing.Player].Income["stolen-offline"] == nil,
        "profile rent for no-longer-owned houses recovers to victim bank on join")
end

do
    local f = attached()
    local p, profile, house = f.Player, f.Profiles[f.Player], f.Houses:List(f.Player)[1]
    profile.Bank, profile.Income[house.Id], profile.Cash = 7, 50, Config.Game.MaxCash - 10
    check(f.Houses:Collect(p), "partial collection at wallet cap succeeds")
    check(profile.Cash == Config.Game.MaxCash and profile.Bank == 0 and profile.Income[house.Id] == 47,
        "wallet cap credits ten and preserves all forty-seven uncollected rent")
    check(profile.Statistics.TotalEarned == 10, "collection earnings statistic counts actual credited cash")
    check(not f.Houses:Collect(p) and profile.Income[house.Id] == 47, "full wallet cannot delete remaining rent")
    profile.Cash -= 100
    profile.Bank = 12
    check(f.Houses:Collect(p, house.Id) and profile.Income[house.Id] == 0 and profile.Bank == 12,
        "single-house pad collects that income without consuming banked old rent")
    check(f.Houses:Collect(p) and profile.Bank == 0, "global home pad collects bank after individual pads")
    check(not f.Houses:Collect(p, "unknown") and not f.Houses:Collect(p, {}),
        "client UID cannot address missing or malformed house")
end

do
    local f = attached()
    local p, profile = f.Player, f.Profiles[f.Player]
    profile.Cash = 1e6
    for slot = 2, Config.Game.StartingSlots do f.Houses.Reserved[p][slot] = "carry-" .. slot end
    local before = profile.Cash
    check(f.Houses:FreeSlot(p) == nil and not f.Houses:Buy(p, "starter_cottage") and profile.Cash == before,
        "incoming carried houses reserve pads; full base purchase cannot oversubscribe")
    f.Houses.Reserved[p][5] = nil
    check(f.Houses:FreeSlot(p) == 5 and f.Houses:Buy(p, "starter_cottage"),
        "purchase selects genuine free slot while retaining other incoming reservations")
    check(f.Houses:List(p)[2].Slot == 5, "committed purchase lands on only unreserved pad")
    local bad = fixture()
    seed(bad, "slot-a", 1); seed(bad, "slot-b", 1)
    check(not bad.Houses:Attach(bad.Player), "saved canonical overlapping pads fail attachment closed")
    local unavailable = fixture()
    seed(unavailable, "slot-unavailable", Config.Game.StartingSlots + 1)
    check(not unavailable.Houses:Attach(unavailable.Player), "saved out-of-capacity pad never silently discarded")
end

do
    for _, block in ipairs({ "Frozen", "Away", "Pending", "Busy", "SourceBusy", "Closing", "Released" }) do
        for _, method in ipairs({ "Buy", "Sell", "Collect" }) do
            local f = attached()
            local p, profile, house = f.Player, f.Profiles[f.Player], f.Houses:List(f.Player)[1]
            profile.Cash, profile.Bank = 5000, 20
            if block == "Frozen" then f.Writable = false
            elseif block == "Away" then f.Home = false
            elseif block == "Pending" then profile.Pending = { Kind = "Buy" }
            elseif block == "Busy" then f.Houses.Busy[p] = "transaction"
            elseif block == "SourceBusy" then f.SourceBusy[p] = true
            elseif block == "Closing" then f.Context.Closing = true
            else f.Profiles[p] = nil end
            local result
            if method == "Buy" then result = f.Houses:Buy(p, "starter_cottage")
            elseif method == "Sell" then result = f.Houses:Sell(p, house.Id, true)
            else result = f.Houses:Collect(p) end
            check(not result and profile.Cash == 5000 and profile.Bank == 20,
                method .. " cannot change economy while " .. block)
        end
    end
    local f = attached()
    for _, id in ipairs({ "unknown", "", {}, 123 }) do
        check(not f.Houses:Buy(f.Player, id) and f.Profiles[f.Player].Cash == 500,
            "server rejects unknown/malformed shop ID without debit")
    end
    check(not f.Houses:Sell(f.Player, "unknown", true) and not f.Houses:Sell(f.Player, {}, true),
        "server rejects missing/malformed sale UID")
end

do
    local f = attached()
    f.Profiles[f.Player].Cash = 1e6
    for _, block in ipairs({ "Pending", "Busy" }) do
        if block == "Pending" then f.Profiles[f.Player].Pending = { Kind = "Sell" }
        else f.Houses.Busy[f.Player] = "transfer-commit" end
        for _, method in ipairs({ "BaseUpgrade", "TreadmillUpgrade", "SecurityUpgrade", "ClaimDaily" }) do
            local before = f.Profiles[f.Player].Cash
            check(not f.Progression[method](f.Progression, f.Player) and f.Profiles[f.Player].Cash == before,
                "atomic house " .. block .. " blocks " .. method)
        end
        f.Profiles[f.Player].Pending, f.Houses.Busy[f.Player] = nil, nil
    end
    local house = f.Houses:List(f.Player)[1]
    f.Profiles[f.Player].Cash = Config.Game.MaxCash - 10
    local before = f.Profiles[f.Player].Statistics.TotalEarned
    check(f.Houses:Sell(f.Player, house.Id, true) and f.Profiles[f.Player].Cash == Config.Game.MaxCash,
        "sale cannot overfill wallet")
    check(f.Profiles[f.Player].Statistics.TotalEarned == before + 10,
        "sale earnings statistic counts actual credited proceeds at wallet cap")
end

print("HouseService: " .. checks .. " actual-source economy, recovery, ownership, income and exploit checks passed.")
