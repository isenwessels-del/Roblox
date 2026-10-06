-- Profiles are private server state. A failed load never creates a playable default.
-- Each persistent record has a renewable lease; every write verifies its token.
-- Saves serialize per profile and snapshot only after entering that queue. A save
-- never replaces the live profile, so mutations during a yield remain in memory
-- for the next save. Release freezes transactions before taking its final snapshot.
local DataService = {}
DataService.__index = DataService

local function copy(value, seen, depth, budget)
    local kind = type(value)
    if kind == "number" then
        assert(value == value and math.abs(value) ~= math.huge, "Non-finite profile number")
    elseif kind == "string" then
        assert(#value <= 100000, "Oversized profile string")
    elseif kind == "table" then
        seen, depth, budget = seen or {}, depth or 0, budget or { Count = 0 }
        assert(not seen[value] and depth < 32, "Cyclic or excessively nested profile")
        seen[value] = true
        local result = {}
        for key, item in pairs(value) do
            budget.Count += 1
            assert(budget.Count <= 10000, "Oversized profile")
            assert(type(key) == "string" or (type(key) == "number" and key == key and math.abs(key) ~= math.huge), "Invalid profile key")
            result[key] = copy(item, seen, depth + 1, budget)
        end
        seen[value] = nil
        return result
    else
        assert(kind == "boolean" or kind == "nil", "Profile contains a nonserializable value")
    end
    return value
end

local function playerKey(player)
    return "Player_" .. tostring(player.UserId)
end

local function unpackRecord(raw)
    if raw == nil then return nil, nil, 0 end
    if type(raw) ~= "table" then return nil, nil, 0, "InvalidProfile" end
    if raw._RecordVersion == nil then return raw, nil, 0 end -- pre-envelope profiles
    if raw._RecordVersion ~= 1 or type(raw.Data) ~= "table" then
        return nil, nil, 0, "UnsupportedRecordVersion"
    end
    local session = raw.Session
    if session ~= nil and (type(session) ~= "table" or type(session.Token) ~= "string"
        or type(session.ExpiresAt) ~= "number" or session.ExpiresAt ~= session.ExpiresAt
        or math.abs(session.ExpiresAt) == math.huge) then
        return nil, nil, 0, "InvalidSession"
    end
    local revision = raw.Revision
    if type(revision) ~= "number" or revision < 0 or revision ~= math.floor(revision)
        or revision == math.huge then return nil, nil, 0, "InvalidRevision" end
    if raw.LastWrite ~= nil and (type(raw.LastWrite) ~= "table" or type(raw.LastWrite.Token) ~= "string"
        or type(raw.LastWrite.Id) ~= "string") then return nil, nil, 0, "InvalidWriteMarker" end
    return raw.Data, session, revision
end

function DataService.new(ctx, options)
    options = options or {}
    local self = setmetatable({}, DataService)
    self._Ctx, self._Entries, self._Loading = ctx, {}, {}
    self._WriteSequence = 0
    self._Schema = options.Schema or ctx.Schema
    if not self._Schema then
        self._Schema = require(game:GetService("ReplicatedStorage").Shared.ProfileSchema)
    end
    self._Now = options.Now or os.time -- leases must use wall time across servers
    self._Wait = options.Wait or task.wait
    self._Spawn = options.Spawn or task.spawn
    self._RetryCount = options.RetryCount or 4
    self._Players, self._BindToClose = options.Players, options.BindToClose
    local config = ctx.Config.Game
    self._AutoSave = config.AutoSaveSeconds or 90
    self._Lease = config.SessionLeaseSeconds or 180
    self._Safety = math.min(options.SafetySeconds or 15, self._Lease / 4)
    assert(self._AutoSave > 0 and self._AutoSave + self._Safety < self._Lease, "Autosave must precede lease expiry")
    local isStudio = options.IsStudio
    if isStudio == nil then isStudio = game:GetService("RunService"):IsStudio() end
    self.Status = isStudio and not config.StudioPersistence and "StudioMemory" or "Persistent"
    self._Token = options.Token
    if not self._Token then self._Token = game:GetService("HttpService"):GenerateGUID(false) end
    if self.Status == "Persistent" then
        self._Store = options.Store or game:GetService("DataStoreService"):GetDataStore(config.ProfileStore)
        assert(self._Store ~= nil, "Persistent mode requires a real profile store")
    end
    return self
end

function DataService:_signal(entry, text, kind)
    if self._Ctx.Notify then pcall(self._Ctx.Notify, entry.Player, text, kind) end
    if self._Ctx.Publish then pcall(self._Ctx.Publish, entry.Player) end
end

function DataService:_retry(operation)
    for attempt = 1, self._RetryCount do
        local ok, result, reason = pcall(operation)
        if ok then return result, reason end
        if attempt < self._RetryCount then self._Wait(math.min(2 ^ (attempt - 1), 4)) end
    end
    return nil, "DataStoreUnavailable"
end

function DataService:_valid(profile)
    if type(profile) ~= "table" or profile.Version ~= 2 then return false end
    if self._Schema.Validate then
        local ok, valid = pcall(self._Schema.Validate, profile)
        return ok and valid == true
    end
    return true
end

function DataService:Get(player)
    local entry = self._Entries[playerKey(player)]
    return entry and entry.Player == player and entry.Profile or nil
end

function DataService:GetStatus(player)
    local entry = self._Entries[playerKey(player)]
    if not entry or entry.Player ~= player then return { Mode = self.Status, Loaded = false, Writable = false } end
    return { Mode = self.Status, Loaded = true, Writable = self:IsWritable(player),
        Saving = entry.Saving == true, Error = entry.Error, Revision = entry.Revision }
end

function DataService:IsWritable(player)
    local entry = self._Entries[playerKey(player)]
    if not entry or entry.Player ~= player or self._Closing or entry.Releasing or entry.Lost then return false end
    if self.Status == "StudioMemory" then return true end
    if self._Now() >= entry.LeaseUntil - self._Safety then
        if not entry.Frozen then
            entry.Frozen = true
            entry.Error = "LeaseRenewalRequired"
            self:_signal(entry, "Saving is unavailable. Transactions are paused to protect your progress.", "Warning")
        end
        return false
    end
    return not entry.Frozen
end

function DataService:Load(player)
    local key = playerKey(player)
    if self._Closing or self._CloseStarted then return nil, "ServerClosing" end
    local existing = self._Entries[key]
    if existing then
        if existing.Player == player and not existing.Lost and not existing.Releasing then return existing.Profile end
        if existing.Player == player then return nil, existing.Error or "ProfileReleasing" end
        return nil, "AlreadyLoaded"
    end
    if self._Loading[key] then return nil, "LoadInProgress" end
    self._Loading[key] = true
    local token = self._Token .. ":" .. key
    local profile, lease, revision, failure
    if self.Status == "StudioMemory" then
        local ok, result = pcall(self._Schema.New, self._Now())
        if ok then profile, lease, revision = result, math.huge, 0 else failure = "InvalidDefaultProfile" end
    else
        local record, reason = self:_retry(function()
            local rejection
            local result = self._Store:UpdateAsync(key, function(raw)
                rejection = nil -- UpdateAsync may invoke this callback repeatedly
                local data, session, oldRevision, unpackError = unpackRecord(raw)
                if unpackError then rejection = unpackError; return nil end
                local now = self._Now()
                if session and session.Token ~= token and session.ExpiresAt > now then
                    rejection = "SessionLocked"; return nil
                end
                local ok, migrated, migrationError = pcall(function()
                    if data == nil then return self._Schema.New(now) end
                    return self._Schema.Migrate(copy(data), now)
                end)
                if not ok or migrated == nil then rejection = migrationError or "MigrationFailed"; return nil end
                local copied, snapshot = pcall(copy, migrated)
                if not copied or not self:_valid(snapshot) then rejection = "InvalidProfile"; return nil end
                return { _RecordVersion = 1, Data = snapshot, Revision = oldRevision,
                    Session = { Token = token, ExpiresAt = now + self._Lease } }
            end)
            return result, rejection
        end)
        if record and record._RecordVersion == 1 and record.Session
            and record.Session.Token == token and record.Session.ExpiresAt > self._Now() then
            profile, lease, revision = copy(record.Data), record.Session.ExpiresAt, record.Revision
        else failure = reason or "SessionLost" end
    end
    if not profile or not self:_valid(profile) then
        self._Loading[key] = nil
        return nil, failure or "InvalidProfile"
    end
    local entry = { Player = player, Profile = profile, Token = token, LeaseUntil = lease,
        Revision = revision, NextSave = self._Now() + self._AutoSave }
    self._Entries[key] = entry
    if self._Closing or self._CloseStarted then
        if not self:Release(player) then self._LateReleaseFailed = true end
        self._Loading[key] = nil
        return nil, "ServerClosing"
    end
    self._Loading[key] = nil
    return profile
end

function DataService:Save(player, release)
    local key = playerKey(player)
    local entry = self._Entries[key]
    if not entry or entry.Player ~= player then return false, "ProfileNotLoaded" end
    if release then entry.Releasing = true end -- freeze before waiting for an in-flight save
    while entry.Saving do
        self._Wait(0.05)
        if self._Entries[key] ~= entry then return release == true, if release then nil else "ProfileReleased" end
    end
    if entry.Lost then
        if release then self._Entries[key] = nil end
        return false, entry.Error or "SessionLost"
    end
    if (entry.Releasing or self._Closing) and not release then return false, "ProfileReleasing" end
    entry.Saving = true
    local copied, snapshot = pcall(copy, entry.Profile)
    if not copied or not self:_valid(snapshot) then
        entry.Saving, entry.Error, entry.Frozen = false, "InvalidProfile", true
        return false, entry.Error
    end
    if self.Status == "StudioMemory" then
        entry.Revision += 1
        entry.Saving, entry.Error = false, nil
        if release then self._Entries[key] = nil end
        return true
    end
    self._WriteSequence += 1
    local operationId = entry.Token .. ":" .. tostring(self._WriteSequence)
    local record, failure = self:_retry(function()
        local rejection
        local result = self._Store:UpdateAsync(key, function(raw)
            rejection = nil
            local _, session, oldRevision, unpackError = unpackRecord(raw)
            if unpackError then rejection = unpackError; return nil end
            local now = self._Now()
            -- A committed write can still produce a network error. Retrying an
            -- already completed release must recognize this operation, without
            -- releasing any lease subsequently acquired by a different session.
            local lastWrite = raw and raw.LastWrite
            if lastWrite and lastWrite.Token == entry.Token and lastWrite.Id == operationId then
                if (release and session == nil) or (not release and session
                    and session.Token == entry.Token and session.ExpiresAt > now) then return copy(raw) end
            end
            if not session or session.Token ~= entry.Token or session.ExpiresAt <= now then
                rejection = "SessionLost"; return nil
            end
            return { _RecordVersion = 1, Data = copy(snapshot), Revision = oldRevision + 1,
                LastWrite = { Token = entry.Token, Id = operationId },
                Session = if release then nil else { Token = entry.Token, ExpiresAt = now + self._Lease } }
        end)
        return result, rejection
    end)
    -- A cancelled UpdateAsync may return nil; success always requires our written snapshot.
    if record and record._RecordVersion == 1 and record.Revision > entry.Revision
        and record.LastWrite and record.LastWrite.Token == entry.Token and record.LastWrite.Id == operationId
        and (release and record.Session == nil or not release and record.Session
            and record.Session.Token == entry.Token and record.Session.ExpiresAt > self._Now()) then
        entry.Revision, entry.Error, entry.Frozen = record.Revision, nil, false
        if not release then entry.LeaseUntil = record.Session.ExpiresAt end
        entry.NextSave = self._Now() + self._AutoSave
        entry.Saving = false
        if release then self._Entries[key] = nil end
        return true
    end
    entry.Saving, entry.Error = false, failure or "SessionLost"
    entry.NextSave = self._Now() + math.min(15, self._AutoSave)
    if entry.Error ~= "DataStoreUnavailable"
        or self._Now() >= entry.LeaseUntil then
        entry.Lost, entry.Frozen = true, true
        self:_signal(entry, "Your data session has ended. Rejoin to protect your progress.", "Error")
        if entry.Releasing then self._Entries[key] = nil end
    else
        self:IsWritable(player) -- freeze before the safety boundary even if retries consumed time
    end
    return false, entry.Error
end

function DataService:Release(player)
    if not self:Get(player) then return true end
    return self:Save(player, true)
end

function DataService:Start()
    if self._Started then return end
    self._Started = true
    local players = self._Players or game:GetService("Players")
    self._LeaveConnection = players.PlayerRemoving:Connect(function(player)
        if self._Ctx.BeforeDataRelease then pcall(self._Ctx.BeforeDataRelease, player) end
        self:Release(player)
    end)
    local bind = self._BindToClose or function(callback) game:BindToClose(callback) end
    bind(function() self:Close() end)
    self._Spawn(function()
        while not self._Closing do
            self._Wait(math.min(10, self._AutoSave / 2))
            if self._Closing then break end
            local now = self._Now()
            for _, entry in pairs(self._Entries) do
                self:IsWritable(entry.Player)
                if entry.Lost and entry.Releasing then self._Entries[playerKey(entry.Player)] = nil end
                if not entry.Saving and not entry.Lost and now >= entry.NextSave then
                    entry.NextSave = now + self._AutoSave
                    self._Spawn(function()
                        if entry.Releasing then self:Release(entry.Player) else self:Save(entry.Player) end
                    end)
                end
            end
        end
    end)
end

function DataService:Close()
    if self._CloseStarted then return self._CloseResult or false end
    self._CloseStarted = true
    -- Gameplay first settles temporary loot while profiles are still writable.
    -- The caller's hook must prevent new gameplay transactions immediately.
    if self._Ctx.BeforeDataClose then pcall(self._Ctx.BeforeDataClose) end
    self._Closing = true
    if self._LeaveConnection then self._LeaveConnection:Disconnect() end
    local pending, complete, failed = {}, 0, false
    for _, entry in pairs(self._Entries) do
        entry.Releasing = true
        table.insert(pending, entry.Player)
    end
    for _, player in ipairs(pending) do
        self._Spawn(function()
            local ok = self:Release(player)
            if not ok then failed = true end
            complete += 1
        end)
    end
    local deadline = self._Now() + 25
    while (complete < #pending or next(self._Loading) ~= nil) and self._Now() < deadline do self._Wait(0.05) end
    self._CloseResult = complete == #pending and next(self._Loading) == nil and not failed and not self._LateReleaseFailed
    return self._CloseResult
end

return DataService
