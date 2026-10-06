-- One server-owned scheduler; bootstrap calls Tick instead of starting independent loops.
local EventService = {}
EventService.__index = EventService

local SUPPORTED = { Blackout = true, GoldenHour = true, PoliceRaid = true, DoubleCash = true, DoubleXP = true }
local MULTIPLIERS = { Cash = "CashMultiplier", XP = "XPMultiplier", Security = "SecurityMultiplier", Spawn = "SpawnMultiplier" }

local function service(ctx, name)
    if ctx[name] then return ctx[name] end
    if game then return game:GetService(name) end
    return nil
end

function EventService.new(ctx)
    local clock = ctx.Clock or os.time
    local ids = {}
    for id, definition in pairs(ctx.Config.Events) do
        if SUPPORTED[id] and definition.Enabled ~= false then table.insert(ids, id) end
    end
    table.sort(ids)
    return setmetatable({
        ctx = ctx, clock = clock, lighting = service(ctx, "Lighting"), players = service(ctx, "Players"),
        colors = ctx.Color3 or Color3,
        active = nil, lightingBefore = nil, ids = ids, sequence = 0,
        nextAt = clock() + (ctx.Config.Game.EventIntervalSeconds or 480),
    }, EventService)
end

function EventService:_announce(text, kind)
    if self.ctx.Announce then
        self.ctx.Announce(text, kind)
    elseif self.players then
        for _, player in ipairs(self.players:GetPlayers()) do
            if self.ctx.Notify then self.ctx.Notify(player, text, kind) end
            if self.ctx.Publish and self.ctx.Data:Get(player) then self.ctx.Publish(player) end
        end
    end
end

function EventService:_restoreLighting()
    if self.lighting and self.lightingBefore then
        for key, value in pairs(self.lightingBefore) do self.lighting[key] = value end
    end
    self.lightingBefore = nil
end

function EventService:_visual(id)
    if not self.lighting then return end
    self.lightingBefore = {
        ClockTime = self.lighting.ClockTime, Brightness = self.lighting.Brightness,
        Ambient = self.lighting.Ambient, OutdoorAmbient = self.lighting.OutdoorAmbient,
    }
    if id == "Blackout" then
        self.lighting.ClockTime = 0
        self.lighting.Brightness = 0.45
        self.lighting.Ambient = self.colors.fromRGB(25, 27, 45)
        self.lighting.OutdoorAmbient = self.colors.fromRGB(35, 38, 59)
    elseif id == "GoldenHour" then
        self.lighting.ClockTime = 17.3
        self.lighting.Brightness = 2.4
        self.lighting.Ambient = self.colors.fromRGB(165, 133, 85)
    elseif id == "PoliceRaid" then
        self.lighting.ClockTime = 19
        self.lighting.Ambient = self.colors.fromRGB(86, 86, 120)
    end
end

function EventService:StartEvent(id)
    local definition = type(id) == "string" and self.ctx.Config.Events[id] or nil
    if not definition or not SUPPORTED[id] or definition.Enabled == false then
        return false, "This event is unavailable in the launch build."
    end
    if self.active then self:StopEvent() end
    local now = self.clock()
    self.active = {
        Id = id, Name = definition.Name, Color = definition.Color,
        StartedAt = now, EndsAt = now + definition.Duration, Duration = definition.Duration,
    }
    self:_visual(id)
    self:_announce(definition.Name .. "! " .. definition.Duration .. " seconds remaining.", "Event")
    if self.ctx.Analytics then self.ctx.Analytics:Emit(nil, "EventStarted", { Event = id }) end
    return true
end

function EventService:StopEvent()
    if not self.active then return end
    local name = self.active.Name
    local id = self.active.Id
    self.active = nil
    self:_restoreLighting()
    self.nextAt = self.clock() + (self.ctx.Config.Game.EventIntervalSeconds or 480)
    self:_announce(name .. " has ended.", "Event")
    if self.ctx.Analytics then self.ctx.Analytics:Emit(nil, "EventEnded", { Event = id }) end
end

function EventService:GetActive()
    if not self.active or self.clock() >= self.active.EndsAt then return nil end
    return {
        Id = self.active.Id, Name = self.active.Name, Color = self.active.Color,
        StartedAt = self.active.StartedAt, EndsAt = self.active.EndsAt, Duration = self.active.Duration,
        SecondsRemaining = math.max(0, self.active.EndsAt - self.clock()),
    }
end

function EventService:GetActiveEvent()
    return self:GetActive()
end

function EventService:IsActive(id)
    local active = self:GetActive()
    return active ~= nil and active.Id == id
end

function EventService:Multiplier(kind)
    local active = self:GetActive()
    if not active then return 1 end
    local definition = self.ctx.Config.Events[active.Id]
    if kind == "Heat" and active.Id == "PoliceRaid" then return definition.HeatMultiplier or 1.5 end
    local field = MULTIPLIERS[kind] or (kind .. "Multiplier")
    return definition[field] or 1
end

function EventService:Tick(_dt)
    local now = self.clock()
    if self.active then
        if now >= self.active.EndsAt then self:StopEvent() end
        return
    end
    if now >= self.nextAt and #self.ids > 0 then
        self.sequence = self.sequence % #self.ids + 1
        self:StartEvent(self.ids[self.sequence])
    end
end

function EventService:Destroy()
    self.active = nil
    self:_restoreLighting()
end

return EventService
