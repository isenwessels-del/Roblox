-- The profile contains income, never ownership. Each house has one canonical
-- CAS record; owner indexes contain only references and are verified on load.
-- Incoming references are durable before CAS. Their revision protects them
-- from pruning while an ownership operation is still in flight.
local OwnershipService = {}
OwnershipService.__index = OwnershipService

local MAX_REFERENCES = 256
local MAX_REVISION = 1000000000000
local MAX_ID = 44 -- DataStore keys include the six-character "House_" prefix.
local FIELDS = { Id = true, DefinitionId = true, Variant = true, Size = true,
    OwnerId = true, Slot = true, Revision = true, CreatedAt = true,
    OwnedSince = true, BuildReadyAt = true, OperationId = true }

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function integer(value, minimum, maximum)
    return type(value) == "number" and value == value and value >= minimum
        and value <= maximum and value == math.floor(value)
end

local function identifier(value, maximum)
    return type(value) == "string" and #value > 0 and #value <= maximum
        and value:match("^[%w_%-]+$") ~= nil
end

local function operationId(value)
    return type(value) == "string" and #value > 0 and #value <= 160
        and value:match("^[%w_%-%:%.]+$") ~= nil
end

local function timestamp(value)
    return type(value) == "number" and value == value and value >= 0 and value <= MAX_REVISION
end

local function memoryStore()
    local records = {}
    return {
        GetAsync = function(_, key) return copy(records[key]) end,
        UpdateAsync = function(_, key, transform)
            local result = transform(copy(records[key]))
            if result == nil then return nil end
            records[key] = copy(result)
            return copy(result)
        end,
    }
end

function OwnershipService.new(ctx, options)
    options = options or {}
    local self = setmetatable({}, OwnershipService)
    self._Ctx, self._Config = ctx, ctx.Config
    self._Now = options.Now or ctx.Clock or os.time
    self._Wait = options.Wait or task.wait
    self._Retries = options.RetryCount or 4
    self.Status = assert(ctx.Data and ctx.Data.Status, "Ownership requires the profile data mode")
    assert(self.Status == "StudioMemory" or self.Status == "Persistent", "Unknown ownership data mode")
    if self.Status == "StudioMemory" then
        -- Never use an injected/production store in temporary Studio mode.
        self._Store = memoryStore()
    else
        self._Store = options.Store or game:GetService("DataStoreService")
            :GetDataStore(assert(ctx.Config.Game.OwnershipStore, "OwnershipStore must be configured"))
        if not options.Store then
            self._ReadOptions = Instance.new("DataStoreGetOptions")
            self._ReadOptions.UseCache = false -- a cached former owner must not load a duplicate
        end
    end
    return self
end

function OwnershipService:_owner(value, allowRemoved)
    if allowRemoved and value == 0 then return true end
    return integer(value, if self.Status == "StudioMemory" then -9007199254740991 else 1,
        9007199254740991) and value ~= 0
end

function OwnershipService:_valid(record, id)
    if type(record) ~= "table" then return false end
    for field in pairs(record) do if not FIELDS[field] then return false end end
    if not identifier(record.Id, MAX_ID) or (id and record.Id ~= id)
        or not identifier(record.DefinitionId, 64) or not identifier(record.Variant, 64)
        or not identifier(record.Size, 64) or not self:_owner(record.OwnerId, true)
        or not integer(record.Revision, 1, MAX_REVISION)
        or not timestamp(record.CreatedAt) or not timestamp(record.OwnedSince)
        or not timestamp(record.BuildReadyAt) or record.OwnedSince < record.CreatedAt
        or record.BuildReadyAt < record.CreatedAt or not operationId(record.OperationId) then return false end
    if record.OwnerId == 0 then
        if record.Slot ~= 0 then return false end
    elseif not integer(record.Slot, 1, self._Config.Game.MaxSlots or 20) then return false end
    return self._Config.HouseById[record.DefinitionId] ~= nil
        and self._Config.VariantById[record.Variant] ~= nil
        and self._Config.SizeById[record.Size] ~= nil
end

function OwnershipService:_index(raw)
    if raw == nil then return { Version = 1, References = {} } end
    if type(raw) ~= "table" or raw.Version ~= 1 or type(raw.References) ~= "table" then return nil end
    for key in pairs(raw) do if key ~= "Version" and key ~= "References" then return nil end end
    local count = 0
    for id, ref in pairs(raw.References) do
        count += 1
        if count > MAX_REFERENCES or not identifier(id, MAX_ID) or type(ref) ~= "table"
            or not integer(ref.Revision, 1, MAX_REVISION) or not operationId(ref.OperationId) then return nil end
        for key in pairs(ref) do if key ~= "Revision" and key ~= "OperationId" then return nil end end
    end
    return copy(raw)
end

function OwnershipService:_retry(operation)
    for attempt = 1, self._Retries do
        local ok, result, reason = pcall(operation)
        if ok then return true, result, reason end
        if attempt < self._Retries then self._Wait(math.min(2 ^ (attempt - 1), 4)) end
    end
    return false, nil, "OwnershipStoreUnavailable"
end

function OwnershipService:_read(key)
    local ok, value, reason = self:_retry(function()
        return self._Store:GetAsync(key, self._ReadOptions)
    end)
    if not ok then return nil, reason end
    return value
end

function OwnershipService:Get(id)
    if not identifier(id, MAX_ID) then return nil, "InvalidHouseId" end
    local raw, reason = self:_read("House_" .. id)
    if reason then return nil, reason end
    if raw == nil then return nil end -- nil means absent only after a successful read
    if not self:_valid(raw, id) then return nil, "InvalidOwnershipRecord" end
    return copy(raw)
end

function OwnershipService:_readIndex(userId)
    local raw, reason = self:_read("Owner_" .. tostring(userId))
    if reason then return nil, reason end
    local index = self:_index(raw)
    if not index then return nil, "InvalidOwnershipIndex" end
    return index
end

function OwnershipService:List(userId)
    if not self:_owner(userId, false) then return nil, "InvalidOwnerId" end
    local index, reason = self:_readIndex(userId)
    if not index then return nil, reason end
    local records = {}
    for id in pairs(index.References) do
        local record, failure = self:Get(id)
        if failure then return nil, failure end -- never return a partial ownership list
        if record and record.OwnerId == userId then table.insert(records, record) end
    end
    table.sort(records, function(a, b)
        return if a.Slot == b.Slot then a.Id < b.Id else a.Slot < b.Slot
    end)
    return records
end

function OwnershipService:_pruneIndex(userId)
    local index, failure = self:_readIndex(userId)
    if not index then return false, failure end
    local stale = {}
    for id, ref in pairs(index.References) do
        local canonical, reason = self:Get(id)
        if reason then return false, reason end
        -- Missing keys and earlier revisions may be incoming creates/transfers.
        -- Keep them. A later canonical revision conclusively invalidates this ref.
        if canonical and canonical.OwnerId ~= userId and canonical.Revision >= ref.Revision then
            stale[id] = ref
        end
    end
    if next(stale) == nil then return true end
    local ok, result, reason = self:_retry(function()
        local rejection
        local written = self._Store:UpdateAsync("Owner_" .. tostring(userId), function(raw)
            rejection = nil
            local latest = self:_index(raw)
            if not latest then rejection = "InvalidOwnershipIndex"; return nil end
            for id, oldRef in pairs(stale) do
                local ref = latest.References[id]
                -- An incoming operation replaces the ref with a higher revision.
                if ref and ref.Revision == oldRef.Revision and ref.OperationId == oldRef.OperationId then
                    latest.References[id] = nil
                end
            end
            return latest
        end)
        return written, rejection
    end)
    if not ok or not result then return false, reason or "OwnershipIndexWriteFailed" end
    return true
end

function OwnershipService:_reference(userId, id, revision, op)
    local function insert()
        local ok, result, reason = self:_retry(function()
            local rejection
            local written = self._Store:UpdateAsync("Owner_" .. tostring(userId), function(raw)
                rejection = nil
                local index = self:_index(raw)
                if not index then rejection = "InvalidOwnershipIndex"; return nil end
                local ref = index.References[id]
                if ref and ref.Revision >= revision then return index end
                if not ref then
                    local count = 0
                    for _ in pairs(index.References) do count += 1 end
                    if count >= MAX_REFERENCES then rejection = "OwnershipIndexFull"; return nil end
                end
                index.References[id] = { Revision = revision, OperationId = op }
                return index
            end)
            return written, rejection
        end)
        if not ok or not result then return false, reason or "OwnershipIndexWriteFailed" end
        local index = self:_index(result)
        local ref = index and index.References[id]
        if not ref or ref.Revision < revision then return false, "OwnershipIndexWriteFailed" end
        return true
    end
    local ok, reason = insert()
    if ok or reason ~= "OwnershipIndexFull" then return ok, reason end
    local pruned, failure = self:_pruneIndex(userId)
    if not pruned then return false, failure end
    return insert()
end

local function checkAllowed(check)
    if check == nil then return true end
    if type(check) ~= "function" then return false end
    -- This callback runs inside UpdateAsync and must not yield. It only checks
    -- live gameplay/session state; it never reads another DataStore.
    local ok, allowed = pcall(check)
    return ok and allowed == true
end

function OwnershipService:Create(record, check)
    if not self:_valid(record) or record.OwnerId == 0 or record.Revision ~= 1 then
        return nil, "InvalidOwnershipRecord"
    end
    local wanted = copy(record)
    local current, readFailure = self:Get(wanted.Id)
    if readFailure then return nil, readFailure end
    local function same(raw)
        return raw.OperationId == wanted.OperationId and raw.OwnerId == wanted.OwnerId
            and raw.Slot == wanted.Slot and raw.DefinitionId == wanted.DefinitionId
            and raw.Variant == wanted.Variant and raw.Size == wanted.Size and raw.Revision == 1
    end
    if current then
        if same(current) then return current end -- committed retry before live-state checks
        return nil, "HouseAlreadyExists"
    end
    if not checkAllowed(check) then return nil, "OwnershipCheckFailed" end
    local indexed, indexFailure = self:_reference(wanted.OwnerId, wanted.Id, 1, wanted.OperationId)
    if not indexed then return nil, indexFailure end
    local ok, result, reason = self:_retry(function()
        local rejection
        local written = self._Store:UpdateAsync("House_" .. wanted.Id, function(raw)
            rejection = nil
            if raw ~= nil then
                if not self:_valid(raw, wanted.Id) then rejection = "InvalidOwnershipRecord"; return nil end
                if same(raw) then return copy(raw) end
                rejection = "HouseAlreadyExists"; return nil
            end
            if not checkAllowed(check) then rejection = "OwnershipCheckFailed"; return nil end
            return copy(wanted)
        end)
        return written, rejection
    end)
    if not ok or not result then return nil, reason or "OwnershipWriteFailed" end
    if not self:_valid(result, wanted.Id) or not same(result) then return nil, "OwnershipWriteFailed" end
    return copy(result)
end

function OwnershipService:Transfer(id, expectedOwner, expectedRevision, newOwner, newSlot, op, check)
    if not identifier(id, MAX_ID) or not self:_owner(expectedOwner, false)
        or not self:_owner(newOwner, false) or expectedOwner == newOwner
        or not integer(expectedRevision, 1, MAX_REVISION - 1)
        or not integer(newSlot, 1, self._Config.Game.MaxSlots or 20) or not operationId(op) then
        return nil, "InvalidOwnershipTransfer"
    end
    local function same(raw)
        return raw.OperationId == op and raw.OwnerId == newOwner and raw.Slot == newSlot
            and raw.Revision == expectedRevision + 1
    end
    local current, readFailure = self:Get(id)
    if readFailure then return nil, readFailure end
    if not current then return nil, "HouseNotFound" end
    if same(current) then return current end
    if current.OwnerId ~= expectedOwner or current.Revision ~= expectedRevision then return nil, "OwnershipChanged" end
    if not checkAllowed(check) then return nil, "OwnershipCheckFailed" end
    local indexed, indexFailure = self:_reference(newOwner, id, expectedRevision + 1, op)
    if not indexed then return nil, indexFailure end
    local ok, result, reason = self:_retry(function()
        local rejection
        local written = self._Store:UpdateAsync("House_" .. id, function(raw)
            rejection = nil
            if raw == nil then rejection = "HouseNotFound"; return nil end
            if not self:_valid(raw, id) then rejection = "InvalidOwnershipRecord"; return nil end
            if same(raw) then return copy(raw) end
            if raw.OwnerId ~= expectedOwner or raw.Revision ~= expectedRevision then
                rejection = "OwnershipChanged"; return nil
            end
            if not checkAllowed(check) then rejection = "OwnershipCheckFailed"; return nil end
            local changed = copy(raw)
            changed.OwnerId, changed.Slot, changed.Revision = newOwner, newSlot, expectedRevision + 1
            changed.OperationId, changed.OwnedSince = op, math.max(raw.CreatedAt, self._Now())
            return changed
        end)
        return written, rejection
    end)
    if not ok or not result then return nil, reason or "OwnershipWriteFailed" end
    if not self:_valid(result, id) or not same(result) then return nil, "OwnershipWriteFailed" end
    return copy(result)
end

function OwnershipService:Remove(id, expectedOwner, expectedRevision, op, check)
    if not identifier(id, MAX_ID) or not self:_owner(expectedOwner, false)
        or not integer(expectedRevision, 1, MAX_REVISION - 1) or not operationId(op) then
        return nil, "InvalidOwnershipRemoval"
    end
    local function same(raw)
        return raw.OperationId == op and raw.OwnerId == 0 and raw.Slot == 0
            and raw.Revision == expectedRevision + 1
    end
    local ok, result, reason = self:_retry(function()
        local rejection
        local written = self._Store:UpdateAsync("House_" .. id, function(raw)
            rejection = nil
            if raw == nil then rejection = "HouseNotFound"; return nil end
            if not self:_valid(raw, id) then rejection = "InvalidOwnershipRecord"; return nil end
            if same(raw) then return copy(raw) end
            if raw.OwnerId ~= expectedOwner or raw.Revision ~= expectedRevision then
                rejection = "OwnershipChanged"; return nil
            end
            if not checkAllowed(check) then rejection = "OwnershipCheckFailed"; return nil end
            local removed = copy(raw)
            removed.OwnerId, removed.Slot, removed.Revision = 0, 0, expectedRevision + 1
            removed.OperationId, removed.OwnedSince = op, math.max(raw.CreatedAt, self._Now())
            return removed
        end)
        return written, rejection
    end)
    if not ok or not result then return nil, reason or "OwnershipWriteFailed" end
    if not self:_valid(result, id) or not same(result) then return nil, "OwnershipWriteFailed" end
    return copy(result)
end

return OwnershipService
