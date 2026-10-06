-- One allowlisted router is shared by remotes and server ProximityPrompt handlers.
local Network = {}
Network.__index = Network
local groups = {
    Gameplay = { RequestSteal = "Steal", RequestSell = "Sell", RequestPlaceItem = "Place", RequestPickupItem = "Pickup",
        RequestUpgrade = "Upgrade", RequestEscape = "Escape", RequestEnterHouse = "EnterHouse", RequestDisableSecurity = "DisableSecurity", RequestSprint = "Sprint" },
    House = { RequestHouseUpgrade = "HouseUpgrade", RequestHouseCustomization = "Theme", RequestSecurityUpgrade = "SecurityUpgrade", RequestHouseVisit = "Visit" },
    Quests = { RequestQuestClaim = "QuestClaim", RequestDailyClaim = "DailyClaim" },
    Settings = { RequestSetting = "Setting" },
    UI = { RequestSync = "Sync", Snapshot = false, Notification = false, RareItemFound = false, AlarmTriggered = false, HeatChanged = false, Announcement = false },
}
function Network.new(ctx)
    local self = setmetatable({ Context = ctx, Remotes = {} }, Network)
    local parent = Instance.new("Folder")
    parent.Name, parent.Parent = "Remotes", ctx.ReplicatedStorage
    for group, entries in pairs(groups) do
        local folder = Instance.new("Folder")
        folder.Name, folder.Parent = group, parent
        self.Remotes[group] = {}
        for name, action in pairs(entries) do
            local event = Instance.new("RemoteEvent")
            event.Name, event.Parent = name, folder
            self.Remotes[group][name] = event
            if action then
                event.OnServerEvent:Connect(function(player, ...) self:Request(player, action, ...) end)
            end
        end
    end
    return self
end
function Network:Request(player, action, a, b, c, d)
    local ctx = self.Context
    if ctx.Closing or not ctx.AntiExploit:Rate(player, action) then return end
    local profile = ctx.Data:Get(player)
    if action == "Sync" then ctx.Publish(player); return end
    if not profile or not ctx.Data:IsWritable(player) then ctx.Notify(player, "Your profile is loading or saving is unavailable.", "Warning"); return end
    if action ~= "Setting" and action ~= "QuestClaim" and action ~= "DailyClaim" and not ctx.AntiExploit:ValidateMovement(player) then return end
    local ok, message
    if action == "Steal" then ok, message = ctx.Robbery:Steal(player, a)
    elseif action == "EnterHouse" then ok, message = ctx.Robbery:Enter(player, a)
    elseif action == "Escape" then ok, message = ctx.Robbery:Escape(player)
    elseif action == "Sell" then ok, message = ctx.Economy:Sell(player, a, b)
    elseif action == "Place" then ok, message = ctx.House:Place(player, a, b, c, d)
    elseif action == "Pickup" then ok, message = ctx.House:Pickup(player, a)
    elseif action == "Upgrade" then ok, message = ctx.Inventory:Upgrade(player, a)
    elseif action == "HouseUpgrade" then ok, message = ctx.House:Upgrade(player, false)
    elseif action == "SecurityUpgrade" then ok, message = ctx.House:Upgrade(player, true)
    elseif action == "Theme" then ok, message = ctx.House:Customize(player, a)
    elseif action == "DisableSecurity" then ok, message = ctx.Security:Disable(player, a)
    elseif action == "QuestClaim" then ok, message = ctx.Quest:Claim(player, a)
    elseif action == "DailyClaim" then ok, message = ctx.Quest:ClaimDaily(player)
    elseif action == "InspectSecurity" then
        if a == player.UserId and ctx.House:AtHome(player) then ctx.Notify(player, "Your house is protected. Upgrade security in the House menu.", "House") end
    elseif action == "OpenShop" then
        if ctx.AntiExploit:Near(player, ctx.World.ShopPosition, ctx.Config.Game.ShopRadius) then
            ctx.Remotes.UI.Notification:FireClient(player, "Open the Shop or Inventory tab to sell stored items.", "Shop")
        end
    elseif action == "Sprint" then
        if typeof(a) == "boolean" then
            local _, humanoid = ctx.AntiExploit:Character(player)
            if humanoid then humanoid.WalkSpeed = if a then ctx.Config.Game.SprintSpeed else ctx.Config.Game.MoveSpeed end
        end
    elseif action == "Setting" then
        local allowed = { Music = true, SFX = true, Notifications = true, ReducedEffects = true, CameraShake = true }
        if typeof(a) == "string" and allowed[a] and typeof(b) == "boolean" then profile.Settings[a] = b; ctx.Publish(player)
        elseif a == "UIScale" and typeof(b) == "number" and b == b and b >= 0.8 and b <= 1.3 then profile.Settings.UIScale = b; ctx.Publish(player) end
    elseif action == "Visit" then
        if typeof(a) == "number" and a % 1 == 0 then
            for _, target in ipairs(ctx.Players:GetPlayers()) do
                if target.UserId == a then
                    local plot = ctx.World:GetPlot(target)
                    if plot and ctx.AntiExploit:Near(player, plot.Origin, 40) then
                        ok, message = true, target.DisplayName .. "'s house value: $" .. ctx.House:Value(target)
                    end
                end
            end
        end
    end
    if message then ctx.Notify(player, message, if ok then "Success" else "Warning") end
end
return Network
