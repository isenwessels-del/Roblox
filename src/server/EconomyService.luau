-- Currency mutations are synchronous and only operate on an acquired profile.
local Economy = {}
Economy.__index = Economy
function Economy.new(ctx) return setmetatable({ Context = ctx }, Economy) end
function Economy:CanAfford(player, amount)
    local profile = self.Context.Data:Get(player)
    return profile ~= nil and typeof(amount) == "number" and amount == amount
        and amount >= 0 and amount % 1 == 0 and profile.Cash >= amount
end
function Economy:AddCash(player, amount, reason)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    local limit = ctx.Config.Economy.MaxCash or 1e15
    if not profile or not ctx.Data:IsWritable(player) or typeof(amount) ~= "number"
        or amount ~= amount or amount < 0 or amount % 1 ~= 0 or amount > limit then return false end
    if profile.Cash + amount > limit then return false end
    profile.Cash += amount
    profile.Statistics.TotalCashEarned = math.min(limit, profile.Statistics.TotalCashEarned + amount)
    if ctx.Analytics then ctx.Analytics:Emit(player, "CashSource", { Amount = amount, Reason = reason }) end
    if ctx.Quest then ctx.Quest:Progress(player, "EarnCash", amount) end
    return true
end
function Economy:RemoveCash(player, amount, reason)
    local ctx = self.Context
    if not ctx.Data:IsWritable(player) or not self:CanAfford(player, amount) then return false end
    local profile = ctx.Data:Get(player)
    profile.Cash -= amount
    profile.Statistics.TotalCashSpent = math.min(ctx.Config.Economy.MaxCash or 1e15, profile.Statistics.TotalCashSpent + amount)
    if ctx.Analytics then ctx.Analytics:Emit(player, "CashSink", { Amount = amount, Reason = reason }) end
    return true
end
function Economy:Sell(player, uid, confirmed)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    if not profile or not ctx.Data:IsWritable(player) or not ctx.AntiExploit:Near(player, ctx.World.ShopPosition, ctx.Config.Game.ShopRadius) then
        return false, "Visit the furniture shop in the town square to sell."
    end
    if ctx.Robbery:Get(player) then return false, "Bring your stolen bag home before selling." end
    if typeof(uid) ~= "string" or #uid > 80 then return false, "Invalid item." end
    local entry = profile.Inventory[uid]
    local item = entry and ctx.Config.Items[entry.ItemId]
    if not item or item.Sellable == false then return false, "This stored item cannot be sold." end
    if ctx.Config.Rarities[item.Rarity].Rank >= 3 and confirmed ~= true then return false, "Confirm selling this valuable item." end
    local multiplier = ctx.Events and ctx.Events:Multiplier("Cash") or 1
    local amount = math.floor(item.Value * (ctx.Config.Economy.SellMultiplier or 1) * multiplier)
    if profile.Cash + amount > (ctx.Config.Economy.MaxCash or 1e15) then return false, "Cash limit reached." end
    -- All prerequisites are checked before either side of this transaction changes.
    profile.Inventory[uid] = nil
    if not self:AddCash(player, amount, "SellItem") then profile.Inventory[uid] = entry; return false, "Sale unavailable." end
    profile.Statistics.ItemsSold += 1
    ctx.Quest:Progress(player, "SellItems", 1)
    ctx.Publish(player)
    return true, "Sold " .. item.Name .. " for $" .. amount .. "."
end
return Economy
