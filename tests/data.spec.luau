-- Runs the real server module with an injected deterministic atomic DataStore.
-- No Roblox service is needed; the store also replays callbacks like UpdateAsync.
local DataService = require("../src/server/DataService")
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
local defaults = 0
local schema = {}
function schema.New(now)
    defaults += 1
    return { Version = 2, Cash = 500, Inventory = {}, House = { Furniture = {} }, LastSeen = now }
end
function schema.Migrate(raw, now)
    if type(raw) ~= "table" or type(raw.Version) ~= "number" or raw.Version > 2 then
        return nil, "UnsupportedSchemaVersion"
    end
    raw.Version = 2
    raw.Inventory = raw.Inventory or {}
    raw.House = raw.House or { Furniture = {} }
    raw.LastSeen = now
    return raw
end

local function makeStore()
    local store = { Records = {}, Calls = 0, Writes = 0, Fail = 0 }
    function store:UpdateAsync(key, callback)
        self.Calls += 1
        if self.Fail > 0 then self.Fail -= 1; error("temporary outage") end
        if self.Before then self.Before(self, key) end
        -- First callback result is intentionally discarded. Neither attempt may
        -- mutate the original stored table or the live service profile.
        callback(clone(self.Records[key]))
        local result = callback(clone(self.Records[key]))
        if result == nil then return nil end
        self.Records[key] = clone(result)
        self.Writes += 1
        if self.After then self.After(self, key) end
        return clone(result)
    end
    return store
end
local time = 1000
local function makeService(store, token, extra)
    local settings = { Store = store, Token = token, Schema = schema, IsStudio = false,
        Now = function() return time end, Wait = function(seconds) time += seconds end,
        Spawn = function(callback) callback() end }
    for key, value in pairs(extra or {}) do settings[key] = value end
    return DataService.new({ Config = { Game = { ProfileStore = "TestProfiles", AutoSaveSeconds = 90,
        SessionLeaseSeconds = 180, StudioPersistence = false }, Economy = { StartingCash = 500 } } }, settings)
end
local player = { UserId = 42 }
local key = "Player_42"

do
    local store = makeStore()
    local a, b = makeService(store, "server-A"), makeService(store, "server-B")
    local profile = a:Load(player)
    check(profile and profile.Version == 2 and profile.Cash == 500, "nil record creates versioned defaults")
    check(a.Status == "Persistent" and a:IsWritable(player), "live mode uses persistent writable lease")
    check(store.Records[key].Session.Token == "server-A:" .. key, "session has unique owner token")
    local count = defaults
    local blocked, reason = b:Load(player)
    check(blocked == nil and reason == "SessionLocked", "second server cannot claim active lease")
    check(b:Get(player) == nil and not b:IsWritable(player), "failed load cannot transact")
    check(defaults == count and store.Records[key].Data.Cash == 500, "session conflict cannot create or overwrite defaults")
    profile.Cash = 825
    check(a:Save(player), "owner can save")
    check(store.Records[key].Data.Cash == 825 and a:Get(player) == profile, "saved snapshot does not replace live profile")
    local returned = store.Records[key].Data
    profile.Cash = 900
    check(returned.Cash == 825, "stored snapshot is detached from memory")
    check(a:Release(player) and a:Get(player) == nil, "release saves and unloads")
    check(store.Records[key].Session == nil and store.Records[key].Data.Cash == 900, "final snapshot releases token")
    local nextProfile = b:Load(player)
    check(nextProfile and nextProfile.Cash == 900, "new server loads committed profile after release")
    check(a:Release(player), "repeated release is harmless")
end

do
    local store = makeStore()
    store.Records[key] = { Version = 1, Cash = 777 }
    local service = makeService(store, "migration")
    local profile = service:Load(player)
    check(profile and profile.Version == 2 and profile.Cash == 777, "legacy profiles migrate preserving cash")
    check(store.Records[key]._RecordVersion == 1 and store.Records[key].Data.Version == 2, "migration commits within claim")
    check(profile.Inventory ~= nil and profile.House.Furniture ~= nil, "migration supplies missing collections")
end

do
    local store = makeStore()
    store.Records[key] = { Version = 99, Cash = 12345 }
    local count = defaults
    local service = makeService(store, "unsupported")
    local profile, reason = service:Load(player)
    check(profile == nil and reason == "UnsupportedSchemaVersion", "future schema rejects load")
    check(store.Writes == 0 and store.Records[key].Version == 99, "future schema is never overwritten")
    check(defaults == count, "unsupported version never invokes defaults")
end

do
    local store = makeStore()
    store.Records[key] = { _RecordVersion = 999, Data = { Version = 2, Cash = 888 } }
    local profile, reason = makeService(store, "future-record"):Load(player)
    check(profile == nil and reason == "UnsupportedRecordVersion" and store.Writes == 0, "unknown envelope rejected read-only")
    store.Records[key] = { _RecordVersion = 1, Data = { Version = 2 }, Revision = 0, Session = { Token = "X", ExpiresAt = math.huge } }
    profile, reason = makeService(store, "corrupt-session"):Load(player)
    check(profile == nil and reason == "InvalidSession" and store.Writes == 0, "nonfinite lease cannot lock users forever")
end

do
    local store = makeStore()
    store.Fail = 2
    local service = makeService(store, "retry")
    check(service:Load(player) ~= nil and store.Calls == 3, "transient load outage retries")
    store.Fail = 20
    local fresh = makeService(store, "missing")
    local count = defaults
    local profile, reason = fresh:Load({ UserId = 99 })
    check(profile == nil and reason == "DataStoreUnavailable", "bounded load outage returns failure")
    check(defaults == count and fresh:Get({ UserId = 99 }) == nil, "outage cannot create playable defaults")
    store.Fail = 20
    local writable = service:Get(player)
    writable.Cash = 1500
    local ok, errorCode = service:Save(player)
    check(not ok and errorCode == "DataStoreUnavailable", "save outage reports failure")
    check(writable.Cash == 1500 and store.Records[key].Data.Cash == 500, "failed save preserves local progress and old stored snapshot")
    time = store.Records[key].Session.ExpiresAt - 14
    check(not service:IsWritable(player), "transactions freeze before unavailable lease expires")
    store.Fail = 0
    check(service:Save(player) and service:IsWritable(player), "successful renewal unfreezes before expiry")
    check(store.Records[key].Data.Cash == 1500, "renewal persists pending progress")
end

do
    local store = makeStore()
    local old = makeService(store, "old")
    check(old:Load(player) ~= nil, "first lease loaded")
    time = store.Records[key].Session.ExpiresAt + 1
    local newer = makeService(store, "new")
    check(newer:Load(player) ~= nil, "expired lease can be recovered by new server")
    newer:Get(player).Cash = 2222
    check(newer:Save(player), "new owner saves")
    old:Get(player).Cash = 1
    local ok, reason = old:Save(player)
    check(not ok and reason == "SessionLost" and not old:IsWritable(player), "old session cannot overwrite takeover")
    ok, reason = old:Release(player)
    check(not ok and reason == "SessionLost", "old session cannot release newer lease")
    check(store.Records[key].Data.Cash == 2222 and store.Records[key].Session.Token == "new:" .. key, "takeover data and token remain intact")
end

do
    local store = makeStore()
    local service = makeService(store, "ambiguous")
    check(service:Load(player) ~= nil, "ambiguous test profile loaded")
    local failed = false
    store.After = function()
        if not failed then failed = true; error("response lost after successful commit") end
    end
    service:Get(player).Cash = 901
    check(service:Save(player) and store.Records[key].Revision == 1, "ambiguous save retries idempotently without double revision")
    failed = false
    check(service:Release(player), "ambiguous release response recovers safely")
    check(store.Records[key].Session == nil and store.Records[key].Revision == 2, "ambiguous release does not perform another write")
end

do
    local store = makeStore()
    local service = makeService(store, "callback-isolation")
    local profile = service:Load(player)
    profile.Inventory.a = { UniqueId = "a", ItemId = "Chair" }
    store.After = function(s)
        profile.Inventory.a.ItemId = "Sofa"
        check(s.Records[key].Data.Inventory.a.ItemId == "Chair", "in-flight save snapshot stays immutable")
    end
    check(service:Save(player), "nested snapshot saves")
    check(profile.Inventory.a.ItemId == "Sofa", "mutations during save remain live")
    store.After = nil
    check(service:Save(player) and store.Records[key].Data.Inventory.a.ItemId == "Sofa", "next save includes in-flight mutation")
end

do
    local store = makeStore()
    local service = makeService(store, "concurrent", {
        Wait = function() coroutine.yield("waiting for save") end,
    })
    local profile = service:Load(player)
    profile.Cash = 100
    local paused = false
    store.Before = function()
        if not paused then paused = true; coroutine.yield("paused update") end
    end
    local saved, released
    local first = coroutine.create(function() saved = service:Save(player) end)
    local second = coroutine.create(function() released = service:Release(player) end)
    check(coroutine.resume(first), "first save pauses inside I/O")
    profile.Cash = 200
    check(coroutine.resume(second), "release queues behind save")
    check(not service:IsWritable(player), "queued release freezes transactions immediately")
    check(coroutine.resume(first) and saved, "first save finishes")
    check(coroutine.resume(second) and released, "release waits then takes fresh snapshot")
    check(store.Records[key].Data.Cash == 200 and store.Records[key].Session == nil, "release persists changes made during earlier save")
end

do
    local store = makeStore()
    local service = makeService(store, "memory", { IsStudio = true })
    check(service.Status == "StudioMemory", "Studio mode is explicit")
    local profile = service:Load(player)
    profile.Cash = 321
    check(service:Save(player) and store.Calls == 0, "Studio never touches production store")
    check(service:Release(player) and service:Load(player).Cash == 500, "memory mode is intentionally nonpersistent")
    check(service:Close() and service:Get(player) == nil, "shutdown releases all memory profiles")
    local another, reason = service:Load({ UserId = 2 })
    check(another == nil and reason == "ServerClosing", "shutdown prevents new loads")
end

do
    local store = makeStore()
    local service = makeService(store, "closing-load", { Wait = function() coroutine.yield("close waiting") end })
    local paused = false
    store.Before = function()
        if not paused then paused = true; coroutine.yield("load waiting") end
    end
    local loaded, loadError, closed
    local loading = coroutine.create(function() loaded, loadError = service:Load(player) end)
    local closing = coroutine.create(function() closed = service:Close() end)
    check(coroutine.resume(loading), "load can wait in datastore")
    check(coroutine.resume(closing) and coroutine.status(closing) == "suspended", "shutdown waits for in-flight profile claims")
    check(coroutine.resume(loading) and loaded == nil and loadError == "ServerClosing", "late load cannot become playable during shutdown")
    check(coroutine.resume(closing) and closed and store.Records[key].Session == nil, "shutdown releases late acquired lease before completion")
end

do
    local store = makeStore()
    local service = makeService(store, "invalid-snapshot")
    local profile = service:Load(player)
    profile.Cash = 0 / 0
    local ok, reason = service:Save(player)
    check(not ok and reason == "InvalidProfile", "invalid snapshot is refused without contacting store")
    check(store.Records[key].Data.Cash == 500, "NaN cannot overwrite good profile")
    profile.Cash = 500
    profile.Inventory.self = profile.Inventory
    ok, reason = service:Save(player)
    check(not ok and reason == "InvalidProfile", "cyclic profile cannot reach DataStore")
end

do
    local store = makeStore()
    local validating = clone(schema)
    validating.Validate = function(profile)
        return type(profile.Cash) == "number" and profile.Cash >= 0, "Invalid cash"
    end
    local service = makeService(store, "schema-validation", { Schema = validating })
    local profile = service:Load(player)
    profile.Cash = -100
    local ok, reason = service:Save(player)
    check(not ok and reason == "InvalidProfile" and not service:IsWritable(player), "schema violations freeze profile instead of persisting")
    check(store.Records[key].Data.Cash == 500, "schema validation preserves previous save")
    profile.Cash = 600
    check(service:Save(player) and service:IsWritable(player), "supported correction and save can recover profile")
end

do
    local store = makeStore()
    local service = makeService(store, "slow-response")
    check(service:Load(player) ~= nil, "slow response profile loaded")
    store.After = function() time += 181 end
    local ok, reason = service:Save(player)
    check(not ok and reason == "SessionLost" and not service:IsWritable(player), "late response cannot admit already expired lease")
end

do
    local store = makeStore()
    local connected, disconnected, leave, shutdown = 0, false, nil, nil
    local coroutines = {}
    local players = { PlayerRemoving = {} }
    function players.PlayerRemoving:Connect(callback)
        connected += 1
        leave = callback
        return { Disconnect = function() disconnected = true end }
    end
    local service = makeService(store, "autosave", {
        Players = players, BindToClose = function(callback) shutdown = callback end,
        Wait = function(seconds) coroutine.yield(seconds) end,
        Spawn = function(callback)
            local co = coroutine.create(callback)
            table.insert(coroutines, co)
            assert(coroutine.resume(co))
        end,
    })
    local profile = service:Load(player)
    local releaseHookCount, closeHookCount = 0, 0
    service._Ctx.BeforeDataRelease = function(leaving)
        releaseHookCount += 1
        check(service:IsWritable(leaving), "leave hook settles temporary loot before transaction freeze")
        service:Get(leaving).Cash += 10
    end
    service:Start()
    service:Start()
    check(connected == 1 and shutdown ~= nil, "Start is idempotent and registers lifecycle hooks")
    profile.Cash = 876
    time += 90
    check(coroutine.resume(coroutines[1]), "autosave scheduler resumes")
    check(store.Records[key].Data.Cash == 876 and store.Records[key].Session.ExpiresAt == time + 180, "autosave writes and renews lease")
    profile.Cash = 900
    leave(player)
    check(service:Get(player) == nil and store.Records[key].Data.Cash == 910 and releaseHookCount == 1, "PlayerRemoving saves settled state and releases")
    local secondPlayer = { UserId = 77 }
    local secondProfile = service:Load(secondPlayer)
    secondProfile.Cash = 707
    service._Ctx.BeforeDataClose = function()
        closeHookCount += 1
        check(service:IsWritable(secondPlayer), "shutdown hook settles temporary loot while writable")
        service:Get(secondPlayer).Cash += 20
    end
    shutdown()
    check(service:Get(secondPlayer) == nil and store.Records.Player_77.Data.Cash == 727
        and store.Records.Player_77.Session == nil and disconnected, "BindToClose saves all remaining profiles and disconnects")
    check(service:Close() and closeHookCount == 1, "repeated close preserves result without repeating settlement hook")
    check(coroutine.resume(coroutines[1]) and coroutine.status(coroutines[1]) == "dead", "autosave loop exits after shutdown")
end

print("DataService persistence checks passed: " .. checks)
