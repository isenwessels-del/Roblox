local PlayerService = {}
PlayerService.__index = PlayerService
function PlayerService.new(ctx) return setmetatable({ Context = ctx, Joined = {}, Connections = {}, Cleaned = setmetatable({}, { __mode = "k" }) }, PlayerService) end
function PlayerService:Spawn(player, character)
    local ctx = self.Context
    local root = character:WaitForChild("HumanoidRootPart", 10)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local plot = ctx.World:GetPlot(player)
    if root and humanoid and plot and player.Character == character then
        ctx.AntiExploit:AllowTeleport(player)
        character:PivotTo(CFrame.new(plot.Origin + Vector3.new(0, 5, -20)))
        ctx.AntiExploit:ValidateMovement(player)
        humanoid.WalkSpeed = ctx.Config.Game.MoveSpeed
        local connection = humanoid.Died:Connect(function() ctx.Robbery:Fail(player, "You were caught during the robbery") end)
        self.DeathConnections = self.DeathConnections or {}
        if self.DeathConnections[player] then self.DeathConnections[player]:Disconnect() end
        self.DeathConnections[player] = connection
    end
end
function PlayerService:Join(player)
    local ctx = self.Context
    if self.Joined[player] or ctx.Closing then return end
    self.Joined[player] = true
    ctx.AntiExploit:Register(player)
    ctx.Notify(player, "Loading your house and collection…", "Info")
    local profile, errorMessage = ctx.Data:Load(player)
    if player.Parent ~= ctx.Players then ctx.Data:Release(player); self.Joined[player] = nil; ctx.AntiExploit:Remove(player); return end
    if not profile then
        self.Joined[player] = nil
        player:Kick("Your saved data could not be loaded safely (" .. tostring(errorMessage) .. "). Please try another server.")
        return
    end
    local plot = ctx.World:Assign(player)
    if not plot then
        ctx.Data:Release(player)
        player:Kick("All eight plots are occupied. Please join another server.")
        return
    end
    ctx.House:Render(player)
    ctx.Quest:InitPlayer(player)
    ctx.Leaderboard:InitPlayer(player)
    ctx.Analytics:InitPlayer(player)
    self.Connections[player] = player.CharacterAdded:Connect(function(character) self:Spawn(player, character) end)
    if player.Character then task.spawn(function() self:Spawn(player, player.Character) end) end
    if ctx.Data.Status == "StudioMemory" then ctx.Notify(player, "Studio practice mode: progress is not saved. Enable StudioPersistence only in a test place to test saving.", "Warning") end
    ctx.Publish(player)
end
function PlayerService:Cleanup(player)
    if self.Cleaned[player] then return end
    self.Cleaned[player] = true
    local ctx = self.Context
    ctx.Robbery:Remove(player)
    if self.Connections[player] then self.Connections[player]:Disconnect(); self.Connections[player] = nil end
    if self.DeathConnections and self.DeathConnections[player] then self.DeathConnections[player]:Disconnect(); self.DeathConnections[player] = nil end
    ctx.World:Release(player)
    ctx.Quest:Remove(player)
    ctx.Leaderboard:Remove(player)
    ctx.Analytics:Remove(player)
    ctx.Heat:Remove(player)
    ctx.Security:Remove(player)
    ctx.AntiExploit:Remove(player)
    self.Joined[player] = nil
end
function PlayerService:Start()
    local ctx = self.Context
    ctx.Players.PlayerAdded:Connect(function(player) task.spawn(function() self:Join(player) end) end)
    ctx.Players.PlayerRemoving:Connect(function(player)
        self:Cleanup(player)
        ctx.Data:Release(player)
        self.Cleaned[player] = nil
    end)
    for _, player in ipairs(ctx.Players:GetPlayers()) do task.spawn(function() self:Join(player) end) end
end
return PlayerService
