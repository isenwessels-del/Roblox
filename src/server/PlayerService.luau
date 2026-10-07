local PlayerService = {}
PlayerService.__index = PlayerService
function PlayerService.new(ctx)
    return setmetatable({ Context = ctx, Cleaning = {}, Connections = {}, Characters = {},
        Joining = setmetatable({}, { __mode = "k" }) }, PlayerService)
end
function PlayerService:_character(player, character)
    local ctx = self.Context
    local root = character:WaitForChild("HumanoidRootPart", 10)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not root or not humanoid or player.Character ~= character or player.Parent ~= ctx.Players then return end
    self.Characters[player] = character
    local plot = ctx.World:GetPlot(player)
    if plot then
        ctx.AntiExploit:AllowTeleport(player)
        root.CFrame = CFrame.new(plot.Spawn) * plot.Frame.Rotation
        ctx.World:SetCharacterGroup(player)
    end
    ctx.Progression:UpdateSpeed(player)
    humanoid.Died:Connect(function()
        ctx.Steal:Cancel(player, "You dropped the house.")
        ctx.Progression:Train(player, false)
        ctx.Progression:SetSprint(player, false)
    end)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack and not backpack:FindFirstChild("House Defender") then
        local tool = Instance.new("Tool")
        tool.Name, tool.RequiresHandle, tool.CanBeDropped = "House Defender", true, false
        tool.ToolTip = "Stops nearby house carriers. R / touch Bat / controller trigger"
        local handle = Instance.new("Part")
        handle.Name, handle.Size = "Handle", Vector3.new(0.65, 3.4, 0.65)
        handle.Material, handle.Color = Enum.Material.Wood, Color3.fromRGB(173, 117, 65)
        handle.CanCollide, handle.CanTouch, handle.Massless = false, false, true
        handle.Parent = tool
        tool.Grip = CFrame.new(0, -0.8, 0)
        tool.Activated:Connect(function() ctx.Request(player, "Bat") end)
        tool.Parent = backpack
    end
end
function PlayerService:_join(player)
    local ctx = self.Context
    if self.Joining[player] or ctx.Closing or player.Parent ~= ctx.Players then return end
    self.Joining[player] = true
    ctx.AntiExploit:Register(player)
    self.Connections[player] = player.CharacterAdded:Connect(function(character) self:_character(player, character) end)
    local profile, loadError = ctx.Data:Load(player)
    if not profile then
        if player.Parent == ctx.Players then player:Kick("Your save could not be opened safely. Please rejoin. " .. tostring(loadError)) end
        return
    end
    if ctx.Closing or player.Parent ~= ctx.Players then ctx.Data:Release(player); return end
    local plot = ctx.World:Assign(player)
    if not plot then player:Kick("Every base is occupied. Please join another server."); return end
    local ok, attachError = ctx.Houses:Attach(player)
    if not ok then
        if player.Parent == ctx.Players then player:Kick("Your house ownership could not be verified. Please rejoin. " .. tostring(attachError)) end
        return
    end
    if ctx.Closing or player.Parent ~= ctx.Players then self:Cleanup(player); ctx.Data:Release(player); return end
    ctx.Ready[player] = true
    ctx.Progression:OnJoin(player)
    if player.Character and self.Characters[player] ~= player.Character then self:_character(player, player.Character)
    elseif player.Character then
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if root then ctx.AntiExploit:AllowTeleport(player); root.CFrame = CFrame.new(plot.Spawn) * plot.Frame.Rotation end
        ctx.World:SetCharacterGroup(player)
        ctx.Progression:UpdateSpeed(player)
    end
    ctx.Publish(player)
    ctx.Notify(player, "Welcome! Steal a growing house box, bring it home, and collect rent. Train on your treadmill to reach richer streets.", "Info")
end
function PlayerService:Cleanup(player)
    if self.Cleaning[player] then return end
    self.Cleaning[player] = true
    local ctx = self.Context
    ctx.Ready[player] = nil
    ctx.Steal:Release(player)
    ctx.Progression:Release(player)
    local deadline = os.clock() + 20
    -- Give an acknowledged ledger operation time to settle before its profiles unload.
    while ctx.Houses.Busy[player] and os.clock() < deadline do task.wait(0.05) end
    ctx.Houses:Release(player)
    ctx.World:Release(player)
    ctx.AntiExploit:Remove(player)
    if self.Connections[player] then self.Connections[player]:Disconnect(); self.Connections[player] = nil end
    self.Characters[player] = nil
    -- Weak keys prevent departed Player instances from being kept forever.
end
function PlayerService:Start()
    self.Cleaning = setmetatable({}, { __mode = "k" })
    local ctx = self.Context
    ctx.Players.PlayerAdded:Connect(function(player) task.spawn(function() self:_join(player) end) end)
    for _, player in ipairs(ctx.Players:GetPlayers()) do task.spawn(function() self:_join(player) end) end
end
return PlayerService
