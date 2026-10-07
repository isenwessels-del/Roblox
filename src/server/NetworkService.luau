-- Remotes and all physical prompts share one narrow server-side action router.
local Network = {}
Network.__index = Network
local allowed = { Sync = true, Buy = true, Steal = true, WildSteal = true, Sell = true,
    Collect = true, CollectAll = true, Lock = true, Bat = true, Sprint = true, Train = true,
    BaseUpgrade = true, TreadmillUpgrade = true, SecurityUpgrade = true, Daily = true,
    Setting = true, OpenShop = true }
function Network.new(ctx)
    local self = setmetatable({ Context = ctx, Remotes = {} }, Network)
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "HouseRemotes", ctx.ReplicatedStorage
    for _, name in ipairs({ "Request", "Snapshot", "Notification", "Announcement" }) do
        local remote = Instance.new("RemoteEvent")
        remote.Name, remote.Parent = name, folder
        self.Remotes[name] = remote
    end
    self.Remotes.Request.OnServerEvent:Connect(function(player, action, a, b)
        self:Request(player, action, a, b)
    end)
    return self
end
function Network:Request(player, action, a, b)
    local ctx = self.Context
    if type(action) ~= "string" or #action > 32 or not allowed[action] then return end
    if ctx.Closing or not ctx.AntiExploit:Rate(player, action) then return end
    if action == "Sync" then ctx.Publish(player); return end
    -- A frozen/dead player may still stop their own training or sprint state.
    if (action == "Train" or action == "Sprint") and a == false then
        if action == "Train" then ctx.Progression:Train(player, false) else ctx.Progression:SetSprint(player, false) end
        return
    end
    local profile = ctx.Data:Get(player)
    if not profile or not ctx.Ready[player] or not ctx.Data:IsWritable(player) then
        ctx.Notify(player, "Your progress is loading or saving is unavailable.", "Warning"); return
    end
    if action ~= "Setting" and not ctx.AntiExploit:ValidateMovement(player) then return end
    local ok, message
    if action == "Buy" then
        if ctx.Validation.Id(a, 64) then ok, message = ctx.Houses:Buy(player, a) end
    elseif action == "Steal" then
        if ctx.Validation.Id(a, 44) then ok, message = ctx.Steal:Attempt(player, a) end
    elseif action == "WildSteal" then
        if ctx.Validation.Id(a, 44) then ok, message = ctx.Steal:AttemptWild(player, a) end
    elseif action == "Sell" then
        if ctx.Validation.Id(a, 44) and (b == nil or type(b) == "boolean") then ok, message = ctx.Houses:Sell(player, a, b) end
    elseif action == "Collect" then
        if ctx.Validation.Id(a, 44) then ok, message = ctx.Houses:Collect(player, a) end
    elseif action == "CollectAll" then ok, message = ctx.Houses:Collect(player)
    elseif action == "Lock" then ok, message = ctx.Progression:Lock(player)
    elseif action == "Bat" then ok, message = ctx.Steal:Bat(player)
    elseif action == "Sprint" and type(a) == "boolean" then ok, message = ctx.Progression:SetSprint(player, a)
    elseif action == "Train" and type(a) == "boolean" then ok, message = ctx.Progression:Train(player, a)
    elseif action == "BaseUpgrade" then ok, message = ctx.Progression:BaseUpgrade(player)
    elseif action == "TreadmillUpgrade" then ok, message = ctx.Progression:TreadmillUpgrade(player)
    elseif action == "SecurityUpgrade" then ok, message = ctx.Progression:SecurityUpgrade(player)
    elseif action == "Daily" then ok, message = ctx.Progression:ClaimDaily(player)
    elseif action == "OpenShop" then ctx.Notify(player, "Open the house shop and upgrade your base here.", "Shop")
    elseif action == "Setting" then
        local settings = { Music = true, SFX = true, ReducedEffects = true }
        if type(a) == "string" and settings[a] and type(b) == "boolean" then profile.Settings[a] = b; ctx.Publish(player) end
    end
    if message then ctx.Notify(player, message, ok and "Success" or "Warning") end
end
return Network
