local House = {}
House.__index = House
local function finite(value) return typeof(value) == "number" and value == value and math.abs(value) < 1e6 end
local function footprint(spec, rotation)
    local x, z = spec.Size.X, spec.Size.Z
    if rotation % 180 ~= 0 then return z, x end
    return x, z
end
function House.new(ctx) return setmetatable({ Context = ctx }, House) end
function House:Value(player)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    if not profile then return 0 end
    local value = ctx.Config.Houses[profile.House.Tier].Value
    local count = 0
    for _, entry in pairs(profile.House.Furniture) do
        local item = ctx.Config.Items[entry.ItemId]
        if item then
            value += math.floor(item.Value * (1 + (ctx.Config.Rarities[item.Rarity].Rank - 1) * 0.05))
            count += 1
        end
    end
    value += math.floor(count / 4) * 100
    profile.House.HouseValue = value
    return value
end
function House:AtHome(player)
    local plot = self.Context.World:GetPlot(player)
    local root = self.Context.AntiExploit:Character(player)
    return plot ~= nil and root ~= nil and self.Context.AntiExploit:ValidateMovement(player)
        and self.Context.World:IsInHome(player, root.Position)
end
function House:Render(player)
    local ctx = self.Context
    self:Value(player)
    local ok, err = pcall(function() ctx.World:RenderHome(player, ctx.Data:Get(player)) end)
    if not ok then warn("[HouseRender]", player.UserId, err) end
    return ok
end
function House:Place(player, uid, x, z, rotation)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    if not profile or not ctx.Data:IsWritable(player) or not self:AtHome(player) then return false, "Return to your own house to place furniture." end
    if ctx.Robbery:Get(player) then return false, "Secure your robbery bag first." end
    if typeof(uid) ~= "string" or #uid > 80 or not finite(x) or not finite(z)
        or not finite(rotation) or rotation % 90 ~= 0 or rotation < 0 or rotation > 270 then return false, "Invalid placement." end
    local entry = profile.Inventory[uid]
    local item = entry and ctx.Config.Items[entry.ItemId]
    if not item or item.Displayable == false then return false, "You don't own this stored furniture." end
    local tier = ctx.Config.Houses[profile.House.Tier]
    local width, depth = footprint(item, rotation)
    -- Snap to the server's grid, then check the complete rotated footprint.
    local grid = ctx.Config.Game.GridSize
    x, z = math.round(x / grid) * grid, math.round(z / grid) * grid
    if math.abs(x) + width / 2 > tier.Width / 2 - 2 or math.abs(z) + depth / 2 > tier.Depth / 2 - 2 then
        return false, "Furniture must fit entirely inside your house."
    end
    -- Keep a walkable doorway corridor in every tier.
    if math.abs(x) < 4 + width / 2 and z < -tier.Depth / 2 + 9 + depth / 2 then return false, "Keep the doorway clear." end
    local count = 0
    for _, placed in pairs(profile.House.Furniture) do
        count += 1
        local other = ctx.Config.Items[placed.ItemId]
        if other then
            local w, d = footprint(other, placed.Rotation)
            if math.abs(x - placed.X) < (width + w) / 2 + 0.2 and math.abs(z - placed.Z) < (depth + d) / 2 + 0.2 then
                return false, "Furniture overlaps another item."
            end
        end
    end
    if count >= tier.MaxFurniture then return false, "Upgrade your house for more display space." end
    profile.Inventory[uid] = nil
    profile.House.Furniture[uid] = { UniqueId = uid, ItemId = entry.ItemId, AcquiredAt = entry.AcquiredAt, X = x, Z = z, Rotation = rotation }
    profile.Statistics.ItemsPlaced += 1
    self:Render(player)
    ctx.Quest:Progress(player, "PlaceItem", 1)
    ctx.Publish(player)
    return true, "Placed " .. item.Name .. ". House value increased!"
end
function House:Pickup(player, uid)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    if not profile or not ctx.Data:IsWritable(player) or not self:AtHome(player) then return false, "Return home to pick up furniture." end
    if ctx.Robbery:Get(player) then return false, "Finish your robbery first." end
    if typeof(uid) ~= "string" or #uid > 80 then return false, "Invalid item." end
    local entry = profile.House.Furniture[uid]
    if not entry or profile.Inventory[uid] then return false, "This item isn't placed in your house." end
    profile.House.Furniture[uid] = nil
    profile.Inventory[uid] = { UniqueId = uid, ItemId = entry.ItemId, AcquiredAt = entry.AcquiredAt }
    self:Render(player)
    ctx.Publish(player)
    return true, "Furniture returned to storage."
end
function House:Upgrade(player, security)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    if not profile or not ctx.Data:IsWritable(player) or not self:AtHome(player) then return false, "Upgrade while at your own house." end
    if ctx.Robbery:Get(player) then return false, "Finish your robbery first." end
    local level = (if security then profile.House.SecurityLevel else profile.House.Tier) + 1
    local spec = (if security then ctx.Config.Security else ctx.Config.Houses)[level]
    if not spec then return false, "Already fully upgraded." end
    if profile.Level < spec.RequiredLevel then return false, "Reach level " .. spec.RequiredLevel .. " first." end
    if not ctx.Economy:RemoveCash(player, spec.Cost, if security then "SecurityUpgrade" else "HouseUpgrade") then return false, "Not enough cash." end
    if security then profile.House.SecurityLevel = level else profile.House.Tier = level end
    if security then profile.Statistics.SecurityUpgrades += 1 else profile.Statistics.HouseUpgrades += 1 end
    self:Render(player)
    ctx.Quest:Progress(player, if security then "UpgradeSecurity" else "UpgradeHouse", 1)
    ctx.Quest:AwardXP(player, 25 * level)
    ctx.Quest:UpdateTutorial(player, "Upgrade")
    ctx.Publish(player)
    return true, spec.Name .. " unlocked!"
end
function House:Customize(player, theme)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    if not profile or not ctx.Data:IsWritable(player) or not self:AtHome(player) then return false, "Customize at your own house." end
    if typeof(theme) ~= "string" then return false, "Unknown theme." end
    local spec = ctx.Config.Game.Themes[theme]
    if not spec then return false, "Unknown theme." end
    if not profile.OwnedThemes[theme] then
        if not ctx.Economy:RemoveCash(player, spec.Cost, "HouseTheme") then return false, "Not enough cash for this cosmetic." end
        profile.OwnedThemes[theme] = true
    end
    profile.House.Theme = theme
    self:Render(player)
    ctx.Publish(player)
    return true, theme .. " theme applied."
end
return House
