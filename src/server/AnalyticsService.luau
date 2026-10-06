-- Bounded aggregate metrics. No inventory, credential, chat, or personal data is logged.
local AnalyticsService = {}
AnalyticsService.__index = AnalyticsService

local function validAmount(amount)
    return type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge
end

local function bounded(value)
    if type(value) == "string" then return string.sub(value, 1, 100) end
    if type(value) == "boolean" then return tostring(value) end
    if type(value) == "number" and value == value and math.abs(value) < math.huge then return tostring(value) end
    return nil
end

function AnalyticsService.new(ctx)
    return setmetatable({
        ctx = ctx, clock = ctx.Clock or os.time, counters = {}, samples = {}, eventCount = 0,
        sources = 0, sinks = 0, lastConsole = {}, windowAt = 0, backendCount = 0,
        sessions = {},
    }, AnalyticsService)
end

function AnalyticsService:InitPlayer(player)
    self.sessions[player] = { StartedAt = self.clock(), FirstRobbery = false, FirstItem = false, FirstUpgrade = false }
    self:Emit(player, "SessionStarted", {})
end

function AnalyticsService:Emit(player, event, fields)
    if type(event) ~= "string" or #event < 1 or #event > 48 or not string.match(event, "^[%w_]+$") then return end
    if self.counters[event] == nil then
        if self.eventCount >= 64 then return end
        self.eventCount += 1
        self.counters[event] = 0
    end
    self.counters[event] += 1
    fields = type(fields) == "table" and fields or {}
    if event == "CashSource" and validAmount(fields.Amount) then self.sources += fields.Amount end
    if event == "CashSink" and validAmount(fields.Amount) then self.sinks += fields.Amount end
    local clean = {}
    local keys = {}
    for key in pairs(fields) do
        if type(key) == "string" and #key <= 32 then table.insert(keys, key) end
    end
    table.sort(keys)
    for index = 1, math.min(8, #keys) do
        local key = keys[index]
        local value = bounded(fields[key])
        if value then clean[key] = value end
    end
    self.samples[event] = clean
    local now = self.clock()
    -- One console sample per event per minute, with at most 64 distinct event labels.
    if not self.lastConsole[event] or now - self.lastConsole[event] >= 60 then
        self.lastConsole[event] = now
        local parts = { "[StealAHouse analytics]", "event=" .. event, "count=" .. self.counters[event] }
        for _, key in ipairs(keys) do
            if clean[key] then table.insert(parts, key .. "=" .. clean[key]) end
        end
        local log = self.ctx.Log or print
        log(table.concat(parts, " "))
    end
    -- Roblox telemetry is optional and queued; it never yields inside an economy transaction.
    local backend = self.ctx.AnalyticsBackend
    if not backend or not player or self.ctx.Config.Game.EnableRobloxAnalytics ~= true then return end
    if now - self.windowAt >= 60 then self.windowAt = now; self.backendCount = 0 end
    if self.backendCount >= 100 then return end
    self.backendCount += 1
    local custom = {}
    for index = 1, math.min(3, #keys) do
        if clean[keys[index]] then custom["CustomField0" .. index] = keys[index] .. ":" .. clean[keys[index]] end
    end
    local spawn = self.ctx.Spawn or task.spawn
    spawn(function()
        pcall(function() backend:LogCustomEvent(player, event, 1, custom) end)
    end)
end

function AnalyticsService:Economy(player, flow, amount, reason)
    if flow ~= "Source" and flow ~= "Sink" then return end
    self:Emit(player, "Cash" .. flow, { Amount = amount, Reason = reason })
end

function AnalyticsService:Milestone(player, milestone)
    local session = self.sessions[player]
    if not session or session[milestone] ~= false then return end
    session[milestone] = true
    self:Emit(player, milestone, { SecondsSinceJoin = self.clock() - session.StartedAt })
end

function AnalyticsService:Remove(player)
    local session = self.sessions[player]
    if session then self:Emit(player, "SessionEnded", { Seconds = self.clock() - session.StartedAt }) end
    self.sessions[player] = nil
end

function AnalyticsService:Get()
    local counts = {}
    for event, count in pairs(self.counters) do counts[event] = count end
    return { Counters = counts, CashCreated = self.sources, CashDestroyed = self.sinks }
end

return AnalyticsService
