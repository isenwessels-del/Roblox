local Inventory = {}
Inventory.__index = Inventory
function Inventory.new(ctx) return setmetatable({ Context = ctx }, Inventory) end
function Inventory:Count(player)
    local profile = self.Context.Data:Get(player)
    if not profile then return 0 end
    local count = 0
    for _ in pairs(profile.Inventory) do count += 1 end
    for _ in pairs(profile.House.Furniture) do count += 1 end
    return count
end
function Inventory:ReservedCount(player)
    local state = self.Context.Robbery and self.Context.Robbery:Get(player)
    local count = 0
    if state then for _ in pairs(state.Carry) do count += 1 end end
    return count
end
function Inventory:CanStore(player, itemId)
    return self.Context.Config.Items[itemId] ~= nil
        and self:Count(player) + self:ReservedCount(player) < self.Context.Config.Game.MaxStoredItems
end
function Inventory:Capacity(player)
    local profile = self.Context.Data:Get(player)
    local spec = profile and self.Context.Config.Backpacks[profile.Backpack.Level]
    return spec and spec.Capacity or 0
end
function Inventory:CarryWeight(player)
    local robbery = self.Context.Robbery and self.Context.Robbery:Get(player)
    local total = 0
    if robbery then
        for _, entry in pairs(robbery.Carry) do total += self.Context.Config.Items[entry.ItemId].Weight end
    end
    return total
end
function Inventory:HasCapacity(player, itemId)
    local spec = self.Context.Config.Items[itemId]
    return spec ~= nil and self:CarryWeight(player) + spec.Weight <= self:Capacity(player)
end
function Inventory:AddStoredItem(player, itemId, reason, existing)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    local state = ctx.Robbery and ctx.Robbery:Get(player)
    local handoff = existing and state and state.Carry[existing.UniqueId] == existing
    local room = if handoff then self:Count(player) < ctx.Config.Game.MaxStoredItems else self:CanStore(player, itemId)
    if not profile or not ctx.Data:IsWritable(player) or not room then return nil, "Home storage is full." end
    if existing and (existing.ItemId ~= itemId or typeof(existing.UniqueId) ~= "string") then return nil, "Invalid item handoff." end
    local entry = existing or { UniqueId = ctx.HttpService:GenerateGUID(false), ItemId = itemId, AcquiredAt = os.time() }
    if profile.Inventory[entry.UniqueId] or profile.House.Furniture[entry.UniqueId] then return nil, "Duplicate item rejected." end
    profile.Inventory[entry.UniqueId] = entry
    local collection = profile.Collection[itemId]
    if not collection then collection = { Discovered = true, FirstFound = os.time(), Count = 0 }; profile.Collection[itemId] = collection end
    collection.Count += 1
    if ctx.Analytics then ctx.Analytics:Emit(player, "ItemStored", { ItemId = itemId, Reason = reason }) end
    return entry
end
function Inventory:Upgrade(player, kind)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    if not profile or not ctx.Data:IsWritable(player) then return false, "Data unavailable." end
    if ctx.Robbery:Get(player) then return false, "Finish your robbery before upgrading." end
    local nextLevel, spec
    if kind == "Backpack" then nextLevel = profile.Backpack.Level + 1; spec = ctx.Config.Backpacks[nextLevel]
    elseif kind == "Tool" then nextLevel = profile.Tools.LockpickLevel + 1; spec = ctx.Config.Tools[nextLevel]
    else return false, "Unknown upgrade." end
    if not spec then return false, "Already at maximum level." end
    if profile.Level < spec.RequiredLevel then return false, "Reach level " .. spec.RequiredLevel .. " first." end
    if not ctx.Economy:RemoveCash(player, spec.Cost, "Upgrade" .. kind) then return false, "Not enough cash." end
    if kind == "Backpack" then profile.Backpack.Level = nextLevel else profile.Tools.LockpickLevel = nextLevel end
    if kind == "Backpack" then profile.Statistics.BackpackUpgrades += 1 else profile.Statistics.ToolUpgrades += 1 end
    ctx.Quest:UpdateTutorial(player, "Upgrade")
    ctx.Publish(player)
    return true, kind .. " upgraded!"
end
return Inventory
