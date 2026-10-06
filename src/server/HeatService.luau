local Heat = {}
Heat.__index = Heat
function Heat.new(ctx) return setmetatable({ Context = ctx, Values = {} }, Heat) end
function Heat:Get(player) return self.Values[player] or 0 end
function Heat:Add(player, amount)
    self.Values[player] = math.clamp(self:Get(player) + amount, 0, 100)
end
function Heat:Tick(dt)
    local ctx = self.Context
    for _, player in ipairs(ctx.Players:GetPlayers()) do
        local robbery = ctx.Robbery:Get(player)
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if robbery and root then
            local target = ctx.World:GetNPC(robbery.TargetHouse)
            if target and ctx.World:GetNPCAt(root.Position) == target then
                local area = ctx.Config.Game.Areas[target.Area]
                self:Add(player, (area.HeatPerSecond or 1) * dt * ctx.Events:Multiplier("Heat"))
            end
        elseif self:Get(player) > 0 then
            self:Add(player, -ctx.Config.Game.HeatDecayPerSecond * dt)
        end
    end
end
function Heat:Remove(player) self.Values[player] = nil end
return Heat
