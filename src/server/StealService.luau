-- Pickup is provisional. Only the ownership ledger can transfer a player's house.
local Steal = {}
Steal.__index = Steal

function Steal.new(ctx)
    return setmetatable({ Context = ctx, Carriers = {}, Held = {}, BatTimes = {},
        Now = ctx.Now or os.clock, Spawn = ctx.Spawn or task.spawn }, Steal)
end
function Steal:IsHeld(uid)
    local state = self.Held[uid]
    return state ~= nil and state.Phase ~= "Hold"
end
function Steal:SourceHousesBusy(player)
    for _, state in pairs(self.Held) do
        if state.Owner == player or state.Player == player then return true end
    end
    return false
end
function Steal:_available(player, token)
    local ctx = self.Context
    local profile = ctx.Data:Get(player)
    return not ctx.Closing and profile ~= nil and ctx.Data:IsWritable(player)
        and (ctx.Ready == nil or ctx.Ready[player] == true)
        and not profile.Pending and ctx.World:GetPlot(player) ~= nil
        and (not ctx.Houses.Busy[player] or ctx.Houses.Busy[player] == token)
end
function Steal:_owner(uid)
    for player, records in pairs(self.Context.Houses.Records) do
        if records[uid] then return player, records[uid] end
    end
end
function Steal:_slotValid(state)
    local houses = self.Context.Houses
    if not houses.Reserved[state.Player] or houses.Reserved[state.Player][state.Slot] ~= state.Token
        or state.Slot > houses:Capacity(state.Player) then return false end
    for _, record in pairs(houses.Records[state.Player] or {}) do
        if record.Slot == state.Slot then return false end
    end
    return true
end
function Steal:_sourceValid(state)
    local ctx = self.Context
    if state.Wild then
        local offer = ctx.Wild:Get(state.Id)
        return offer == state.Offer and offer.Busy == state.Player
    end
    local records = ctx.Houses.Records[state.Owner]
    local record = records and records[state.Id]
    return self:_available(state.Owner, state.Token) and not ctx.Progression:IsLocked(state.Owner)
        and record ~= nil and record.OwnerId == state.Owner.UserId
        and record.Revision == state.Revision and record.Slot == state.Record.Slot
end
function Steal:_valid(state, atHome)
    local ctx = self.Context
    if self.Carriers[state.Player] ~= state or self.Held[state.Id] ~= state
        or state.CancelReason or not self:_available(state.Player, state.Token)
        or not self:_slotValid(state) or not self:_sourceValid(state)
        or not ctx.AntiExploit:Character(state.Player)
        or not ctx.AntiExploit:ValidateMovement(state.Player) then return false end
    return not atHome or ctx.World:AtHome(state.Player)
end
function Steal:_position(state)
    if state.Wild then return { Position = state.Offer.Position, Model = state.Offer.Model } end
    local ctx = self.Context
    local plot = ctx.World:GetPlot(state.Owner)
    if not plot then return nil end
    local model = ctx.World.GetHouseModel and ctx.World:GetHouseModel(state.Owner, state.Id)
    return { Position = ctx.World:SlotPosition(plot, state.Record.Slot), Model = model }
end
function Steal:_holdValid(state)
    if not self:_valid(state, false) then return false end
    local ctx = self.Context
    if state.Wild and ctx.Progression:Speed(state.Player) < (state.Offer.RequiredSpeed or 0) then return false end
    local target = self:_position(state)
    return target ~= nil and ctx.AntiExploit:CanInteract(state.Player, target, ctx.Config.Game.InteractionRadius)
end
function Steal:_speed(player, carry)
    local ctx = self.Context
    if ctx.Progression.UpdateSpeed then ctx.Progression:UpdateSpeed(player); return end
    local _, humanoid = ctx.AntiExploit:Character(player)
    if humanoid then
        humanoid.WalkSpeed = carry and self.Context.Config.Game.CarrySpeed or self.Context.Progression:Speed(player)
    end
end
function Steal:_begin(player, record, owner, offer)
    local ctx = self.Context
    if self.Carriers[player] or self.Held[record.Id] or not self:_available(player) then return false end
    local slot = ctx.Houses:FreeSlot(player)
    if not slot then ctx.Notify(player, "Your base has no empty pad.", "Error"); return false end
    local token = ctx.HttpService:GenerateGUID(false)
    local state = { Id = record.Id, Record = record, Revision = record.Revision, Owner = owner,
        Player = player, Slot = slot, Token = token, Phase = "Hold", StartedAt = self.Now(),
        Wild = offer ~= nil, Offer = offer }
    ctx.Houses.Reserved[player] = ctx.Houses.Reserved[player] or {}
    ctx.Houses.Reserved[player][slot] = token
    self.Carriers[player], self.Held[state.Id] = state, state
    if not self:_holdValid(state) then self:Cancel(player); return false end
    if ctx.Progression.Train then ctx.Progression:Train(player, false) end
    self:_speed(player, false)
    ctx.Publish(player)
    return true
end
function Steal:Attempt(player, uid)
    if type(uid) ~= "string" or #uid > 100 then return false end
    local owner, record = self:_owner(uid)
    if not owner or owner == player or (record.BuildReadyAt or 0) > self.Context.Clock()
        or not self:_available(owner) or self.Context.Progression:IsLocked(owner) then return false end
    return self:_begin(player, record, owner, nil)
end
function Steal:AttemptWild(player, offerId)
    local ctx = self.Context
    if type(offerId) ~= "string" or #offerId > 100 or self.Carriers[player]
        or self.Held[offerId] or not self:_available(player) then return false end
    local offer = ctx.Wild:Get(offerId)
    if not offer or offer.Busy or ctx.Progression:Speed(player) < (offer.RequiredSpeed or 0)
        or not ctx.AntiExploit:CanInteract(player, offer, ctx.Config.Game.InteractionRadius) then return false end
    offer = ctx.Wild:Claim(offerId, player)
    if not offer then return false end
    local record = { Id = offer.Id, DefinitionId = offer.DefinitionId, Variant = offer.Variant, Size = offer.Size }
    if self:_begin(player, record, nil, offer) then return true end
    ctx.Wild:Release(offerId, player)
    return false
end
function Steal:_cleanup(state)
    local ctx, player = self.Context, state.Player
    if self.Held[state.Id] == state then self.Held[state.Id] = nil end
    if self.Carriers[player] == state then
        self.Carriers[player] = nil
        ctx.World:ClearCarry(player)
        self:_speed(player, false)
    end
    local reserved = ctx.Houses.Reserved[player]
    if reserved and reserved[state.Slot] == state.Token then reserved[state.Slot] = nil end
    for _, participant in ipairs({ player, state.Owner }) do
        if ctx.Houses.Busy[participant] == state.Token then ctx.Houses.Busy[participant] = nil end
    end
    ctx.Publish(player)
    if state.Owner then ctx.Publish(state.Owner) end
end
function Steal:_return(state, reason)
    local ctx = self.Context
    if state.Wild then
        ctx.Wild:Release(state.Id, state.Player)
    elseif state.Phase ~= "Hold" and self:_owner(state.Id) == state.Owner then
        local record = (ctx.Houses.Records[state.Owner] or {})[state.Id]
        if record and record.Revision == state.Revision and ctx.World:GetPlot(state.Owner) then
            ctx.World:RenderHouse(state.Owner, record)
        end
    end
    self:_cleanup(state)
    if reason then ctx.Notify(state.Player, reason, "Error") end
end
function Steal:Cancel(player, reason)
    local state = self.Carriers[player]
    if not state then return end
    if state.Phase == "Committing" then
        -- UpdateAsync may have committed while its response is still in flight.
        state.CancelReason = reason or "Carry interrupted."
        return
    end
    self:_return(state, reason)
end
function Steal:CancelForOwner(player)
    local states = {}
    for _, state in pairs(self.Held) do if state.Owner == player then table.insert(states, state) end end
    for _, state in ipairs(states) do self:Cancel(state.Player, "The original owner left.") end
end
function Steal:_carry(state)
    local ctx = self.Context
    state.Phase, state.CarriedAt = "Carry", self.Now()
    if state.Wild then
        state.Record.Size = state.Offer.Size -- Freeze server-grown size at pickup, never accept client size.
        ctx.World:RemovePrefab(state.Offer)
    else
        ctx.World:RemoveHouse(state.Owner, state.Id)
    end
    ctx.World:CarryModel(state.Player, state.Record)
    self:_speed(state.Player, true)
    ctx.Notify(state.Player, "Carry the house to your own base!", "Info")
    if state.Owner then ctx.Notify(state.Owner, "Someone is carrying your house! Use your bat.", "Warning") end
    ctx.Publish(state.Player)
end
function Steal:_settle(state, record, readKnown)
    local ctx = self.Context
    local committedRevision = if state.Wild then 1 else state.Revision + 1
    if record and record.OwnerId == state.Player.UserId and record.OperationId == state.Token
        and record.Revision == committedRevision and record.Slot == state.Slot then
        if state.Wild then ctx.Wild:Finish(state.Id, state.Player)
        else ctx.Houses:ApplyTransfer(state.Owner, state.Player, state.Record, record) end
        self:_cleanup(state)
        ctx.Notify(state.Player, "House secured!", "Success")
        return true
    end
    local profile = ctx.Data:Get(state.Player)
    if readKnown and ((not state.Wild and record and record.OwnerId == state.Owner.UserId
        and record.Revision == state.Revision) or (state.Wild and not record
        and not state.IntentPrepared and profile ~= nil and not profile.Pending)) then
        self:_return(state, state.CancelReason or "The transfer could not be completed. Try again.")
        return true
    end
    if readKnown and record and ((state.Wild)
        or record.OwnerId ~= state.Owner.UserId or record.Revision ~= state.Revision) then
        -- A later sale/transfer may win while this server awaits a response.
        -- A conclusive canonical change cannot be rolled back to our old copy.
        -- Refresh under the existing economic locks before releasing them.
        local participants, seen = { state.Player }, {}
        if state.Owner then table.insert(participants, state.Owner) end
        if ctx.Players and ctx.Players.GetPlayerByUserId and record.OwnerId ~= 0 then
            local owner = ctx.Players:GetPlayerByUserId(record.OwnerId)
            if owner then table.insert(participants, owner) end
        end
        for _, participant in ipairs(participants) do
            if not seen[participant] and ctx.Data:Get(participant) then
                seen[participant] = true
                local ok, refreshed = pcall(function() return ctx.Houses:Refresh(participant) end)
                if not ok or not refreshed then state.RetryAt = self.Now() + 3; return false end
            end
        end
        if state.Wild then ctx.Wild:Finish(state.Id, state.Player) end
        for participant in pairs(seen) do
            local current = (ctx.Houses.Records[participant] or {})[state.Id]
            if current and current.OwnerId == participant.UserId and ctx.World:GetPlot(participant) then
                -- Refresh suppresses held UIDs, so reveal the reconciled house
                -- explicitly before this transaction releases its locks.
                ctx.World:RenderHouse(participant, current)
            end
        end
        self:_cleanup(state)
        ctx.Notify(state.Player, "House ownership changed; your base has been refreshed.", "Warning")
        return true
    end
    -- Unknown commit outcomes keep the UID and pad frozen; never duplicate a house.
    state.RetryAt = self.Now() + 3
    return false
end
function Steal:_commit(state)
    if state.InFlight then return end
    local ctx = self.Context
    if state.Phase ~= "Committing" then
        if not self:_valid(state, true) then self:Cancel(state.Player, "Carry interrupted."); return end
        state.Phase = "Committing"
        ctx.Houses.Busy[state.Player] = state.Token
        if state.Owner then ctx.Houses.Busy[state.Owner] = state.Token end
    end
    state.InFlight = true
    self.Spawn(function()
        local record
        local ok = pcall(function()
            if state.Wild then
                record = ctx.Houses:SecureWild(state.Player, state.Offer, state)
            else
                record = ctx.Ownership:Transfer(state.Id, state.Owner.UserId, state.Revision,
                    state.Player.UserId, state.Slot, state.Token, function() return self:_valid(state, true) end)
            end
        end)
        if self.Carriers[state.Player] ~= state then state.InFlight = false; return end
        if ok and record then
            local settledOK, settled = pcall(function() return self:_settle(state, record, true) end)
            if settledOK and settled then state.InFlight = false; return end
        end
        local readOK, canonical, err = pcall(function() return ctx.Ownership:Get(state.Id) end)
        local settledOK = pcall(function()
            self:_settle(state, readOK and canonical or nil, readOK and not err)
        end)
        state.InFlight = false -- Keep the transaction locked through yielding reconciliation too.
        if not settledOK then state.RetryAt = self.Now() + 3 end
    end)
end
function Steal:CanCommit(state)
    return self:_valid(state, true)
end
function Steal:Bat(player)
    local ctx, now = self.Context, self.Now()
    if not self:_available(player) or self.Carriers[player]
        or now - (self.BatTimes[player] or -math.huge) < ctx.Config.Game.BatCooldown then return false end
    local root, humanoid = ctx.AntiExploit:Character(player)
    if not root or humanoid.FloorMaterial == Enum.Material.Air
        or not ctx.AntiExploit:ValidateMovement(player) then return false end
    local nearest, distance
    for carrier, state in pairs(self.Carriers) do
        local target = ctx.AntiExploit:Character(carrier)
        if carrier ~= player and state.Phase == "Carry" and target then
            local length = (target.Position - root.Position).Magnitude
            if length <= ctx.Config.Game.BatRange and (not distance or length < distance)
                and ctx.AntiExploit:CanInteract(player, { Position = target.Position, Model = carrier.Character }, ctx.Config.Game.BatRange) then
                nearest, distance = state, length
            end
        end
    end
    self.BatTimes[player] = now
    if not nearest then return false end
    local target = ctx.AntiExploit:Character(nearest.Player)
    self:Cancel(nearest.Player, "The bat stopped your escape!")
    if target then
        local delta = target.Position - root.Position
        local direction = delta.Magnitude > 0.01 and delta.Unit or root.CFrame.LookVector
        target.AssemblyLinearVelocity = direction * 28 + Vector3.new(0, 5, 0)
        ctx.AntiExploit:AllowTeleport(nearest.Player) -- A server-authorized knockback must not trigger rollback.
    end
    local profile = ctx.Data:Get(player)
    if profile and nearest.Owner == player then profile.Statistics.Defended += 1 end
    ctx.Publish(player)
    return true
end
function Steal:Tick(_dt)
    local states = {}
    for _, state in pairs(self.Carriers) do table.insert(states, state) end
    for _, state in ipairs(states) do
        if self.Carriers[state.Player] ~= state then continue end
        if state.Phase == "Committing" then
            if state.RetryAt and self.Now() >= state.RetryAt then self:_commit(state) end
        elseif state.Phase == "Hold" then
            if not self:_holdValid(state) then self:Cancel(state.Player, "Stay beside the house while stealing.")
            elseif self.Now() - state.StartedAt >= self.Context.Config.Game.StealHoldSeconds then self:_carry(state) end
        elseif not self:_valid(state, false) then self:Cancel(state.Player, "Carry interrupted.")
        elseif self.Now() - state.CarriedAt >= self.Context.Config.Game.CarryTimeoutSeconds then self:Cancel(state.Player, "Carry timed out.")
        else
            self:_speed(state.Player, true)
            if self.Context.World:AtHome(state.Player) then self:_commit(state) end
        end
    end
end
function Steal:Release(player)
    self:Cancel(player, "The carrier left.")
    self:CancelForOwner(player)
    self.BatTimes[player] = nil
end
return Steal
