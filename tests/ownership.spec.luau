-- Real ownership ledger; injected atomic DataStore replays transform callbacks.
-- These are deterministic persistence protocol checks, not Roblox engine tests.
local Ownership = require("../src/server/OwnershipService")
local checks = 0
local function check(value, message)
    assert(value, message)
    checks += 1
end
local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end
local function size(map)
    local count = 0
    for _ in pairs(map) do count += 1 end
    return count
end
local now = 1000
local function store()
    local result = { Records = {}, Calls = 0, Writes = 0, ReadFails = 0, WriteFails = 0 }
    function result:GetAsync(key)
        self.Calls += 1
        if self.ReadFails > 0 or self.FailReadKey == key then
            self.ReadFails = math.max(0, self.ReadFails - 1)
            error("read unavailable")
        end
        if self.BeforeRead then self.BeforeRead(self, key) end
        return clone(self.Records[key])
    end
    function result:UpdateAsync(key, callback)
        self.Calls += 1
        if self.WriteFails > 0 or self.FailWriteKey == key then
            self.WriteFails = math.max(0, self.WriteFails - 1)
            error("write unavailable")
        end
        if self.BeforeWrite then self.BeforeWrite(self, key) end
        local original = clone(self.Records[key])
        callback(clone(self.Records[key])) -- discarded optimistic transform
        if self.BetweenCallbacks then self.BetweenCallbacks(self, key) end
        local changed = callback(clone(self.Records[key]))
        -- Transform callbacks must not mutate the existing store snapshot.
        if self.AssertUnmutated then self.AssertUnmutated(self, key, original) end
        if changed == nil then return nil end
        self.Records[key] = clone(changed)
        self.Writes += 1
        if self.AfterCommit then self.AfterCommit(self, key) end
        if self.AmbiguousKey == key and self.AmbiguousCount > 0 then
            self.AmbiguousCount -= 1
            error("committed; response lost")
        end
        return clone(changed)
    end
    return result
end
local function service(injected, mode, extra)
    local ctx = { Config = { Game = { MaxSlots = 20, OwnershipStore = "TestOwnership" },
        HouseById = { Cottage = {} }, VariantById = { Normal = {}, Gold = {} },
        SizeById = { Normal = {}, Big = {}, Giant = {} } }, Data = { Status = mode or "Persistent" } }
    local settings = { Store = injected, Wait = function(seconds) now += seconds end,
        Now = function() return now end }
    for key, value in pairs(extra or {}) do settings[key] = value end
    return Ownership.new(ctx, settings)
end
local function record(id, owner, slot, op)
    return { Id = id or "home-1", DefinitionId = "Cottage", Variant = "Normal", Size = "Normal",
        OwnerId = owner or 11, Slot = slot or 1, Revision = 1, CreatedAt = 900,
        OwnedSince = 900, BuildReadyAt = 906, OperationId = op or "create-1" }
end
local function failure(result, reason, expected, message)
    check(result == nil and reason == expected, message .. ": " .. tostring(reason))
end

do
    local s = store()
    local a = service(s)
    check(a:Get("home-1") == nil, "a successful missing canonical read means absent")
    check(#a:List(11) == 0, "new owner index lists no records")
    local input = record()
    local created = a:Create(input)
    check(created and created.Revision == 1 and created.OwnerId == 11, "create canonical record")
    check(s.Records.Owner_11.References["home-1"].Revision == 1, "index persisted before canonical create")
    check(s.Records["House_home-1"].BuildReadyAt == 906, "construction timestamp persisted")
    input.OwnerId = 77
    created.Slot = 19
    check(a:Get("home-1").OwnerId == 11 and a:Get("home-1").Slot == 1, "inputs and returned records detached")
    check(#a:List(11) == 1 and a:List(11)[1].Id == "home-1", "owner loads canonical house")
    local reloaded = service(s)
    check(#reloaded:List(11) == 1 and reloaded:Get("home-1").OperationId == "create-1", "fresh server recovers ownership")
    local writes = s.Writes
    check(a:Create(record(), function() error("must not run") end) ~= nil,
        "idempotent create recognized before live-state callback")
    check(s.Writes == writes, "recognized create does not rewrite indexes")
    local other = record(nil, 12)
    failure(a:Create(other), "HouseAlreadyExists", "HouseAlreadyExists", "UID cannot be claimed twice")
end

do
    local s = store()
    local a, b = service(s), service(s)
    a:Create(record())
    now = 1100
    local moved = a:Transfer("home-1", 11, 1, 22, 3, "transfer-A")
    check(moved and moved.OwnerId == 22 and moved.Slot == 3 and moved.Revision == 2, "canonical ownership transferred")
    check(moved.OwnedSince == now and moved.CreatedAt == 900 and moved.BuildReadyAt == 906,
        "transfer resets accrual time and preserves creation and construction")
    check(#a:List(11) == 0 and #b:List(22) == 1, "stale victim index never duplicates ownership")
    check(s.Records.Owner_11.References["home-1"] ~= nil, "owner indexes are references rather than authorities")
    check(s.Records.Owner_22.References["home-1"].Revision == 2, "destination canonical revision indexed")
    local duplicate = a:Transfer("home-1", 11, 1, 22, 3, "transfer-A", function() return false end)
    check(duplicate and duplicate.OwnerId == 22 and duplicate.Revision == 2, "committed transfer retry bypasses cancellation")
    local lost, reason = b:Transfer("home-1", 11, 1, 33, 2, "transfer-B")
    failure(lost, reason, "OwnershipChanged", "second thief cannot commit stale ownership")
    check(s.Records.Owner_33 == nil, "stale upfront revision does not pollute incoming owner index")
    local back = b:Transfer("home-1", 22, 2, 11, 4, "return-1")
    check(back and back.Revision == 3 and back.OwnerId == 11, "same UID can transfer back at a new revision")
    check(#a:List(11) == 1 and #b:List(22) == 0, "old and new owners reconcile after return")
    check(s.Records.Owner_11.References["home-1"].Revision == 3, "return upgrades owner reference revision")
end

do
    local s = store()
    local a, b = service(s), service(s)
    a:Create(record())
    s.BeforeWrite = function(_, key)
        if key == "House_home-1" then
            s.BeforeWrite = nil
            check(b:Transfer("home-1", 11, 1, 33, 5, "winning-race") ~= nil,
                "competing server wins during first thief's yield")
        end
    end
    local lost, reason = a:Transfer("home-1", 11, 1, 22, 3, "losing-race")
    failure(lost, reason, "OwnershipChanged", "CAS rechecks canonical owner after incoming index write")
    check(a:Get("home-1").OwnerId == 33 and #a:List(22) == 0, "racing index cannot confer ownership")
    check(#a:List(11) == 0 and #a:List(33) == 1, "exactly one owner after race")
end

do
    local s = store()
    local a = service(s)
    a:Create(record())
    s.BetweenCallbacks = function(_, key)
        if key == "House_home-1" then
            s.BetweenCallbacks = nil
            local competing = clone(s.Records[key])
            competing.OwnerId, competing.Slot, competing.Revision = 44, 6, 2
            competing.OperationId = "winning-replay"
            s.Records[key] = competing
            s.Records.Owner_44 = { Version = 1, References = { ["home-1"] = { Revision = 2, OperationId = "winning-replay" } } }
        end
    end
    local lost, reason = a:Transfer("home-1", 11, 1, 22, 3, "losing-replay")
    failure(lost, reason, "OwnershipChanged", "replayed UpdateAsync callback sees winning concurrent revision")
    check(a:Get("home-1").OwnerId == 44, "discarded callback cannot mutate original canonical record")
end

do
    local s = store()
    local a = service(s)
    s.AmbiguousKey, s.AmbiguousCount = "Owner_11", 1
    check(a:Create(record()) ~= nil, "ambiguous recipient index commit retries idempotently")
    check(size(s.Records.Owner_11.References) == 1, "ambiguous index retry does not duplicate references")
    s.AmbiguousKey, s.AmbiguousCount = "House_home-2", 1
    check(a:Create(record("home-2", 11, 2, "create-2")) ~= nil, "ambiguous create retries committed operation")
    check(a:Get("home-2").Revision == 1, "create callback replay never increments revision")
    s.AmbiguousKey, s.AmbiguousCount = "House_home-1", 1
    s.AfterCommit = function(_, key)
        if key == "House_home-1" then s.AfterCommit = nil; s.Cancelled = true end
    end
    local moved = a:Transfer("home-1", 11, 1, 22, 1, "ambiguous-transfer", function() return not s.Cancelled end)
    check(moved and moved.Revision == 2 and moved.OwnerId == 22,
        "committed transfer survives live cancellation before response retry")
    s.AmbiguousKey, s.AmbiguousCount = "House_home-1", 1
    check(a:Remove("home-1", 22, 2, "ambiguous-sale") ~= nil, "ambiguous removal retries tombstone")
    check(a:Get("home-1").Revision == 3 and a:Get("home-1").OwnerId == 0,
        "ambiguous removal increments only once")
end

do
    local s = store()
    local a = service(s)
    s.AmbiguousKey, s.AmbiguousCount = "House_home-1", 4
    local lost, reason = a:Create(record())
    failure(lost, reason, "OwnershipStoreUnavailable", "all create response retries may fail despite committed data")
    check(a:Get("home-1").OwnerId == 11, "ambiguous outage keeps committed canonical record")
    check(a:Create(record(), function() return false end) ~= nil,
        "recovery recognizes committed create despite expired live intent")
    s.AmbiguousKey, s.AmbiguousCount = "House_home-1", 4
    lost, reason = a:Transfer("home-1", 11, 1, 22, 2, "lost-transfer")
    failure(lost, reason, "OwnershipStoreUnavailable", "all transfer response retries may be ambiguous")
    check(a:Transfer("home-1", 11, 1, 22, 2, "lost-transfer", function() return false end) ~= nil,
        "later recovery recognizes committed transfer")
    s.AmbiguousKey, s.AmbiguousCount = "House_home-1", 4
    lost, reason = a:Remove("home-1", 22, 2, "lost-sale")
    failure(lost, reason, "OwnershipStoreUnavailable", "all remove response retries may be ambiguous")
    check(a:Remove("home-1", 22, 2, "lost-sale", function() return false end) ~= nil,
        "later sale recovery recognizes durable tombstone")
end

do
    local s = store()
    local a = service(s)
    s.FailWriteKey = "Owner_11"
    local lost, reason = a:Create(record())
    failure(lost, reason, "OwnershipStoreUnavailable", "failed recipient index stops canonical create")
    check(s.Records["House_home-1"] == nil, "unindexed house cannot be created")
    s.FailWriteKey = nil
    a:Create(record())
    s.FailWriteKey = "Owner_22"
    lost, reason = a:Transfer("home-1", 11, 1, 22, 2, "index-outage")
    failure(lost, reason, "OwnershipStoreUnavailable", "failed destination index stops ownership transfer")
    check(a:Get("home-1").OwnerId == 11 and a:Get("home-1").Revision == 1,
        "index outage leaves victim authoritative ownership intact")
    s.FailWriteKey = nil
    s.FailReadKey = "House_home-1"
    lost, reason = a:Get("home-1")
    failure(lost, reason, "OwnershipStoreUnavailable", "canonical read outage is never a missing house")
    lost, reason = a:List(11)
    failure(lost, reason, "OwnershipStoreUnavailable", "partial house list fails closed")
    lost, reason = a:Create(record())
    failure(lost, reason, "OwnershipStoreUnavailable", "create cannot mistake read outage for new UID")
    s.FailReadKey = "Owner_11"
    lost, reason = a:List(11)
    failure(lost, reason, "OwnershipStoreUnavailable", "index read outage is never an empty inventory")
end

do
    local s = store()
    local a = service(s)
    local calls = 0
    local lost, reason = a:Create(record(), function() calls += 1; return false end)
    failure(lost, reason, "OwnershipCheckFailed", "rejected create stays absent")
    check(calls == 1 and s.Records.Owner_11 == nil, "preflight cancellation does not write index")
    a:Create(record())
    s.AfterCommit = function(_, key)
        if key == "Owner_22" then s.Cancelled = true end
    end
    lost, reason = a:Transfer("home-1", 11, 1, 22, 2, "cancel-yield", function() return not s.Cancelled end)
    failure(lost, reason, "OwnershipCheckFailed", "live state revalidated after yielding index operation")
    check(a:Get("home-1").OwnerId == 11, "cancelled transfer retains source ownership")
    check(#a:List(22) == 0, "cancelled incoming reference does not award a house")
    lost, reason = a:Remove("home-1", 11, 1, "cancel-sale", function() error("invalid state") end)
    failure(lost, reason, "OwnershipCheckFailed", "throwing live check fails closed")
    check(a:Get("home-1").OwnerId == 11, "failed remove leaves house intact")
end

do
    local s = store()
    local a = service(s)
    a:Create(record())
    local removed = a:Remove("home-1", 11, 1, "sale-1")
    check(removed and removed.OwnerId == 0 and removed.Slot == 0 and removed.Revision == 2,
        "remove writes permanent revisioned tombstone")
    check(#a:List(11) == 0, "tombstoned houses omitted from owner inventory")
    check(a:Remove("home-1", 11, 1, "sale-1", function() return false end) ~= nil,
        "sold house recovery recognizes operation before liveness checks")
    local lost, reason = a:Create(record())
    failure(lost, reason, "HouseAlreadyExists", "tombstone prevents accidental UID resurrection")
    lost, reason = a:Transfer("home-1", 11, 1, 22, 2, "revive")
    failure(lost, reason, "OwnershipChanged", "sold house cannot be transferred from stale state")
    lost, reason = a:Remove("missing", 11, 1, "missing-sale")
    failure(lost, reason, "HouseNotFound", "missing house is not successful sale")
end

do
    local s = store()
    local live, studioA, studioB = service(s), service(s, "StudioMemory"), service(s, "StudioMemory")
    local calls = s.Calls
    check(studioA:Create(record("temporary", -1, 1, "studio-1")) ~= nil,
        "Studio multiplayer negative IDs supported in temporary mode")
    check(#studioA:List(-1) == 1 and #studioB:List(-1) == 0,
        "separate temporary ledgers are isolated")
    check(studioA:Transfer("temporary", -1, 1, -2, 1, "studio-transfer") ~= nil,
        "temporary Studio users can transfer")
    check(#studioA:List(-1) == 0 and #studioA:List(-2) == 1,
        "temporary CAS still has one canonical owner")
    check(s.Calls == calls and live:Get("temporary") == nil, "Studio mode never touches injected persistent store")
    local lost, reason = live:Create(record("negative", -1))
    failure(lost, reason, "InvalidOwnershipRecord", "production refuses negative owner IDs")
end

do
    local s = store()
    local a = service(s)
    for _, field in ipairs({ "Id", "DefinitionId", "Variant", "Size", "OwnerId", "Slot", "Revision",
        "CreatedAt", "OwnedSince", "BuildReadyAt", "OperationId" }) do
        local bad = record()
        bad[field] = nil
        local lost, reason = a:Create(bad)
        failure(lost, reason, "InvalidOwnershipRecord", "missing " .. field .. " rejected")
    end
    local cases = {
        { "Id", string.rep("x", 45) }, { "Id", "bad/key" }, { "Id", "" },
        { "DefinitionId", "Unknown" }, { "Variant", "Unknown" }, { "Size", "Unknown" },
        { "Slot", 21 }, { "Slot", 0 }, { "Slot", 1.5 }, { "OwnerId", 0 },
        { "OwnerId", 1.5 }, { "Revision", 2 }, { "CreatedAt", math.huge },
        { "CreatedAt", 0 / 0 }, { "OwnedSince", 800 }, { "BuildReadyAt", 800 },
        { "OperationId", "" }, { "OperationId", string.rep("x", 161) },
        { "OperationId", "unexpected space" }, { "Injected", {} },
    }
    for _, case in ipairs(cases) do
        local bad = record()
        bad[case[1]] = case[2]
        local lost, reason = a:Create(bad)
        failure(lost, reason, "InvalidOwnershipRecord", "invalid " .. case[1] .. " refused")
    end
    local invalidRecords = { "bad", { Id = "home-1" }, record("another-id") }
    for _, bad in ipairs(invalidRecords) do
        s.Records["House_home-1"] = bad
        local lost, reason = a:Get("home-1")
        failure(lost, reason, "InvalidOwnershipRecord", "corrupt canonical data fails closed")
    end
    s.Records["House_home-1"] = nil
    local badIndexes = {
        "bad", { Version = 2, References = {} }, { Version = 1, References = { bad = "ref" } },
        { Version = 1, References = { bad = { Revision = 1, OperationId = "valid", Extra = 1 } } },
        { Version = 1, References = {}, Extra = {} },
    }
    for _, bad in ipairs(badIndexes) do
        s.Records.Owner_11 = bad
        local lost, reason = a:List(11)
        failure(lost, reason, "InvalidOwnershipIndex", "malformed reference index fails closed")
    end
    local refs = {}
    for i = 1, 257 do refs["too-many-" .. i] = { Revision = 1, OperationId = "valid" } end
    s.Records.Owner_11 = { Version = 1, References = refs }
    local lost, reason = a:List(11)
    failure(lost, reason, "InvalidOwnershipIndex", "oversized stored index rejected")
    check(s.Records["House_home-1"] == nil, "malformed inputs never create canonical house")
end

do
    local s = store()
    local a = service(s)
    local refs = {}
    for i = 1, 256 do
        local id = "stale-" .. i
        refs[id] = { Revision = 1, OperationId = "old-create-" .. i }
        local tombstone = record(id, 22, 1, "away-" .. i)
        tombstone.Revision = 2
        s.Records["House_" .. id] = tombstone
    end
    s.Records.Owner_11 = { Version = 1, References = refs }
    check(a:Create(record()) ~= nil, "full owner index prunes conclusively stale references")
    check(size(s.Records.Owner_11.References) == 1 and #a:List(11) == 1,
        "pruning preserves new owner inventory within bound")
end

do
    local s = store()
    local a = service(s)
    local refs = {}
    for i = 1, 256 do
        local id = "pending-" .. i
        refs[id] = { Revision = 2, OperationId = "incoming-" .. i }
        s.Records["House_" .. id] = record(id, 22, 1, "old-create-" .. i)
    end
    s.Records.Owner_11 = { Version = 1, References = refs }
    local lost, reason = a:Create(record())
    failure(lost, reason, "OwnershipIndexFull", "pending incoming references cannot be pruned before CAS")
    check(size(s.Records.Owner_11.References) == 256 and s.Records["House_home-1"] == nil,
        "reference bound fails closed rather than orphaning incoming houses")
    check(#a:List(11) == 0, "pending destination refs never count as actual houses")
end

do
    local s = store()
    local a, b = service(s), service(s)
    local refs = {}
    for i = 1, 256 do
        local id = "old-" .. i
        refs[id] = { Revision = 1, OperationId = "original-" .. i }
        local moved = record(id, 22, 1, "moved-" .. i)
        moved.Revision = 2
        s.Records["House_" .. id] = moved
    end
    s.Records.Owner_11 = { Version = 1, References = refs }
    local indexCalls = 0
    s.BeforeWrite = function(_, key)
        if key == "Owner_11" then
            indexCalls += 1
            if indexCalls == 2 then -- first full insertion rejected; this is prune CAS
                s.BeforeWrite = nil
                check(b:Transfer("old-1", 22, 2, 11, 7, "incoming-during-prune") ~= nil,
                    "incoming transfer can race stale-index cleanup")
            end
        end
    end
    check(a:Create(record()) ~= nil, "cleanup CAS preserves concurrently upgraded reference")
    check(s.Records.Owner_11.References["old-1"].Revision == 3,
        "prune never removes new revision replacing stale reference")
    check(#a:List(11) == 2 and a:Get("old-1").OwnerId == 11,
        "incoming house remains discoverable after competing prune")
end

do
    local s = store()
    local a = service(s)
    s.Records.Owner_11 = { Version = 1, References = { vanished = { Revision = 1, OperationId = "pending-create" } } }
    check(#a:List(11) == 0, "missing canonical UID does not become an inventory house")
    a:Create(record("third", 11, 3, "create-third"))
    a:Create(record("first", 11, 1, "create-first"))
    a:Create(record("second", 11, 2, "create-second"))
    local sorted = a:List(11)
    check(#sorted == 3 and sorted[1].Id == "first" and sorted[3].Id == "third",
        "canonical lists are sorted deterministically by slot")
    local lost, reason = a:Transfer("first", 11, 1, 11, 2, "same-owner")
    failure(lost, reason, "InvalidOwnershipTransfer", "same-owner transfer is not a theft")
    lost, reason = a:Transfer("first", 11, 1, 22, 21, "bad-slot")
    failure(lost, reason, "InvalidOwnershipTransfer", "invalid target slot rejected before store")
    lost, reason = a:Transfer("first", 11, 0 / 0, 22, 1, "nan-revision")
    failure(lost, reason, "InvalidOwnershipTransfer", "NaN CAS revision rejected")
    lost, reason = a:Remove("first", 11, 0, "zero-revision")
    failure(lost, reason, "InvalidOwnershipRemoval", "invalid removal revision rejected")
    lost, reason = a:List(0)
    failure(lost, reason, "InvalidOwnerId", "tombstone owner cannot load inventory")
    lost, reason = a:Get("invalid/key")
    failure(lost, reason, "InvalidHouseId", "unsafe datastore key rejected")
end

print("OwnershipService: " .. checks .. " canonical ownership, indexed discovery, CAS, replay and outage checks passed.")
