-- Engine/storage boundaries are fakes; StealService itself is the actual source.
local checks = 0
local function check(value, message) assert(value, message); checks += 1 end
local vectors = {}
local function vector(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vectors) end
vectors.__sub = function(a, b) return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vectors.__add = function(a, b) return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vectors.__mul = function(a, n) return vector(a.X * n, a.Y * n, a.Z * n) end
vectors.__index = function(a, key)
    if key == "Magnitude" then return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end
    if key == "Unit" then return vector(a.X / a.Magnitude, a.Y / a.Magnitude, a.Z / a.Magnitude) end
end
Vector3 = { new = vector }
Enum = { Material = { Air = "Air" } }

local function fixture()
    local f = { Time = 100, Notifications = {}, Calls = {}, Deferred = {}, Id = 0, SourceModel = {} }
    local function player(id)
        return { UserId = id, Root = { Position = vector(0, 0, 0), CFrame = { LookVector = vector(1, 0, 0) } },
            Humanoid = { Health = 100, WalkSpeed = 20, FloorMaterial = "Ground" }, Character = {} }
    end
    f.Owner, f.Thief, f.Other = player(1), player(2), player(3)
    local profiles = {}
    for _, p in ipairs({ f.Owner, f.Thief, f.Other }) do profiles[p] = { Statistics = { Defended = 0 }, Income = {} } end
    local ctx = { Config = { Game = { InteractionRadius = 12, CarrySpeed = 12,
        StealHoldSeconds = 2, CarryTimeoutSeconds = 90, BatRange = 9, BatCooldown = 1.2 } },
        Clock = function() return f.Time end, Now = function() return f.Time end,
        Spawn = function(callback) if f.Defer then table.insert(f.Deferred, callback) else callback() end end,
        Notify = function(p, text, kind) table.insert(f.Notifications, { p, text, kind }) end,
        Publish = function(_p) end }
    ctx.HttpService = { GenerateGUID = function() f.Id += 1; return "token" .. f.Id end }
    ctx.Data = { Get = function(_, p) return profiles[p] end,
        IsWritable = function(_, p) return profiles[p] ~= nil and not p.Frozen end }
    ctx.AntiExploit = {
        Character = function(_, p) if p.Humanoid.Health > 0 then return p.Root, p.Humanoid end end,
        ValidateMovement = function(_, p) return not p.BadMovement end,
        CanInteract = function(_, p, target, radius)
            f.InteractionTarget = target
            return not p.NoLOS and not p.BadMovement and (p.Root.Position - target.Position).Magnitude <= radius
        end,
        AllowTeleport = function(_, p) p.AllowedKnockback = true end,
    }
    ctx.Progression = {
        IsLocked = function(_, p) return p.Locked == true end,
        Speed = function(_, p) return p.Speed or 20 end,
    }
    local plots = {}
    for _, p in ipairs({ f.Owner, f.Thief, f.Other }) do plots[p] = { Position = vector(0, 0, 0) } end
    ctx.World = {
        GetPlot = function(_, p) return plots[p] end,
        SlotPosition = function(_, plot, _slot) return plot.Position end,
        GetHouseModel = function() return f.SourceModel end,
        AtHome = function(_, p) return p.Home == true end,
        RemoveHouse = function(_, p, uid) f.Removed = { p, uid } end,
        RenderHouse = function(_, p, record) f.Rendered = { p, record } end,
        CarryModel = function(_, p, record) f.CarryRendered = { p, record }; return {} end,
        ClearCarry = function(_, p) f.ClearCount = (f.ClearCount or 0) + 1; f.Cleared = p end,
        RemovePrefab = function(_, offer) offer.Model = nil end,
    }
    local record = { Id = "house", DefinitionId = "Starter", Variant = "Normal", Size = "Normal",
        OwnerId = 1, Slot = 1, Revision = 1, BuildReadyAt = 50 }
    local canonical = { house = record }
    ctx.Houses = { Records = { [f.Owner] = { house = record }, [f.Thief] = {}, [f.Other] = {} },
        Busy = {}, Reserved = {}, Capacity = function(_, p) return p.Capacity or 10 end,
        FreeSlot = function(self, p)
            for slot = 1, self:Capacity(p) do
                local free = not (self.Reserved[p] or {})[slot]
                for _, house in pairs(self.Records[p] or {}) do if house.Slot == slot then free = false end end
                if free then return slot end
            end
        end,
        ApplyTransfer = function(self, source, target, oldRecord, newRecord)
            self.Records[source][oldRecord.Id] = nil
            self.Records[target][newRecord.Id] = newRecord
            if profiles[source] then
                profiles[source].Bank = (profiles[source].Bank or 0) + (profiles[source].Income[oldRecord.Id] or 0)
                profiles[source].Income[oldRecord.Id] = nil
            end
            if profiles[target] then profiles[target].Income[newRecord.Id] = 0 end
            f.Applied = newRecord
        end,
        Refresh = function(self, p)
            f.Refreshes = (f.Refreshes or 0) + 1
            if f.RefreshFail then return false, "Unavailable" end
            if f.OnRefresh then f.OnRefresh(p) end
            self.Records[p] = {}
            for uid, house in pairs(canonical) do
                if house.OwnerId == p.UserId then self.Records[p][uid] = house end
            end
            return true
        end,
        SecureWild = function(self, p, offer, state)
            local old = canonical[offer.Id]
            if old and old.OwnerId == p.UserId and old.OperationId == state.Token then return old end
            if not ctx.Steal:_valid(state, true) then return nil, "Invalid" end
            state.IntentPrepared = true
            if f.WildFail then profiles[p].Pending = { Kind = "Wild", Id = offer.Id }; return nil, "Unavailable" end
            local award = { Id = offer.Id, OwnerId = p.UserId, Revision = 1, Slot = state.Slot,
                Size = state.Record.Size, DefinitionId = offer.DefinitionId, OperationId = state.Token }
            canonical[award.Id], self.Records[p][award.Id] = award, award
            return award
        end,
    }
    ctx.Players = { GetPlayerByUserId = function(_, id)
        for _, p in ipairs({ f.Owner, f.Thief, f.Other }) do
            if p.UserId == id and profiles[p] then return p end
        end
    end }
    ctx.Ownership = {
        Transfer = function(_, uid, owner, revision, target, slot, token, validate)
            table.insert(f.Calls, { uid, owner, revision, target, slot, token })
            local old = canonical[uid]
            if old.OperationId == token then return old end
            if old.OwnerId ~= owner or old.Revision ~= revision or not validate() then return nil, "Invalid" end
            if f.TransferFail then return nil, "Unavailable" end
            local new = { Id = uid, OwnerId = target, Revision = revision + 1, Slot = slot,
                OperationId = token, DefinitionId = old.DefinitionId }
            canonical[uid] = new
            if f.OnCommit then f.OnCommit() end
            if f.Ambiguous then return nil, "LostResponse" end
            return new
        end,
        Get = function(_, uid) if f.ReadFail then return nil, "Unavailable" end; return canonical[uid] end,
    }
    local offer = { Id = "wild", DefinitionId = "Villa", Variant = "Gold", Size = "Normal",
        Position = vector(0, 0, 0), Model = {}, RequiredSpeed = 20 }
    ctx.Wild = { Offers = { wild = offer },
        Get = function(self, uid) return self.Offers[uid] end,
        Claim = function(self, uid, p)
            local item = self.Offers[uid]
            if not item or item.Busy then return nil end
            item.Busy = p; return item
        end,
        Release = function(self, uid, p)
            local item = self.Offers[uid]
            if item and item.Busy == p then item.Busy, item.Model = nil, {}; f.WildReturned = item.Position end
        end,
        Finish = function(self, uid, _p) self.Offers[uid] = nil; f.WildFinished = true end,
    }
    f.Context, f.Profiles, f.Canonical, f.Offer, f.Plots = ctx, profiles, canonical, offer, plots
    f.Service = StealService.new(ctx); ctx.Steal = f.Service
    function f:Advance(seconds) self.Time += seconds; self.Service:Tick(seconds) end
    function f:Carry() check(self.Service:Attempt(self.Thief, "house"), "valid theft begins"); self:Advance(2) end
    return f
end

do
    local f = fixture()
    check(not f.Service:Attempt(f.Owner, "house"), "owner cannot steal own house")
    check(not f.Service:Attempt(f.Thief, {}), "nonstring UID rejected")
    check(not f.Service:Attempt(f.Thief, "unknown"), "unknown UID rejected")
    f.Thief.Root.Position = vector(13, 0, 0)
    check(not f.Service:Attempt(f.Thief, "house"), "out of range rejected")
    f.Thief.Root.Position = vector(0, 0, 0); f.Thief.NoLOS = true
    check(not f.Service:Attempt(f.Thief, "house"), "occluded pickup rejected")
    f.Thief.NoLOS = false; f.Thief.BadMovement = true
    check(not f.Service:Attempt(f.Thief, "house"), "teleported pickup rejected")
    f.Thief.BadMovement = false; f.Owner.Locked = true
    check(not f.Service:Attempt(f.Thief, "house"), "locked base rejects theft even inside")
    f.Owner.Locked = false; f.Thief.Frozen = true
    check(not f.Service:Attempt(f.Thief, "house"), "frozen thief lease rejects theft")
    f.Thief.Frozen = false; f.Owner.Frozen = true
    check(not f.Service:Attempt(f.Thief, "house"), "frozen victim lease rejects theft")
    f.Owner.Frozen = false; f.Profiles[f.Owner].Pending = {}
    check(not f.Service:Attempt(f.Thief, "house"), "pending victim economic transaction rejects theft")
    f.Profiles[f.Owner].Pending = nil; f.Thief.Capacity = 0
    check(not f.Service:Attempt(f.Thief, "house"), "full destination rejects theft")
end
do
    local f = fixture()
    check(f.Service:Attempt(f.Thief, "house"), "hold starts")
    check(not f.Service:IsHeld("house"), "hold does not pause rent")
    check(not f.Service:Attempt(f.Other, "house"), "UID mutex prevents contested hold")
    check(not f.Service:AttemptWild(f.Thief, "wild"), "one carry/hold per player")
    check(f.Context.Houses.Reserved[f.Thief][1] ~= nil, "destination pad reserved during hold")
    f:Advance(1.999)
    check(f.Service.Carriers[f.Thief].Phase == "Hold" and not f.Removed, "server hold timer cannot finish early")
    f:Advance(0.0011)
    check(f.Service.Carriers[f.Thief].Phase == "Carry", "hold completes after server time")
    check(f.Service:IsHeld("house") and f.Removed ~= nil, "carry pauses rent and hides original model")
    check(f.Canonical.house.OwnerId == f.Owner.UserId, "pickup never transfers ownership")
    check(f.Thief.Humanoid.WalkSpeed == 12, "carry server movement speed enforced")
    f.Thief.Humanoid.WalkSpeed = 90; f:Advance(0.2)
    check(f.Thief.Humanoid.WalkSpeed == 12, "carry speed reapplied every tick")
    f.Profiles[f.Owner].Income.house = 41
    f.Thief.Home = true; f:Advance(0.1)
    check(f.Canonical.house.OwnerId == f.Thief.UserId and f.Canonical.house.Revision == 2, "own-base arrival commits CAS ownership")
    check(f.Context.Houses.Records[f.Owner].house == nil and f.Context.Houses.Records[f.Thief].house ~= nil, "runtime ownership mirrors durable commit")
    check(f.Profiles[f.Owner].Bank == 41 and f.Profiles[f.Thief].Income.house == 0, "victim accrued rent banked and recipient starts at zero")
    check(not f.Service.Carriers[f.Thief] and not f.Service.Held.house, "completed carry clears UID/player mutex")
    check(not f.Context.Houses.Reserved[f.Thief][1] and not f.Context.Houses.Busy[f.Thief], "successful commit releases reservations")
    check(f.Thief.Humanoid.WalkSpeed == 20, "normal speed restored")
end
do
    local f = fixture(); f.Service:Attempt(f.Thief, "house"); f.Thief.NoLOS = true; f:Advance(1)
    check(not f.Service.Carriers[f.Thief] and not f.Removed, "hold continuously rechecks line of sight")
    f.Thief.NoLOS = false; f:Carry(); f.Owner.Locked = true; f:Advance(0.1)
    check(not f.Service.Carriers[f.Thief] and f.Rendered ~= nil and f.Canonical.house.OwnerId == 1, "new gate lock returns carried house")
    f.Owner.Locked = false; f:Carry(); f.Thief.Humanoid.Health = 0; f:Advance(0.1)
    check(not f.Service.Carriers[f.Thief] and f.Canonical.house.OwnerId == 1, "death cancels provisional carry")
end
do
    local f = fixture(); f:Carry(); f:Advance(90)
    check(not f.Service.Carriers[f.Thief] and f.Rendered ~= nil, "carry timeout returns original source slot")
    f:Carry(); f.Service:Release(f.Owner)
    check(not f.Service.Carriers[f.Thief] and f.Canonical.house.OwnerId == 1, "victim departure returns uncommitted ownership")
    f:Carry(); f.Thief.Frozen = true; f:Advance(0.1)
    check(not f.Service.Carriers[f.Thief] and #f.Calls == 0, "lease freeze cancels before durable transfer")
end
do
    local f = fixture(); f.Defer = true; f:Carry(); f.Thief.Home = true; f:Advance(0.1)
    check(f.Service.Carriers[f.Thief].Phase == "Committing", "yielding transaction has explicit frozen phase")
    check(f.Context.Houses.Busy[f.Owner] and f.Context.Houses.Busy[f.Thief], "both economic profiles locked while committing")
    f.Service:Cancel(f.Thief, "Left")
    check(f.Service.Held.house ~= nil and f.Context.Houses.Reserved[f.Thief][1] ~= nil, "cancellation cannot release in-flight UID/pad")
    f.Deferred[1]()
    check(not f.Service.Carriers[f.Thief] and f.Canonical.house.OwnerId == 1, "precommit cancellation fails closure and rolls back known source")
    check(f.Rendered ~= nil, "known unchanged canonical owner permits original render")
end
do
    local f = fixture(); f:Carry(); f.OnCommit = function() f.Service:Cancel(f.Thief, "Disconnected") end
    f.Ambiguous = true; f.Thief.Home = true; f:Advance(0.1)
    check(f.Canonical.house.OwnerId == 2 and f.Applied ~= nil, "ambiguous successful commit reconciled despite concurrent cancel")
    check(f.Rendered == nil, "committed house never restored to stale victim")
    check(not f.Service.Held.house, "reconciled commit clears mutex")
end
do
    local f = fixture(); f:Carry(); f.TransferFail, f.ReadFail = true, true
    f.Thief.Home = true; f:Advance(0.1)
    local state = f.Service.Carriers[f.Thief]
    check(state and state.Phase == "Committing" and not f.Rendered, "unavailable canonical read cannot imply transfer failure")
    check(f.Context.Houses.Busy[f.Owner] ~= nil and f.Service.Held.house == state, "unknown outcomes retain economic and UID locks")
    f.TransferFail, f.ReadFail = false, false; f:Advance(3)
    check(f.Applied and not f.Service.Carriers[f.Thief], "retry resolves transient uncertain transfer")
end
do
    local f = fixture(); f:Carry(); f.Defer = true; f.Thief.Home = true; f:Advance(0.1)
    f.Owner.Locked = true; f.Deferred[1]()
    check(not f.Applied and f.Canonical.house.OwnerId == 1, "gate state rechecked inside ledger completion closure")
    f.Owner.Locked = false; f:Carry(); f.Defer = false; f.Thief.Home = true
    f.Context.Houses.Records[f.Thief].occupied = { Slot = 1 }; f:Advance(0.1)
    check(not f.Service.Carriers[f.Thief] and not f.Applied, "destination capacity/collision revalidated at arrival")
end
do
    local f = fixture(); f.Thief.Speed = 19
    check(not f.Service:AttemptWild(f.Thief, "wild"), "NPC territory checks server-earned speed")
    f.Thief.Speed = 20
    check(f.Service:AttemptWild(f.Thief, "wild"), "wild hold claims server offer")
    check(f.Offer.Busy == f.Thief and not f.Service:AttemptWild(f.Other, "wild"), "wild site reservation rejects competitors")
    f.Offer.Size = "Big"; f:Advance(2)
    check(f.Service.Carriers[f.Thief].Record.Size == "Big", "pickup freezes current server-grown size")
    f.Offer.Size = "Giant"; f.Thief.Home = true; f:Advance(0.1)
    check(f.Canonical.wild.Size == "Big" and f.Canonical.wild.OwnerId == 2, "wild securing uses frozen size and durable canonical UID")
    check(f.WildFinished and f.Context.Wild:Get("wild") == nil, "successful wild carry retires reserved source")
end
do
    local f = fixture(); local site = f.Offer.Position
    f.Service:AttemptWild(f.Thief, "wild"); f:Advance(2); f.Service:Cancel(f.Thief)
    check(f.Offer.Busy == nil and f.Offer.Model ~= nil and f.WildReturned == site, "wild cancellation returns exact reserved site")
    check(f.Service:AttemptWild(f.Other, "wild"), "returned wild offer available to another player")
    f.Other.Speed = 0; f:Advance(2)
    check(not f.Service.Carriers[f.Other] and f.Offer.Busy == nil, "speed gate rechecked throughout hold")
end
do
    local f = fixture(); f.Service:AttemptWild(f.Thief, "wild"); f:Advance(2)
    f.WildFail = true; f.Thief.Home = true; f:Advance(0.1); f.Service:Release(f.Thief)
    check(f.Service.Held.wild and f.Offer.Busy == f.Thief and not f.WildReturned, "durable pending wild award cannot be returned and awarded twice")
end
do
    local f = fixture(); f.Service:AttemptWild(f.Thief, "wild"); f:Advance(2)
    f.WildFail = true; f.Thief.Home = true; f:Advance(0.1)
    local state = f.Service.Carriers[f.Thief]
    check(state.IntentPrepared, "wild durable intent is remembered outside the live profile")
    f.Profiles[f.Thief] = nil
    f.Service:Release(f.Thief); f:Advance(3)
    check(f.Service.Carriers[f.Thief] == state and f.Offer.Busy == f.Thief and not f.WildReturned,
        "profile unload is not evidence that a saved wild intent was cancelled")
    f.Canonical.wild = { Id = "wild", OwnerId = f.Thief.UserId, Revision = 1,
        Slot = state.Slot, OperationId = state.Token }
    f:Advance(3)
    check(f.WildFinished and not f.Service.Carriers[f.Thief],
        "later canonical creation reconciles prepared wild award after departure")
end
do
    local f = fixture(); f:Carry()
    check(f.InteractionTarget.Model == f.SourceModel,
        "hold line of sight recognizes the actual house model as its target")
    local state = f.Service.Carriers[f.Thief]
    f.Canonical.house = { Id = "house", OwnerId = f.Other.UserId, Revision = 2,
        Slot = 1, OperationId = "other-operation", DefinitionId = "Starter" }
    f.Thief.Home = true; f:Advance(0.1)
    check(not f.Service.Carriers[f.Thief] and not f.Service.Held.house,
        "conclusive competing ownership does not freeze stale carry forever")
    check(not f.Context.Houses.Records[f.Owner].house and not f.Context.Houses.Records[f.Thief].house
        and f.Context.Houses.Records[f.Other].house == f.Canonical.house,
        "all live affected bases reconcile from canonical ownership")
    check(f.Rendered and f.Rendered[1] == f.Other and not f.Context.Houses.Reserved[f.Thief][state.Slot],
        "changed canonical owner is never rolled back to the victim")
end
do
    local f = fixture(); f:Carry(); f.RefreshFail = true
    f.Canonical.house = { Id = "house", OwnerId = 0, Revision = 3, Slot = 0, OperationId = "later-sale" }
    f.Thief.Home = true; f:Advance(0.1)
    local state = f.Service.Carriers[f.Thief]
    check(state and f.Context.Houses.Busy[f.Owner] == state.Token and not f.Rendered,
        "failed reconciliation keeps a sold UID and destination frozen")
    f.RefreshFail = false
    f.OnRefresh = function()
        local calls = #f.Calls
        f:Advance(4)
        check(#f.Calls == calls and state.InFlight,
            "yielding canonical reconciliation cannot start a second in-flight transfer")
    end
    f:Advance(3)
    check(not f.Service.Carriers[f.Thief] and not f.Context.Houses.Records[f.Owner].house,
        "tombstone reconciliation clears stale carry after store recovery")
end
do
    local f = fixture(); f:Carry(); f.TransferFail = true
    f.Thief.Home = true; f:Advance(0.1)
    check(not f.Service.Carriers[f.Thief] and f.Rendered ~= nil,
        "known unchanged canonical source safely returns an uncommitted transfer")
end
do
    local f = fixture(); f:Carry(); f.Owner.Root.Position = vector(10, 0, 0)
    check(not f.Service:Bat(f.Owner) and f.Service.Carriers[f.Thief], "bat range enforced")
    f:Advance(1.3); f.Owner.Root.Position = vector(0, 0, 0); f.Owner.NoLOS = true
    check(not f.Service:Bat(f.Owner) and f.Service.Carriers[f.Thief], "bat line of sight enforced")
    f:Advance(1.3); f.Owner.NoLOS = false; f.Owner.Humanoid.FloorMaterial = "Air"
    check(not f.Service:Bat(f.Owner), "airborne bat cannot inject knockback")
    f.Owner.Humanoid.FloorMaterial = "Ground"
    check(f.Service:Bat(f.Owner), "near grounded victim can interrupt thief")
    check(not f.Service.Carriers[f.Thief] and f.Canonical.house.OwnerId == 1, "bat returns provisional ownership")
    check(f.Profiles[f.Owner].Statistics.Defended == 1 and f.Thief.AllowedKnockback, "server defense statistic and authorized knockback")
    check(not f.Service:Bat(f.Owner), "bat cooldown blocks repeated hits")
end
do
    local f = fixture(); f:Carry(); local old = f.Service.Carriers[f.Thief]
    f.Service:Cancel(f.Thief); f:Carry(); local newer = f.Service.Carriers[f.Thief]
    f.Service:_cleanup(old)
    check(f.Service.Carriers[f.Thief] == newer and f.Service.Held.house == newer,
        "late cleanup cannot clear a newer carry state")
    check(f.Context.Houses.Reserved[f.Thief][newer.Slot] == newer.Token,
        "late cleanup cannot remove a newer reservation token")
end
do
    local f = fixture()
    f.Context.Ready = { [f.Thief] = true }
    check(not f.Service:Attempt(f.Thief, "house"), "joining victim cannot be robbed before spawn shield is initialized")
    f.Context.Ready[f.Owner] = true
    check(f.Service:Attempt(f.Thief, "house"), "ready unlocked victim may be robbed")
end
print(string.format("PASS: %d production stealing state checks", checks))
