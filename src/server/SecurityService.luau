local Security = {}
Security.__index = Security
function Security.new(ctx) return setmetatable({ Context = ctx, Disabled = {} }, Security) end
function Security:Level(house)
    return math.clamp(tonumber(house.Difficulty) or house.Area or 1, 1, 10)
end
function Security:DetectionDelay(player, house)
    local ctx = self.Context
    local spec = ctx.Config.Security[self:Level(house)]
    local profile = ctx.Data:Get(player)
    local tool = profile and ctx.Config.Tools[profile.Tools.LockpickLevel]
    return math.max(1, (spec.DetectionDelay + (tool and tool.DetectionReduction or 0)) / math.max(0.1, ctx.Events:Multiplier("Security")))
end
function Security:IsDisabled(player, house)
    local map = self.Disabled[player]
    return map ~= nil and (map[house.Id] or 0) > os.clock()
end
function Security:Disable(player, id)
    local ctx = self.Context
    local house = typeof(id) == "string" and ctx.World:GetNPC(id)
    local profile = ctx.Data:Get(player)
    local state = ctx.Robbery:Get(player)
    if not house or not profile or not state or state.TargetHouse ~= house.Id then return false, "Enter this NPC house first." end
    if not ctx.AntiExploit:Near(player, house.EntryPosition, 15) then return false, "Stand near the security panel by the entrance." end
    if profile.Tools.LockpickLevel < math.min(self:Level(house), #ctx.Config.Tools) then return false, "Upgrade your counter-security tool first." end
    if self:IsDisabled(player, house) then return false, "Security is already disabled." end
    self.Disabled[player] = self.Disabled[player] or {}
    self.Disabled[player][id] = os.clock() + 25
    ctx.Notify(player, "Security disabled for 25 seconds.", "Success")
    return true, "Security bypassed. Steal quickly."
end
function Security:Remove(player) self.Disabled[player] = nil end
return Security
