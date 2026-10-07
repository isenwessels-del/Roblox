-- Economy intents are saved before touching the independent ownership ledger.
-- A retry/rejoin completes the same UID operation instead of minting another house.
local Houses = {}
Houses.__index = Houses

function Houses.new(ctx)
    return setmetatable({ Context = ctx, Records = {}, Busy = {}, Reserved = {},
        RecoverAt = {}, Recovering = {} }, Houses)
end
function Houses:Capacity(player)
    local profile = self.Context.Data:Get(player)
    return profile and self.Context.Config.Bases[profile.BaseLevel].Slots or 0
end
function Houses:List(player)
    local result = {}
    for _, record in pairs(self.Records[player] or {}) do table.insert(result, record) end
    table.sort(result, function(a, b) return a.Slot < b.Slot end)
    return result
end
function Houses:FreeSlot(player)
    local occupied = {}
    for _, record in pairs(self.Records[player] or {}) do occupied[record.Slot] = true end
    for slot in pairs(self.Reserved[player] or {}) do occupied[slot] = true end
    for slot = 1, self:Capacity(player) do if not occupied[slot] then return slot end end
end
function Houses:Rate(record)
    local config = self.Context.Config
    return config.HouseById[record.DefinitionId].Income
        * config.VariantById[record.Variant].Multiplier * config.SizeById[record.Size].IncomeMultiplier
end
function Houses:_ready(player)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    return profile and not ctx.Closing and ctx.Data:IsWritable(player) and not profile.Pending
        and not self.Busy[player] and not ctx.Steal:SourceHousesBusy(player)
end
function Houses:_bank(profile, amount)
    profile.Bank = math.min(self.Context.Config.Game.IncomeCap, profile.Bank + amount)
end
function Houses:_render(player, record)
    local ctx = self.Context
    if ctx.World:GetPlot(player) and not ctx.Steal:IsHeld(record.Id) then
        ctx.World:RenderHouse(player, record)
    end
end
function Houses:_record(player, intent)
    return { Id = intent.Id, DefinitionId = intent.DefinitionId, Variant = intent.Variant,
        Size = intent.Size, OwnerId = player.UserId, Slot = intent.Slot, Revision = 1,
        CreatedAt = intent.CreatedAt, OwnedSince = intent.CreatedAt,
        BuildReadyAt = intent.CreatedAt + (intent.Kind == "Starter" and 0 or self.Context.Config.Game.ConstructionSeconds),
        OperationId = intent.OperationId }
end
function Houses:_resume(player)
    local ctx, profile = self.Context, self.Context.Data:Get(player)
    local intent = profile and profile.Pending
    if not intent then return nil, "No pending transaction." end
    -- This save acknowledges the debit/intent even after an ambiguous previous save.
    local saved, saveError = ctx.Data:Save(player)
    if not saved then return nil, saveError or "Saving unavailable; your purchase will recover on rejoin." end
    local record, err
    if intent.Kind == "Sell" then
        record, err = ctx.Ownership:Remove(intent.Id, player.UserId, intent.ExpectedRevision, intent.OperationId)
    else record, err = ctx.Ownership:Create(self:_record(player, intent)) end
    if not record then
        local canonical, readError = ctx.Ownership:Get(intent.Id)
        if readError then return nil, readError end
        if canonical and intent.Kind ~= "Sell" and canonical.CreatedAt == intent.CreatedAt
            and canonical.DefinitionId == intent.DefinitionId and canonical.Variant == intent.Variant
            and canonical.Size == intent.Size then
            -- The creation completed, but the house may since have been stolen.
            record = canonical
        elseif canonical and intent.Kind == "Sell" and canonical.OwnerId ~= player.UserId
            and not (canonical.OwnerId == 0 and canonical.OperationId == intent.OperationId) then
            -- A conflicted sale cannot credit money for somebody else's house.
            profile.Pending = nil
            ctx.Data:Save(player)
            return nil, "That house changed owner; no sale was paid."
        else return nil, err or "The ownership store is unavailable; transaction retained." end
    end
    if intent.Kind == "Sell" then
        if record.OwnerId ~= 0 or record.OperationId ~= intent.OperationId then return nil, "Sale conflict." end
        local credited = math.min(intent.Price, ctx.Config.Game.MaxCash - profile.Cash)
        profile.Cash += credited
        self:_bank(profile, intent.Price - credited)
        profile.Statistics.TotalEarned = math.min(1e15, profile.Statistics.TotalEarned + credited)
        self:_bank(profile, profile.Income[intent.Id] or 0)
        profile.Income[intent.Id] = nil
        (self.Records[player] or {})[intent.Id] = nil
        ctx.World:RemoveHouse(player, intent.Id)
    else
        profile.HasStarter = true
        profile.Collection[intent.DefinitionId] = true
        if record.OwnerId == player.UserId and ctx.Data:Get(player) == profile and self.Records[player] then
            self.Records[player][record.Id] = record
            profile.Income[record.Id] = profile.Income[record.Id] or 0
            self:_render(player, record)
        end
        if intent.Kind == "Buy" then
            profile.Statistics.Bought += 1
            profile.Statistics.TotalSpent = math.min(1e15, profile.Statistics.TotalSpent + intent.Price)
        elseif intent.Kind == "Wild" then profile.Statistics.Stolen += 1 end
    end
    profile.Pending = nil
    -- Failure here is recoverable: the saved intent and canonical operation remain.
    local finalized = ctx.Data:Save(player)
    if not finalized then ctx.Notify(player, "House transaction committed. Saving will retry automatically.", "Warning") end
    if intent.Kind == "Wild" and record.OwnerId == player.UserId then
        local definition = ctx.Config.HouseById[record.DefinitionId]
        local rare = ctx.Config.Rarities[definition.Rarity].Rank >= 4 or record.Variant ~= "Normal"
        ctx.Notify(player, definition.Name .. " secured: " .. record.Variant .. " • " .. record.Size,
            rare and "Rare" or "Stolen")
    end
    ctx.Publish(player)
    return record
end
function Houses:_intent(player, kind, definitionId, variant, size, slot, id, token)
    local ctx = self.Context
    return { Kind = kind, Id = id or ctx.HttpService:GenerateGUID(false),
        DefinitionId = definitionId, Variant = variant, Size = size, Slot = slot,
        Price = 0, OperationId = token or ctx.HttpService:GenerateGUID(false), CreatedAt = ctx.Clock() }
end
function Houses:Attach(player)
    local ctx, profile = self.Context, self.Context.Data:Get(player)
    self.Records[player], self.Reserved[player] = {}, {}
    if profile.Pending then
        self.Busy[player] = profile.Pending.OperationId
        local _, err = self:_resume(player)
        self.Busy[player] = nil
        if profile.Pending then return false, err or "Unable to recover your transaction." end
    end
    if ctx.Data:Get(player) ~= profile or not ctx.World:GetPlot(player) then return false, "Profile released." end
    local records, err = ctx.Ownership:List(player.UserId)
    if not records then return false, err end
    if ctx.Data:Get(player) ~= profile or not ctx.World:GetPlot(player) then return false, "Profile released." end
    local slots = {}
    for _, record in ipairs(records) do
        if record.Slot > self:Capacity(player) or slots[record.Slot] then
            return false, "Saved houses contain overlapping or unavailable slots. Contact the developer."
        end
        slots[record.Slot] = true
        self.Records[player][record.Id] = record
        profile.Collection[record.DefinitionId] = true
    end
    -- Pending rent stays with its earner even if the house changed owner during a crash.
    for uid, amount in pairs(profile.Income) do
        if not self.Records[player][uid] then self:_bank(profile, amount); profile.Income[uid] = nil end
    end
    local now = ctx.Clock()
    local offline = 0
    for _, record in ipairs(records) do
        local since = math.max(profile.LastSeen, record.OwnedSince, record.BuildReadyAt)
        local seconds = math.clamp(now - since, 0, ctx.Config.Game.OfflineMaxSeconds)
        offline += self:Rate(record) * seconds * ctx.Config.Game.OfflineMultiplier
        profile.Income[record.Id] = profile.Income[record.Id] or 0
        self:_render(player, record)
    end
    self:_bank(profile, offline)
    profile.LastSeen = now
    if not profile.HasStarter then
        if #records > 0 then profile.HasStarter = true
        else
            local intent = self:_intent(player, "Starter", ctx.Config.Houses[1].Id, "Normal", "Normal", 1)
            profile.Pending, self.Busy[player] = intent, intent.OperationId
            local _, starterError = self:_resume(player)
            self.Busy[player] = nil
            if profile.Pending then return false, starterError end
        end
    end
    ctx.World:UpdateSlots(player, self:Capacity(player))
    if offline >= 1 then ctx.Notify(player, "$" .. math.floor(offline) .. " offline rent is waiting at your base.", "Success") end
    return true
end
function Houses:Buy(player, definitionId)
    local ctx, profile = self.Context, self.Context.Data:Get(player)
    local definition = type(definitionId) == "string" and ctx.Config.HouseById[definitionId]
    if not definition or not self:_ready(player) then return false, "Finish your current action first." end
    if not ctx.World:AtHome(player) then return false, "Buy houses from your own base." end
    local slot = self:FreeSlot(player)
    if not slot then return false, "Upgrade your base or free a pad." end
    if profile.Cash < definition.Price then return false, "You need more cash." end
    local intent = self:_intent(player, "Buy", definitionId, "Normal", "Normal", slot)
    intent.Price = definition.Price
    profile.Cash -= definition.Price
    profile.Pending, self.Busy[player] = intent, intent.OperationId
    local record, err = self:_resume(player)
    if self.Busy[player] == intent.OperationId then self.Busy[player] = nil end
    return record ~= nil, record and "House ordered! Construction takes six seconds." or err
end
function Houses:SecureWild(player, offer, state)
    local ctx, profile = self.Context, self.Context.Data:Get(player)
    if not profile then return nil, "Profile released." end
    if profile.Pending then
        if profile.Pending.Id ~= offer.Id or profile.Pending.Kind ~= "Wild"
            or profile.Pending.OperationId ~= state.Token then return nil, "Another transaction is pending." end
        state.IntentPrepared = true
        return self:_resume(player)
    end
    if not ctx.Data:IsWritable(player) or not ctx.Steal:_valid(state, true) then return nil, "The carry was interrupted." end
    local intent = self:_intent(player, "Wild", offer.DefinitionId, offer.Variant, state.Record.Size,
        state.Slot, offer.Id, state.Token)
    profile.Pending = intent
    state.IntentPrepared = true
    return self:_resume(player)
end
function Houses:Sell(player, uid, confirmed)
    local ctx, profile = self.Context, self.Context.Data:Get(player)
    local record = type(uid) == "string" and (self.Records[player] or {})[uid]
    if not record or not self:_ready(player) then return false, "That house is unavailable." end
    if not ctx.World:AtHome(player) then return false, "Sell from your own base." end
    if confirmed ~= true then ctx.Notify(player, "Confirm selling this house.", "ConfirmSell", uid); return true end
    if record.BuildReadyAt > ctx.Clock() then return false, "Wait for construction to finish." end
    local intent = self:_intent(player, "Sell", record.DefinitionId, record.Variant, record.Size, record.Slot, uid)
    intent.ExpectedRevision = record.Revision
    intent.Price = math.floor(ctx.Config.HouseById[record.DefinitionId].Price
        * ctx.Config.VariantById[record.Variant].Multiplier * ctx.Config.SizeById[record.Size].IncomeMultiplier * 0.5)
    profile.Pending, self.Busy[player] = intent, intent.OperationId
    local result, err = self:_resume(player)
    if self.Busy[player] == intent.OperationId then self.Busy[player] = nil end
    return result ~= nil, result and "House sold. Previous rent is waiting at your base." or err
end
function Houses:Collect(player, uid)
    local ctx, profile = self.Context, self.Context.Data:Get(player)
    if not self:_ready(player) or not ctx.World:AtHome(player) then return false, "Collect rent at your own base." end
    if uid ~= nil and (type(uid) ~= "string" or not (self.Records[player] or {})[uid]) then return false, "Unknown house." end
    local amount = uid and (profile.Income[uid] or 0) or profile.Bank
    if not uid then for _, value in pairs(profile.Income) do amount += value end end
    local credit = math.min(amount, ctx.Config.Game.MaxCash - profile.Cash)
    if credit <= 0 then return false, "No rent to collect, or your wallet is full." end
    local remaining = credit
    if not uid then
        local take = math.min(profile.Bank, remaining)
        profile.Bank -= take; remaining -= take
    end
    local ids = uid and { uid } or {}
    if not uid then for id in pairs(profile.Income) do table.insert(ids, id) end; table.sort(ids) end
    for _, id in ipairs(ids) do
        local take = math.min(profile.Income[id] or 0, remaining)
        profile.Income[id] -= take; remaining -= take
        if remaining <= 0 then break end
    end
    profile.Cash += credit
    profile.Statistics.TotalEarned = math.min(1e15, profile.Statistics.TotalEarned + credit)
    ctx.Publish(player)
    return true, "$" .. math.floor(credit) .. " rent collected!"
end
function Houses:ApplyTransfer(source, target, oldRecord, newRecord)
    local ctx = self.Context
    local from, to = ctx.Data:Get(source), ctx.Data:Get(target)
    local previous = (self.Records[target] or {})[newRecord.Id]
    local alreadyApplied = previous and previous.Revision == newRecord.Revision and previous.OperationId == newRecord.OperationId
    if from then self:_bank(from, from.Income[oldRecord.Id] or 0); from.Income[oldRecord.Id] = nil end
    if to and not alreadyApplied then
        to.Income[oldRecord.Id] = 0
        to.Collection[newRecord.DefinitionId] = true
        to.Statistics.Stolen += 1
    end
    if self.Records[source] then self.Records[source][oldRecord.Id] = nil end
    if self.Records[target] then self.Records[target][newRecord.Id] = newRecord end
    ctx.World:RemoveHouse(source, oldRecord.Id)
    -- Held stays set until Steal clears its transaction state; force the destination display.
    if ctx.World:GetPlot(target) then ctx.World:RenderHouse(target, newRecord) end
end
function Houses:Refresh(player)
    if not self.Context.Data:Get(player) then return false end
    local list, err = self.Context.Ownership:List(player.UserId)
    if not list then return false, err end
    local old = self.Records[player] or {}
    local profile = self.Context.Data:Get(player)
    self.Records[player] = {}
    for _, record in ipairs(list) do
        self.Records[player][record.Id] = record
        profile.Income[record.Id] = profile.Income[record.Id] or 0
        profile.Collection[record.DefinitionId] = true
        self:_render(player, record)
    end
    for uid, amount in pairs(profile.Income) do
        if not self.Records[player][uid] then self:_bank(profile, amount); profile.Income[uid] = nil end
    end
    for uid in pairs(old) do if not self.Records[player][uid] then self.Context.World:RemoveHouse(player, uid) end end
    return true
end
function Houses:Tick(dt)
    local ctx = self.Context
    for player, records in pairs(self.Records) do
        local profile = ctx.Data:Get(player)
        if profile and ctx.Data:IsWritable(player) and not self.Busy[player] and not profile.Pending then
            profile.LastSeen = ctx.Clock()
            for uid, record in pairs(records) do
                if not ctx.Steal:IsHeld(uid) and record.BuildReadyAt <= ctx.Clock() then
                    profile.Income[uid] = math.min(ctx.Config.Game.IncomeCap,
                        (profile.Income[uid] or 0) + self:Rate(record) * dt)
                    ctx.World:UpdateIncome(player, uid, profile.Income[uid])
                end
            end
        elseif profile and profile.Pending and not self.Busy[player] and not self.Recovering[player]
            and not ctx.Steal.Carriers[player] and ctx.Data:IsWritable(player)
            and (self.RecoverAt[player] or 0) <= ctx.Now() then
            self.RecoverAt[player], self.Recovering[player] = ctx.Now() + 10, true
            task.spawn(function()
                local pending = profile.Pending
                if pending then
                    self.Busy[player] = pending.OperationId
                    local ok, err = pcall(function() return self:_resume(player) end)
                    if not ok then warn("[House recovery]", err) end
                    if self.Busy[player] == pending.OperationId then self.Busy[player] = nil end
                end
                self.Recovering[player] = nil
            end)
        end
    end
end
function Houses:Release(player)
    self.Records[player], self.Reserved[player] = nil, nil
    self.RecoverAt[player], self.Recovering[player] = nil, nil
end
return Houses
