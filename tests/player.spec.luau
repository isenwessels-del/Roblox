-- Production join/cleanup lifecycle. Signals and adjacent services are injected boundaries.
-- Character is nil here: actual spawning, tools and physics require Roblox Studio.
local Players = require("../src/server/PlayerService")
local checks = 0
local function check(condition, message) assert(condition, message); checks += 1 end
local function signal()
    local value = { Connections = {}, Disconnects = 0 }
    function value:Connect(callback)
        local connection = { Callback = callback, Connected = true }
        function connection:Disconnect()
            if self.Connected then value.Disconnects += 1; self.Connected = false end
        end
        table.insert(self.Connections, connection)
        return connection
    end
    return value
end
local function fixture()
    local calls, events = {}, {}
    local function called(name)
        calls[name] = (calls[name] or 0) + 1
        table.insert(events, name)
    end
    local ctx = { Players = {}, Ready = {}, Closing = false }
    local player = { UserId = 41, Parent = ctx.Players, Character = nil, CharacterAdded = signal(), Kicks = {} }
    function player:Kick(message) called("Kick"); table.insert(self.Kicks, message) end
    ctx.AntiExploit = { Register = function(_, p) assert(p == player); called("Register") end,
        Remove = function(_, p) assert(p == player); called("AntiRemove") end }
    ctx.Data = { Profile = {}, Load = function(self, p)
        assert(p == player); called("Load")
        if self.OnLoad then self.OnLoad() end
        return self.Profile, self.LoadError
    end, Release = function(_, p) assert(p == player); called("DataRelease") end }
    ctx.World = { Plot = {}, Assign = function(self, p)
        assert(p == player); called("Assign")
        if self.OnAssign then self.OnAssign() end
        return self.Plot
    end, Release = function(_, p) assert(p == player); called("WorldRelease") end }
    ctx.Houses = { Busy = {}, Attached = true, Attach = function(self, p)
        assert(p == player); called("Attach")
        if self.OnAttach then self.OnAttach() end
        return self.Attached, self.AttachError
    end, Release = function(_, p) assert(p == player); called("HouseRelease") end }
    ctx.Steal = { Release = function(_, p) assert(p == player); called("StealRelease") end }
    ctx.Progression = { OnJoin = function(_, p) assert(p == player); called("OnJoin") end,
        Release = function(_, p) assert(p == player); called("ProgressRelease") end }
    ctx.Publish = function(p) assert(p == player); called("Publish") end
    ctx.Notify = function(p, text, kind)
        assert(p == player and type(text) == "string" and kind == "Info"); called("Notify")
    end
    return Players.new(ctx), ctx, player, calls, events
end

do
    local service, ctx, player, calls, events = fixture()
    service:_join(player)
    check(ctx.Ready[player] == true, "successful verified join marks the player ready")
    check(calls.Load == 1 and calls.Assign == 1 and calls.Attach == 1, "join loads one profile, assigns one base and attaches canonical houses")
    check(calls.Register == 1 and #player.CharacterAdded.Connections == 1, "join registers validation and one character subscription")
    check(calls.OnJoin == 1 and calls.Publish == 1 and calls.Notify == 1, "verified join initializes progression and sends one snapshot and welcome")
    check(table.concat(events, ",") == "Register,Load,Assign,Attach,OnJoin,Publish,Notify",
        "progression and snapshot occur only after safe profile and canonical ownership attachment")
    check(#player.Kicks == 0 and service.Characters[player] == nil, "nil Character requires no engine construction and causes no rejection")
    service:_join(player)
    check(calls.Load == 1 and calls.Assign == 1 and calls.Attach == 1 and calls.Publish == 1,
        "duplicate join cannot reload profile, reassign base or reinitialize progression")
end

do
    local service, ctx, player, calls = fixture()
    ctx.Data.OnLoad = function() coroutine.yield("loading") end
    local pending = coroutine.create(function() service:_join(player) end)
    local ok, stage = coroutine.resume(pending)
    check(ok and stage == "loading" and calls.Load == 1 and not ctx.Ready[player], "a yielding save load keeps player unready")
    service:_join(player)
    check(calls.Load == 1 and calls.Assign == nil and #player.CharacterAdded.Connections == 1,
        "concurrent join is rejected while original Data.Load is yielding")
    check(coroutine.resume(pending), "original yielding load can resume")
    check(ctx.Ready[player] and calls.Assign == 1 and calls.OnJoin == 1, "original join completes once after load resumes")
end

do
    local service, ctx, player, calls = fixture()
    ctx.Data.Profile, ctx.Data.LoadError = nil, "SessionInUse"
    service:_join(player)
    check(#player.Kicks == 1 and player.Kicks[1]:find("SessionInUse", 1, true) ~= nil,
        "load failure kicks with save error rather than creating temporary replacement data")
    check(calls.Assign == nil and calls.Attach == nil and calls.OnJoin == nil and calls.Publish == nil,
        "load failure never allocates a plot or grants progression")
    check(not ctx.Ready[player], "failed profile remains unavailable to gameplay router")
    service:_join(player)
    check(calls.Load == 1 and #player.Kicks == 1, "replayed failed join cannot bypass session rejection")
end

do
    local service, ctx, player, calls = fixture()
    player.Parent = nil
    service:_join(player)
    check(next(calls) == nil and #player.CharacterAdded.Connections == 0,
        "player removed before join receives no load, allocation or subscription")
    player.Parent = ctx.Players; ctx.Closing = true
    service:_join(player)
    check(next(calls) == nil and not ctx.Ready[player], "closing server starts no player join")
end

for _, stop in ipairs({ "removed", "closing" }) do
    local service, ctx, player, calls = fixture()
    ctx.Data.OnLoad = function()
        if stop == "removed" then player.Parent = nil else ctx.Closing = true end
    end
    service:_join(player)
    check(calls.DataRelease == 1 and calls.Assign == nil and not ctx.Ready[player],
        stop .. " during load releases opened profile before any world assignment")
    check(#player.Kicks == 0 and calls.OnJoin == nil and calls.Publish == nil,
        stop .. " during load never starts progression or sends a welcome")
end

do
    local service, ctx, player, calls = fixture()
    ctx.Data.Profile = nil
    ctx.Data.OnLoad = function() player.Parent = nil end
    service:_join(player)
    check(#player.Kicks == 0 and calls.Assign == nil and not ctx.Ready[player],
        "departed player with failed load is neither kicked again nor assigned a base")
end

do
    local service, ctx, player, calls = fixture()
    ctx.World.Plot = nil
    service:_join(player)
    check(#player.Kicks == 1 and player.Kicks[1]:find("occupied", 1, true) ~= nil,
        "base exhaustion rejects player instead of sharing someone else's plot")
    check(calls.Attach == nil and calls.OnJoin == nil and not ctx.Ready[player],
        "no available plot grants neither starter ownership nor ready state")
end

do
    local service, ctx, player, calls = fixture()
    ctx.Houses.Attached, ctx.Houses.AttachError = false, "OwnershipStoreUnavailable"
    service:_join(player)
    check(#player.Kicks == 1 and player.Kicks[1]:find("OwnershipStoreUnavailable", 1, true) ~= nil,
        "canonical ownership failure rejects a join with the ledger failure reason")
    check(calls.Assign == 1 and calls.Attach == 1 and calls.OnJoin == nil and calls.Publish == nil and not ctx.Ready[player],
        "failed canonical attachment cannot become ready or publish a fabricated starter home")
end

for _, stop in ipairs({ "removed", "closing" }) do
    local service, ctx, player, calls = fixture()
    ctx.Houses.OnAttach = function()
        if stop == "removed" then player.Parent = nil else ctx.Closing = true end
    end
    service:_join(player)
    check(calls.DataRelease == 1 and calls.HouseRelease == 1 and calls.WorldRelease == 1,
        stop .. " during canonical attachment releases attached houses, assigned base and profile")
    check(calls.StealRelease == 1 and calls.ProgressRelease == 1 and calls.AntiRemove == 1,
        stop .. " after attach cleans all gameplay subsystems")
    check(not ctx.Ready[player] and calls.OnJoin == nil and calls.Publish == nil,
        stop .. " after attach cannot become ready or start progression")
    check(player.CharacterAdded.Disconnects == 1 and service.Connections[player] == nil,
        stop .. " after attach disconnects loading character callback")
end

do
    local service, ctx, player, calls, events = fixture()
    service:_join(player)
    table.clear(events)
    service.Characters[player] = {}
    service:Cleanup(player)
    check(ctx.Ready[player] == nil and service.Characters[player] == nil and service.Connections[player] == nil,
        "cleanup removes readiness, character cache and retained subscription")
    check(calls.StealRelease == 1 and calls.ProgressRelease == 1 and calls.HouseRelease == 1
        and calls.WorldRelease == 1 and calls.AntiRemove == 1, "cleanup releases every player-specific gameplay subsystem")
    check(table.concat(events, ",") == "StealRelease,ProgressRelease,HouseRelease,WorldRelease,AntiRemove",
        "cleanup cancels active carry and movement progression before releasing houses and base")
    check(player.CharacterAdded.Disconnects == 1, "character subscription disconnects exactly once")
    service:Cleanup(player)
    check(calls.StealRelease == 1 and calls.ProgressRelease == 1 and calls.HouseRelease == 1
        and calls.WorldRelease == 1 and calls.AntiRemove == 1 and player.CharacterAdded.Disconnects == 1,
        "duplicate cleanup cannot double-release ownership, world base or connections")
    check(calls.DataRelease == nil, "profile release remains with the bootstrap's ordered shutdown/removal handler")
end

do
    -- Replace only the function's clock/wait environment; no real sleeps or engine task API.
    local originalEnvironment = getfenv(Players.Cleanup)
    local simulatedTime, waits, settle, activeContext, activePlayer = 0, 0, false, nil, nil
    local environment = setmetatable({ os = { clock = function() return simulatedTime end },
        task = { wait = function(seconds)
            waits += 1
            assert(seconds > 0 and seconds <= 0.05, "cleanup wait stays a short scheduler yield")
            simulatedTime += seconds
            if settle and waits == 3 then activeContext.Houses.Busy[activePlayer] = nil end
        end } }, { __index = originalEnvironment })
    setfenv(Players.Cleanup, environment)
    local service, ctx, player, calls = fixture()
    activeContext, activePlayer = ctx, player
    service:_join(player)
    ctx.Houses.Busy[player], settle = true, true
    service:Cleanup(player)
    check(waits == 3 and simulatedTime < 1 and not ctx.Houses.Busy[player],
        "cleanup yields for an outstanding canonical write to settle")
    check(calls.HouseRelease == 1 and calls.WorldRelease == 1 and calls.StealRelease == 1,
        "settled operation proceeds to a single ordinary subsystem release")
    service:Cleanup(player)
    check(waits == 3 and calls.HouseRelease == 1, "duplicate settled cleanup performs no further waits or releases")
    service, ctx, player, calls = fixture()
    activeContext, activePlayer = ctx, player
    simulatedTime, waits, settle = 0, 0, false
    service:_join(player)
    ctx.Houses.Busy[player] = true
    service:Cleanup(player)
    check(simulatedTime >= 20 and simulatedTime <= 20.05 and waits <= 401,
        "unresponsive ownership operation cannot hold removal cleanup beyond bounded twenty-second grace")
    check(calls.HouseRelease == 1 and calls.WorldRelease == 1 and player.CharacterAdded.Disconnects == 1,
        "bounded grace still removes base and loading connection once")
    setfenv(Players.Cleanup, originalEnvironment)
end

print("PASS: " .. checks .. " production PlayerService join, yielding-load, fail-closed and cleanup checks")
