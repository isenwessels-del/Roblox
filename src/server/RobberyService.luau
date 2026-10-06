local Robbery = {}
Robbery.__index = Robbery
function Robbery.new(ctx) return setmetatable({ Context = ctx, States = {}, Attempts = {} }, Robbery) end
function Robbery:Get(player) return self.States[player] end
function Robbery:Enter(player, id)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    local house = typeof(id) == "string" and #id <= 80 and ctx.World:GetNPC(id)
    if not profile or not ctx.Data:IsWritable(player) or not house then return false, "Unknown robbery house." end
    if not ctx.AntiExploit:Near(player, house.EntryPosition, 18) then return false, "Stand at the house entrance." end
    if self.States[player] then return false, "Bring your current bag home first." end
    local area = ctx.Config.Game.Areas[house.Area]
    if profile.Level < area.RequiredLevel then return false, "This district requires level " .. area.RequiredLevel .. "." end
    local requiredTool = math.min(math.max(1, math.floor(house.Area / 2)), #ctx.Config.Tools)
    if profile.Tools.LockpickLevel < requiredTool then return false, "Upgrade your lockpick tool to level " .. requiredTool .. "." end
    self.States[player] = { Active = true, TargetHouse = house.Id, TargetName = area.Name,
        Started = os.clock(), Carry = {}, ItemsStolen = 0, Alarm = false }
    ctx.Quest:Progress(player, "VisitHouses", 1)
    ctx.Publish(player)
    return true, "Robbery started. Steal furniture, then return home to secure it."
end
function Robbery:Steal(player, uid)
    local ctx = self.Context
    local state = self.States[player]
    if typeof(uid) ~= "string" or #uid > 80 or not state or self.Attempts[player] then return false, "Enter a house before stealing." end
    local record = ctx.Items:Get(uid)
    if not record or record.HouseId ~= state.TargetHouse or record.Busy then return false, "This loot is unavailable." end
    if not ctx.Data:IsWritable(player) or not ctx.AntiExploit:CanInteract(player, record, ctx.Config.Game.InteractionDistance) then return false, "Move closer to the loot." end
    local spec = ctx.Config.Items[record.ItemId]
    if not ctx.Inventory:HasCapacity(player, record.ItemId) then return false, "Backpack full! Return home or upgrade it." end
    if ctx.Inventory:Count(player) + state.ItemsStolen >= ctx.Config.Game.MaxStoredItems then return false, "Home storage full. Sell some stored items first." end
    local attempt = { Record = record, State = state, Started = os.clock() }
    self.Attempts[player], record.Busy = attempt, attempt
    ctx.Notify(player, "Stealing " .. spec.Name .. "… stay nearby.", "Info")
    task.spawn(function()
        local function valid()
            return self.States[player] == state and self.Attempts[player] == attempt and ctx.Items:Get(uid) == record
                and ctx.Data:IsWritable(player) and ctx.AntiExploit:CanInteract(player, record, ctx.Config.Game.InteractionDistance)
                and ctx.Inventory:HasCapacity(player, record.ItemId)
                and ctx.Inventory:Count(player) + state.ItemsStolen < ctx.Config.Game.MaxStoredItems
        end
        while valid() and os.clock() - attempt.Started < ctx.Config.Game.StealSeconds do task.wait(0.1) end
        local success = valid() and os.clock() - attempt.Started >= ctx.Config.Game.StealSeconds
        if self.Attempts[player] == attempt then self.Attempts[player] = nil end
        if record.Busy == attempt then record.Busy = nil end
        if not success then ctx.Notify(player, "Theft cancelled.", "Warning"); return end
        -- No yield occurs between the final validation and consuming the unique record.
        if not ctx.Items:Consume(record) then return end
        state.Carry[uid] = { UniqueId = uid, ItemId = record.ItemId, AcquiredAt = os.time() }
        state.ItemsStolen += 1
        local profile = ctx.Data:Get(player)
        profile.Statistics.ItemsStolen += 1
        local rank = ctx.Config.Rarities[spec.Rarity].Rank
        if rank >= 3 then profile.Statistics.RareItemsFound += 1 end
        if rank == 5 then profile.Statistics.LegendaryItemsFound += 1 end
        if rank == 6 then profile.Statistics.MythicItemsFound += 1 end
        if rank == 7 then profile.Statistics.SecretItemsFound += 1 end
        ctx.Heat:Add(player, ctx.Config.Rarities[spec.Rarity].Heat or 15)
        ctx.Quest:Progress(player, "StealItems", 1)
        ctx.Quest:Progress(player, "FindRarity", 1, spec.Rarity)
        ctx.Quest:AwardXP(player, ctx.Config.Economy.XPPerSteal * rank)
        ctx.Quest:UpdateTutorial(player, "Steal")
        if rank >= 3 then ctx.Remotes.UI.RareItemFound:FireClient(player, { ItemId = spec.Id, Name = spec.Name, Rarity = spec.Rarity, Value = spec.Value }) end
        if rank >= 6 then ctx.Remotes.UI.Announcement:FireAllClients(player.DisplayName .. " found a " .. spec.Rarity .. " " .. spec.Name .. "!") end
        ctx.Publish(player)
        ctx.Notify(player, "Loot in backpack. Escape to your home pad to keep it!", "Success")
    end)
    return true
end
function Robbery:Escape(player)
    local ctx = self.Context
    local state = self.States[player]
    local plot = ctx.World:GetPlot(player)
    if not state or not plot or not ctx.Data:IsWritable(player)
        or not ctx.AntiExploit:Near(player, plot.HomePad.Position, ctx.Config.Game.InteractionDistance) then return false, "Reach your own home pad to escape." end
    if self.Attempts[player] then return false, "Finish or cancel your current theft first." end
    local count = 0
    for _ in pairs(state.Carry) do count += 1 end
    if count == 0 then
        self.States[player] = nil
        ctx.Police:Remove(player)
        ctx.Publish(player)
        return true, "Empty robbery ended. Try another house."
    end
    if ctx.Inventory:Count(player) + count > ctx.Config.Game.MaxStoredItems then return false, "Home storage full." end
    local profile = ctx.Data:Get(player)
    for uid in pairs(state.Carry) do
        if profile.Inventory[uid] or profile.House.Furniture[uid] then return false, "Duplicate item detected. Contact the developer." end
    end
    for _, entry in pairs(state.Carry) do
        assert(ctx.Inventory:AddStoredItem(player, entry.ItemId, "RobberyEscape", entry), "Validated escape failed")
    end
    self.States[player] = nil
    ctx.Security:Remove(player)
    ctx.Police:Remove(player)
    ctx.Heat:Add(player, -50)
    profile.Statistics.SuccessfulRobberies += 1
    profile.Statistics.HousesRobbed += 1
    ctx.Quest:Progress(player, "CompleteRobbery", 1)
    ctx.Quest:AwardXP(player, ctx.Config.Economy.XPPerEscape)
    ctx.Quest:UpdateTutorial(player, "ReturnHome")
    ctx.Analytics:Emit(player, "RobberyEscape", { Count = count, Area = state.TargetHouse })
    ctx.Publish(player)
    return true, "ESCAPED! " .. count .. " items secured. Display them or visit the shop to sell."
end
function Robbery:Fail(player, reason)
    local ctx = self.Context
    local state = self.States[player]
    if not state then return end
    local attempt = self.Attempts[player]
    if attempt and attempt.Record.Busy == attempt then attempt.Record.Busy = nil end
    self.Attempts[player] = nil
    local protected = 0
    if ctx.Data:IsWritable(player) then
        for _, entry in pairs(state.Carry) do
            if ctx.Config.Rarities[ctx.Config.Items[entry.ItemId].Rarity].Rank >= 3 then
                if ctx.Inventory:AddStoredItem(player, entry.ItemId, "RareLootProtection", entry) then protected += 1 end
            end
        end
        ctx.Data:Get(player).Statistics.FailedRobberies += 1
    end
    self.States[player] = nil
    ctx.Security:Remove(player)
    ctx.Police:Remove(player)
    ctx.Heat:Add(player, -60)
    ctx.Notify(player, reason .. ". Unsecured common loot lost; " .. protected .. " rare items protected.", "Warning")
    ctx.Publish(player)
end
function Robbery:Tick()
    local ctx = self.Context
    for player, state in pairs(self.States) do
        local root = ctx.AntiExploit:Character(player)
        if not root then self:Fail(player, "Robbery ended after death")
        elseif not ctx.Data:IsWritable(player) then self:Fail(player, "Profile saving is unavailable")
        elseif os.clock() - state.Started > ctx.Config.Game.MaxRobberySeconds then self:Fail(player, "Robbery timed out")
        else
            local house = ctx.World:GetNPC(state.TargetHouse)
            if house and ctx.World:GetNPCAt(root.Position) == house and not state.Alarm
                and os.clock() - state.Started >= ctx.Security:DetectionDelay(player, house)
                and not ctx.Security:IsDisabled(player, house) then
                state.Alarm = true
                local spec = ctx.Config.Security[ctx.Security:Level(house)]
                ctx.Heat:Add(player, spec.HeatBonus or 35)
                ctx.Remotes.UI.AlarmTriggered:FireClient(player, "ALARM! Police have been alerted. RUN!")
                ctx.Notify(player, "ALARM TRIGGERED — RUN HOME!", "Alarm")
                ctx.Publish(player)
            end
        end
    end
end
function Robbery:Remove(player)
    self:Fail(player, "Player left during robbery")
    self.States[player], self.Attempts[player] = nil, nil
end
return Robbery
