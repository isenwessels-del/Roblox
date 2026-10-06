--!nonstrict
local W = require(script.Parent.Widgets)
local Inventory = {}
Inventory.__index = Inventory

function Inventory.new(ctx)
    local self = setmetatable({ Context = ctx }, Inventory)
    ctx.UI:Register("Inventory", function(parent, state) self:RenderInventory(parent, state) end)
    ctx.UI:Register("Shop", function(parent, state) self:RenderShop(parent, state) end)
    ctx.UI:Register("Collection", function(parent, state) self:RenderCollection(parent, state) end)
    return self
end

function Inventory:SortedItems(items)
    local result = {}
    for uid, entry in pairs(items or {}) do table.insert(result, { Uid = uid, Entry = entry }) end
    table.sort(result, function(a, b)
        local ac, bc = self.Context.Config.Items[a.Entry.ItemId], self.Context.Config.Items[b.Entry.ItemId]
        local ar = if ac then self.Context.Config.Rarities[ac.Rarity].Rank else 0
        local br = if bc then self.Context.Config.Rarities[bc.Rarity].Rank else 0
        if ar ~= br then return ar > br end
        return tostring(a.Uid) < tostring(b.Uid)
    end)
    return result
end

function Inventory:Sell(uid, spec)
    local payout = math.floor(spec.Value * self.Context.Config.Economy.SellMultiplier)
    self.Context.UI:Confirm("Sell " .. spec.Name .. "?", spec.Rarity .. " • $" .. W.Number(payout)
        .. "\nThis permanently exchanges the item for cash. Stand at the orange SELL SHOP to complete the sale.", function()
        self.Context:Request("Gameplay", "RequestSell", uid, true)
    end)
end

function Inventory:ItemCard(parent, uid, entry, mode)
    local spec = self.Context.Config.Items[entry.ItemId]
    local card = W.Card(parent, if mode == "Carry" then 76 else 120)
    if not spec then
        W.Text(card, "Archived item", 25, W.Colors.Muted)
        W.Text(card, "This saved item needs a matching catalog entry.", 32, W.Colors.Muted, 13)
        return
    end
    local rarity = self.Context.Config.Rarities[spec.Rarity]
    W.Text(card, spec.Name, 25, W.Color(rarity.Color), 18)
    W.Text(card, spec.Rarity .. "  •  $" .. W.Number(spec.Value) .. "  •  " .. tostring(spec.Weight) .. " weight", 22, W.Colors.Muted, 13)
    if mode == "Carry" then return end
    if mode == "Shop" then
        W.Button(card, "Sell for $" .. W.Number(spec.Value * self.Context.Config.Economy.SellMultiplier), function() self:Sell(uid, spec) end)
    else
        W.Actions(card, "Place at home", function() self.Context.House:Begin(uid) end,
            "Sell at shop", function() self:Sell(uid, spec) end)
    end
end

function Inventory:RenderInventory(parent, state)
    if not state or not state.Profile then W.Text(parent, "Loading inventory...", 45); return end
    local carry = state.Runtime.Carry or {}
    W.Text(parent, "CARRIED LOOT • UNSECURED", 30, W.Colors.Orange, 17)
    W.Text(parent, "Police can confiscate your haul. Return to your HOME beacon before selling or displaying it.", 46, W.Colors.Muted, 14)
    if #carry == 0 then W.Text(parent, "Your backpack is empty. Enter a house and hold the STEAL prompt near an item.", 52, W.Colors.Muted) end
    for _, entry in ipairs(carry) do self:ItemCard(parent, entry.UniqueId, entry, "Carry") end
    if #carry > 0 then W.Button(parent, "Secure haul (stand at HOME)", function() self.Context:Request("Gameplay", "RequestEscape") end) end
    local stored = self:SortedItems(state.Profile.Inventory)
    W.Text(parent, "HOME STORAGE • " .. #stored .. " ITEMS", 34, W.Colors.Teal, 17)
    if #stored == 0 then W.Text(parent, "Bring a successful haul home to start your collection.", 48, W.Colors.Muted) end
    for _, item in ipairs(stored) do self:ItemCard(parent, item.Uid, item.Entry, "Storage") end
end

function Inventory:RenderShop(parent, state)
    if not state or not state.Profile then return end
    W.Text(parent, "SELL SHOP", 32, W.Colors.Orange, 21)
    W.Text(parent, "Stand at the orange shop in the town square to sell secured items. Displayed items must first be picked up in House. Carrying loot? Secure it at home first.", 74, W.Colors.Muted, 14)
    local stored = self:SortedItems(state.Profile.Inventory)
    if #stored == 0 then W.Text(parent, "No secured items to sell yet.", 44, W.Colors.Muted) end
    for _, item in ipairs(stored) do self:ItemCard(parent, item.Uid, item.Entry, "Shop") end
    W.Text(parent, "UPGRADES", 32, W.Colors.Teal, 19)
    local backpack = state.Profile.Backpack.Level
    local tool = state.Profile.Tools.LockpickLevel
    for _, row in ipairs({ { "Backpack", self.Context.Config.Backpacks, backpack }, { "Tool", self.Context.Config.Tools, tool } }) do
        local nextTier = row[2][row[3] + 1]
        local card = W.Card(parent, 122)
        W.Text(card, row[1] .. "  •  Level " .. row[3], 25, W.Colors.Text, 18)
        if nextTier then
            local detail = if row[1] == "Backpack" then tostring(nextTier.Capacity) .. " capacity" else "Counters stronger security"
            W.Text(card, nextTier.Name .. "  •  " .. detail .. "  •  Requires level " .. nextTier.RequiredLevel, 25, W.Colors.Muted, 13)
            W.Button(card, "Upgrade • $" .. W.Number(nextTier.Cost), function() self.Context:Request("Gameplay", "RequestUpgrade", row[1]) end)
        else W.Text(card, "Maximum level reached.", 45, W.Colors.Teal) end
    end
end

function Inventory:RenderCollection(parent, state)
    if not state or not state.Profile then return end
    local profile = state.Profile
    local ids = {}
    local found, total = 0, 0
    for id, spec in pairs(self.Context.Config.Items) do
        total += 1
        if profile.Collection[id] then found += 1 end
        if spec.Rarity ~= "Secret" or profile.Collection[id] then table.insert(ids, id) end
    end
    W.Text(parent, "COLLECTION BOOK  •  " .. found .. " / " .. total, 33, W.Colors.Teal, 20)
    W.Text(parent, "Discover items by stealing and escaping. Secret treasures stay hidden until discovered.", 45, W.Colors.Muted, 14)
    table.sort(ids, function(a, b)
        local sa, sb = self.Context.Config.Items[a], self.Context.Config.Items[b]
        local ra, rb = self.Context.Config.Rarities[sa.Rarity].Rank, self.Context.Config.Rarities[sb.Rarity].Rank
        if ra ~= rb then return ra > rb end
        return sa.Name < sb.Name
    end)
    for _, id in ipairs(ids) do
        local spec = self.Context.Config.Items[id]
        local discovered = profile.Collection[id]
        local card = W.Card(parent, 75)
        W.Text(card, if discovered then spec.Name else "??? • " .. spec.Rarity, 25,
            if discovered then W.Color(self.Context.Config.Rarities[spec.Rarity].Color) else W.Colors.Muted, 18)
        W.Text(card, if discovered then spec.Rarity .. " • " .. spec.Category .. " • $" .. W.Number(spec.Value) else "Undiscovered • Explore higher districts", 25, W.Colors.Muted, 13)
    end
end

return Inventory
