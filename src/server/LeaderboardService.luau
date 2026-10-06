-- Live stats are synchronous; OrderedDataStore reads/writes run only on a coarse, cached schedule.
local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local GLOBAL_METRICS = { "HouseValue", "CashEarned", "Robberies", "RareItems" }

local function integer(value)
    if type(value) ~= "number" or value ~= value or value < 0 or value >= math.huge then return 0 end
    return math.min(1000000000000000, math.floor(value))
end

local function newInstance(ctx, class)
    return ctx.CreateInstance and ctx.CreateInstance(class) or Instance.new(class)
end

function LeaderboardService.new(ctx)
    local self = setmetatable({
        ctx = ctx, clock = ctx.Clock or os.time, players = {}, pending = {}, written = {}, stores = {},
        global = {}, updatedAt = 0, saveElapsed = 0, readElapsed = 120,
        writing = false, reading = false, storeWarning = false,
        persistent = ctx.Data.Status == "Persistent",
    }, LeaderboardService)
    if self.persistent then
        local backend = ctx.DataStoreService or game:GetService("DataStoreService")
        local prefix = ctx.Config.Game.ProfileStore or "StealAHouse_v2"
        for _, metric in ipairs(GLOBAL_METRICS) do
            self.stores[metric] = backend:GetOrderedDataStore(prefix .. "_Rank_" .. metric)
            self.global[metric] = {}
        end
    end
    return self
end

function LeaderboardService:_warn(message)
    if self.storeWarning then return end
    self.storeWarning = true
    local log = self.ctx.Log or warn
    log("[StealAHouse] Global leaderboard unavailable; live server standings remain active. " .. tostring(message))
end

function LeaderboardService:InitPlayer(player)
    local folder = player:FindFirstChild("leaderstats")
    if not folder then
        folder = newInstance(self.ctx, "Folder")
        folder.Name = "leaderstats"
        folder.Parent = player
    end
    local values = {}
    for _, name in ipairs({ "Cash", "HouseValue", "ItemsStolen", "RareItems" }) do
        local value = folder:FindFirstChild(name)
        if not value then
            value = newInstance(self.ctx, "IntValue")
            value.Name = name
            value.Parent = folder
        end
        values[name] = value
    end
    self.players[player] = { Values = values }
    self:Update(player)
end

function LeaderboardService:Update(player)
    local profile = self.ctx.Data:Get(player)
    local state = self.players[player]
    if not profile or not state then return end
    local statistics = profile.Statistics or {}
    local house = profile.House or {}
    local row = {
        UserId = player.UserId, Name = player.DisplayName or player.Name,
        Cash = integer(profile.Cash), HouseValue = integer(house.HouseValue),
        ItemsStolen = integer(statistics.ItemsStolen), RareItems = integer(statistics.RareItemsFound),
    }
    state.Row = row
    for name, value in pairs(state.Values) do value.Value = row[name] end
    if self.persistent and self.ctx.Data:IsWritable(player) then
        local snapshot = {
            HouseValue = row.HouseValue, CashEarned = integer(statistics.TotalCashEarned),
            Robberies = integer(statistics.SuccessfulRobberies), RareItems = row.RareItems,
        }
        local previous = self.written[player.UserId]
        local changed = not previous
        for _, metric in ipairs(GLOBAL_METRICS) do
            if not previous or snapshot[metric] > (previous[metric] or -1) then changed = true end
        end
        if changed then self.pending[player.UserId] = snapshot end
    end
end

function LeaderboardService:_spawn(callback)
    local spawn = self.ctx.Spawn or task.spawn
    spawn(callback)
end

function LeaderboardService:Flush()
    if not self.persistent or self.writing or next(self.pending) == nil then return end
    local batch = {}
    for userId, values in pairs(self.pending) do batch[userId] = values end
    self.writing = true
    self:_spawn(function()
        for userId, values in pairs(batch) do
            local successful = true
            local cached = self.written[userId] or {}
            for _, metric in ipairs(GLOBAL_METRICS) do
                if not cached[metric] or values[metric] > cached[metric] then
                    local ok, result = pcall(function()
                        return self.stores[metric]:UpdateAsync(tostring(userId), function(old)
                            -- Lifetime records are monotonic, including highest-ever displayed house value.
                            return math.max(integer(old), values[metric])
                        end)
                    end)
                    if ok then
                        cached[metric] = integer(result)
                    else
                        successful = false
                        self:_warn(result)
                    end
                end
            end
            self.written[userId] = cached
            if successful and self.pending[userId] == values then self.pending[userId] = nil end
        end
        self.writing = false
    end)
end

function LeaderboardService:_refresh()
    if not self.persistent or self.reading then return end
    self.reading = true
    self:_spawn(function()
        local refreshed = false
        for _, metric in ipairs(GLOBAL_METRICS) do
            local ok, rows = pcall(function()
                return self.stores[metric]:GetSortedAsync(false, 10):GetCurrentPage()
            end)
            if ok then
                local result = {}
                for _, entry in ipairs(rows) do
                    local userId = tonumber(entry.key)
                    if userId then table.insert(result, { UserId = userId, Value = integer(entry.value) }) end
                end
                self.global[metric] = result
                refreshed = true
            else
                self:_warn(rows)
            end
        end
        if refreshed then self.updatedAt = self.clock() end
        self.reading = false
    end)
end

function LeaderboardService:Get()
    local live, global = {}, {}
    for _, state in pairs(self.players) do
        if state.Row then
            local row = {}
            for key, value in pairs(state.Row) do row[key] = value end
            table.insert(live, row)
        end
    end
    table.sort(live, function(a, b)
        if a.HouseValue ~= b.HouseValue then return a.HouseValue > b.HouseValue end
        if a.Cash ~= b.Cash then return a.Cash > b.Cash end
        return a.UserId < b.UserId
    end)
    for metric, rows in pairs(self.global) do
        global[metric] = {}
        for _, row in ipairs(rows) do table.insert(global[metric], { UserId = row.UserId, Value = row.Value }) end
    end
    return { Live = live, Global = global, PersistenceEnabled = self.persistent, UpdatedAt = self.updatedAt }
end

function LeaderboardService:Remove(player)
    self:Update(player)
    self.players[player] = nil
    self:Flush()
end

function LeaderboardService:Tick(dt)
    self.saveElapsed += dt
    self.readElapsed += dt
    if self.saveElapsed >= 90 then self.saveElapsed = 0; self:Flush() end
    if self.readElapsed >= 120 then self.readElapsed = 0; self:_refresh() end
end

return LeaderboardService
