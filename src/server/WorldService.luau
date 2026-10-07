--!nonstrict
local Factory = require(script.Parent.ModelFactory)
local World = {}
World.__index = World
local Physics = game:GetService("PhysicsService")

local BASE_WIDTH, BASE_DEPTH = 132, 126
local BASE_COLORS = { "FF9589", "FFD378", "83D8B8", "82B9F3", "B49AEF", "F1A1D1", "7BD7DC" }
local DISTRICTS = {
    { Name = "Starter Lane", Speed = 20, Color = "8FDB9D" },
    { Name = "Garden Street", Speed = 26, Color = "AAD584" },
    { Name = "Metro Avenue", Speed = 34, Color = "88BCD9" },
    { Name = "Skyline Crescent", Speed = 42, Color = "AF9BDD" },
    { Name = "Royal Road", Speed = 52, Color = "E5BE79" },
    { Name = "Astral Heights", Speed = 64, Color = "E697D3" },
}

function World.new(ctx)
    return setmetatable({ Context = ctx, Plots = {}, Assigned = {}, WildSites = {}, Houses = {},
        Carry = {}, Accumulator = 0, CharacterConnections = {}, SiteOffers = {} }, World)
end

function World:_request(player, action, ...)
    if not self.Context.Closing then self.Context.Request(player, action, ...) end
end

function World:_prompt(part, action, object, callback, hold)
    return Factory.Prompt(part, action, object, self.Context.Config.Game.InteractionRadius, hold, callback)
end

function World:_touch(part, callback)
    local last = setmetatable({}, { __mode = "k" })
    part.Touched:Connect(function(hit)
        if hit.Name ~= "HumanoidRootPart" then return end
        local player = self.Context.Players:GetPlayerFromCharacter(hit.Parent)
        local now = self.Context.Now()
        if player and (not last[player] or now - last[player] >= 0.75) then
            last[player] = now
            callback(player)
        end
    end)
end

local function groupName(id) return "HouseBaseOwner" .. id end
local function gateName(id) return "HouseBaseGate" .. id end

function World:_collisionGroups()
    -- A base owner passes only their own gate. There is no shared owner bypass.
    local names = { "HouseVisitors" }
    for id = 1, self.Context.Config.Game.MaxPlayers do
        table.insert(names, groupName(id)); table.insert(names, gateName(id))
    end
    for _, name in ipairs(names) do
        if not Physics:IsCollisionGroupRegistered(name) then Physics:RegisterCollisionGroup(name) end
    end
    for id = 1, self.Context.Config.Game.MaxPlayers do
        Physics:CollisionGroupSetCollidable(gateName(id), groupName(id), false)
        Physics:CollisionGroupSetCollidable(gateName(id), "HouseVisitors", true)
        for other = 1, self.Context.Config.Game.MaxPlayers do
            if other ~= id then Physics:CollisionGroupSetCollidable(gateName(id), groupName(other), true) end
        end
    end
end

function World:_base(id, origin, rotation)
    local frame = CFrame.new(origin) * CFrame.Angles(0, rotation, 0)
    local model = Factory.Model(self.Model, "Base_" .. id)
    local color = BASE_COLORS[id]
    local plot = { Id = id, Origin = origin, Frame = frame, Model = model, Pads = {}, Rendered = {},
        Gates = {}, Capacity = self.Context.Config.Game.StartingSlots,
        Entry = frame:PointToWorldSpace(Vector3.new(0, 2, -65)),
        CollectPosition = frame:PointToWorldSpace(Vector3.new(-20, 2, -44)),
        LockPosition = frame:PointToWorldSpace(Vector3.new(20, 2, -44)),
        TreadmillPosition = frame:PointToWorldSpace(Vector3.new(43, 2, -43)),
        Spawn = frame:PointToWorldSpace(Vector3.new(0, 4, -45)) }
    Factory.Part(model, "Floor", Vector3.new(BASE_WIDTH, 1, BASE_DEPTH), frame, "E6E8DF", Enum.Material.Concrete)
    local gates = {
        { Vector3.new(BASE_WIDTH, 34, 0.8), Vector3.new(0, 17, -BASE_DEPTH / 2) },
        { Vector3.new(BASE_WIDTH, 34, 0.8), Vector3.new(0, 17, BASE_DEPTH / 2) },
        { Vector3.new(0.8, 34, BASE_DEPTH), Vector3.new(-BASE_WIDTH / 2, 17, 0) },
        { Vector3.new(0.8, 34, BASE_DEPTH), Vector3.new(BASE_WIDTH / 2, 17, 0) },
        { Vector3.new(BASE_WIDTH, 0.8, BASE_DEPTH), Vector3.new(0, 34, 0) },
    }
    for _, details in ipairs(gates) do
        local gate = Factory.Part(model, "LockBarrier", details[1], frame * CFrame.new(details[2]), color, Enum.Material.ForceField)
        gate.CollisionGroup, gate.CanTouch = gateName(id), false
        table.insert(plot.Gates, gate)
    end
    for _, x in ipairs({ -65, 65 }) do
        Factory.Part(model, "BaseColumn", Vector3.new(2, 14, 2), frame * CFrame.new(x, 7, -62), color)
    end
    local sign = Factory.Part(model, "OwnerSign", Vector3.new(48, 6, 1), frame * CFrame.new(0, 14, -62), color)
    plot.OwnerText = Factory.Label(sign, "AVAILABLE BASE " .. id, "FFFFFF", 68, 230)
    plot.OwnerText.Parent.StudsOffset = Vector3.new(0, 0, 0)
    local lock = Factory.Part(model, "LockPad", Vector3.new(10, 0.5, 10),
        frame * CFrame.new(20, 0.9, -44), "F09392", Enum.Material.Neon)
    plot.LockText = Factory.Label(lock, "LOCK BASE\n60 seconds", "FFFFFF", 60, 95)
    self:_prompt(lock, "Lock base", "Finite shield", function(player)
        if plot.Owner == player then self:_request(player, "Lock") end
    end)
    local collect = Factory.Part(model, "CollectAll", Vector3.new(13, 0.5, 10),
        frame * CFrame.new(-20, 0.9, -44), "76DEA7", Enum.Material.Neon)
    Factory.Label(collect, "COLLECT ALL RENT", "FFFFFF", 44, 95)
    self:_prompt(collect, "Collect all", "Your rent", function(player)
        if plot.Owner == player then self:_request(player, "CollectAll") end
    end)
    self:_touch(collect, function(player) if plot.Owner == player then self:_request(player, "CollectAll") end end)
    local treadmill = Factory.Part(model, "Treadmill", Vector3.new(10, 1.5, 8),
        frame * CFrame.new(43, 1.1, -43), "3F4B61")
    Factory.Part(model, "RunningBelt", Vector3.new(7, 0.3, 6), frame * CFrame.new(43, 2, -43), "202838")
    plot.TreadmillText = Factory.Label(treadmill, "TREADMILL 1\nTrain to reach faster streets", "9DEBFF", 66, 90)
    self:_prompt(treadmill, "Start training", "Earn speed", function(player)
        if plot.Owner == player then self:_request(player, "Train", true) end
    end)
    local shop = Factory.Part(model, "UpgradeKiosk", Vector3.new(9, 3, 6), frame * CFrame.new(-43, 2, -43), color)
    Factory.Label(shop, "BASE UPGRADES", "FFFFFF", 44, 90)
    self:_prompt(shop, "Open upgrades", "House shop", function(player) self:_request(player, "OpenShop") end)
    for slot = 1, self.Context.Config.Game.MaxSlots do
        local position = self:SlotPosition(plot, slot)
        local pad = Factory.Part(model, "HousePad_" .. slot, Vector3.new(19, 0.45, 19), CFrame.new(position), color)
        local rent = Factory.Part(model, "RentPad_" .. slot, Vector3.new(6, 0.35, 3),
            frame * CFrame.new(((slot - 1) % 5 - 2) * 24, 1.05, math.floor((slot - 1) / 5) * 23 - 21 - 10), "74D6A4")
        local text = Factory.Label(rent, "EMPTY SLOT " .. slot, "FFFFFF", 42, 65)
        text.Parent.StudsOffset = Vector3.new(0, 1.3, 0)
        local padState = { Part = pad, Rent = rent, Text = text }
        padState.Prompt = self:_prompt(rent, "Collect rent", "House " .. slot, function(player)
            if plot.Owner == player and padState.Uid then self:_request(player, "Collect", padState.Uid) end
        end)
        self:_touch(rent, function(player)
            if plot.Owner == player and padState.Uid then self:_request(player, "Collect", padState.Uid) end
        end)
        plot.Pads[slot] = padState
    end
    self.Plots[id] = plot
    self:SetOwner(plot, nil)
    self:SetLock(plot, false, 0)
    self:_slots(plot, plot.Capacity)
end

function World:_wildNeighborhood()
    local id = 0
    for street, roadX in ipairs({ -300, 0, 300 }) do
        Factory.Part(self.Model, "LandlordStreet_" .. street, Vector3.new(36, 0.4, 620),
            CFrame.new(roadX, 0.25, -540), "68717B", Enum.Material.Asphalt)
        for line = 1, 15 do
            Factory.Part(self.Model, "RoadMarking", Vector3.new(1.5, 0.1, 13),
                CFrame.new(roadX, 0.55, -235 - line * 38), "F9E4A8")
        end
        for row, z in ipairs({ -350, -525, -700 }) do
            for sideIndex, side in ipairs({ -1, 1 }) do
                id += 1
                local tier = (row - 1) * 2 + sideIndex
                local district = DISTRICTS[tier]
                local origin = Vector3.new(roadX + side * 96, 1, z)
                local frame = CFrame.lookAt(origin, Vector3.new(roadX, 1, z))
                local model = Factory.Model(self.Model, "LandlordPlot_" .. id)
                -- Adjacent streets leave only 108 studs between rear neighbors.
                -- Keep their ground plates separate to avoid overlapping surfaces.
                Factory.Part(model, "Territory", Vector3.new(100, 0.7, 106), frame, district.Color, Enum.Material.Grass)
                Factory.Part(model, "Walkway", Vector3.new(16, 0.2, 54), frame * CFrame.new(0, 0.6, -26), "E5D6BD")
                local landmark = { Color = district.Color, Style = tier >= 5 and "castle" or tier >= 3 and "modern" or "cottage" }
                Factory.House(model, "LandlordHome", frame * CFrame.new(0, 0.7, 28), landmark, { Color = "FFF2C8" }, 1.8, false)
                local guardFrame = frame * CFrame.new(17, 0.5, -24)
                local guard = Factory.Landlord(model, guardFrame, district.Color, tier)
                local sign = Factory.Part(model, "SpeedSign", Vector3.new(12, 5, 1), frame * CFrame.new(-22, 5, -50), "243149")
                Factory.Label(sign, district.Name .. "\nSPEED " .. district.Speed .. "+", "FFE7A0", 65, 140)
                local position = frame:PointToWorldSpace(Vector3.new(0, 0.8, -9))
                Factory.Part(model, "PrefabStand", Vector3.new(23, 0.5, 22), CFrame.new(position - Vector3.new(0, 0.5, 0)), "EEE2C6")
                table.insert(self.WildSites, { Id = "site_" .. id, Position = position, Model = model,
                    Frame = frame, Tier = tier, RequiredSpeed = district.Speed, GuardModel = guard,
                    GuardOrigin = guardFrame.Position, GuardFrame = guardFrame })
            end
        end
    end
end

function World:Init()
    self:_collisionGroups()
    local old = self.Context.Workspace:FindFirstChild("HouseNeighborhood")
    if old then old:Destroy() end
    self.Model = Factory.Model(self.Context.Workspace, "HouseNeighborhood")
    Factory.Part(self.Model, "Ground", Vector3.new(1090, 1, 1330), CFrame.new(0, -0.7, -380), "6DAD79", Enum.Material.Grass)
    Factory.Part(self.Model, "TownSquare", Vector3.new(650, 0.4, 182), CFrame.new(0, 0.1, 0), "C9C8B9", Enum.Material.Concrete)
    local arrival = Instance.new("SpawnLocation")
    arrival.Name, arrival.Size, arrival.CFrame = "TownArrival", Vector3.new(12, 1, 12), CFrame.new(0, 1, 62)
    arrival.Anchored, arrival.Neutral, arrival.Duration = true, true, 0
    arrival.Color, arrival.Material = Color3.fromRGB(152, 207, 216), Enum.Material.SmoothPlastic
    arrival.Parent = self.Model -- Safe waiting spawn while persistent profiles are loading.
    local fountain = Factory.Part(self.Model, "Fountain", Vector3.new(30, 1.5, 30), CFrame.new(0, 1, 0), "E4E8E8")
    Factory.Part(self.Model, "FountainWater", Vector3.new(26, 0.3, 26), CFrame.new(0, 1.9, 0), "77D4EE", Enum.Material.Glass)
    Factory.Part(self.Model, "FountainPillar", Vector3.new(4, 7, 4), CFrame.new(0, 5, 0), "E4E8E8")
    Factory.Label(fountain, "STEAL A HOUSE\nSteal a prefab • Build • Collect rent • Train", "FFFFFF", 68, 230)
    local market = Factory.Part(self.Model, "TownShop", Vector3.new(16, 5, 9), CFrame.new(-45, 3, 0), "F0B778")
    Factory.Label(market, "HOUSE SHOP + UPGRADES", "FFFFFF", 45, 130)
    self:_prompt(market, "Open shop", "Buy a house", function(player) self:_request(player, "OpenShop") end)
    local board = Factory.Part(self.Model, "Standings", Vector3.new(26, 14, 2), CFrame.new(45, 8, 0), "243149")
    self.StandingsText = Factory.Label(board, "TOWN STANDINGS\nWaiting for residents", "FFF2BC", 170, 140)
    self.StandingsText.Parent.StudsOffset = Vector3.new(0, 0, 0)
    self.StandingsText.Parent.Size = UDim2.fromOffset(360, 250)
    for id, x in ipairs({ -222, -74, 74, 222 }) do self:_base(id, Vector3.new(x, 1, -170), math.pi) end
    for index, x in ipairs({ -148, 0, 148 }) do self:_base(index + 4, Vector3.new(x, 1, 170), 0) end
    self:_wildNeighborhood()
end

function World:SlotPosition(plot, slot)
    if type(slot) ~= "number" or slot < 1 or slot > self.Context.Config.Game.MaxSlots or slot % 1 ~= 0 then return nil end
    return plot.Frame:PointToWorldSpace(Vector3.new(((slot - 1) % 5 - 2) * 24, 0.8,
        math.floor((slot - 1) / 5) * 23 - 21))
end

function World:SetOwner(plot, player)
    plot.Owner = player
    plot.Model:SetAttribute("OwnerId", player and player.UserId or 0)
    plot.OwnerText.Text = player and (player.DisplayName .. "'s BASE\nSteal houses • Collect rent") or ("AVAILABLE BASE " .. plot.Id)
end

function World:Assign(player)
    if self.Assigned[player] then return self.Assigned[player] end
    for _, plot in ipairs(self.Plots) do
        if not plot.Owner then
            self.Assigned[player], self.Houses[player] = plot, {}
            self:SetOwner(plot, player)
            self:SetCharacterGroup(player)
            return plot
        end
    end
    return nil
end

function World:GetPlot(player) return self.Assigned[player] end

function World:Inside(player, plot)
    if not plot then return false end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local localPosition = plot.Frame:PointToObjectSpace(root.Position)
    return math.abs(localPosition.X) < BASE_WIDTH / 2 - 2
        and math.abs(localPosition.Z) < BASE_DEPTH / 2 - 2
        and localPosition.Y >= -1 and localPosition.Y <= 15
end

function World:AtHome(player) return self:Inside(player, self:GetPlot(player)) end

function World:SetCharacterGroup(player)
    local connection = self.CharacterConnections[player]
    if connection then connection:Disconnect(); self.CharacterConnections[player] = nil end
    local character = player.Character
    if not character then return end
    local plot = self:GetPlot(player)
    local group = plot and groupName(plot.Id) or "HouseVisitors"
    local function set(part) if part:IsA("BasePart") then part.CollisionGroup = group end end
    for _, part in ipairs(character:GetDescendants()) do set(part) end
    self.CharacterConnections[player] = character.DescendantAdded:Connect(set)
end

function World:SetLock(plot, locked, remaining)
    if not plot then return end
    plot.Locked, plot.LockRemaining = locked == true, math.max(0, remaining or 0)
    plot.Model:SetAttribute("Locked", plot.Locked)
    for _, gate in ipairs(plot.Gates) do
        gate.CanCollide, gate.CanQuery = plot.Locked, plot.Locked
        gate.Transparency = plot.Locked and 0.63 or 1
    end
    plot.LockText.Text = plot.Locked and ("BASE LOCKED\n" .. math.ceil(plot.LockRemaining) .. " seconds") or "LOCK BASE\nFinite shield"
end

function World:_slots(plot, capacity)
    plot.Capacity = math.clamp(math.floor(capacity), 1, #plot.Pads)
    for slot, pad in ipairs(plot.Pads) do
        local enabled = slot <= plot.Capacity
        pad.Part.Transparency, pad.Rent.Transparency = enabled and 0.15 or 0.8, enabled and 0 or 0.8
        pad.Part.Color = enabled and Factory.Color(BASE_COLORS[plot.Id]) or Color3.fromRGB(82, 87, 99)
        pad.Prompt.Enabled = enabled and pad.Uid ~= nil
        if not pad.Uid then pad.Text.Text = enabled and ("EMPTY SLOT " .. slot) or "UPGRADE BASE\nUnlock slot" end
    end
end

function World:UpdateSlots(player, capacity)
    local plot = self:GetPlot(player)
    if plot then self:_slots(plot, capacity) end
end

function World:UpdateTreadmill(player, level, training)
    local plot = self:GetPlot(player)
    if plot then plot.TreadmillText.Text = "TREADMILL " .. tostring(level) .. (training and "\nTRAINING • Earn speed" or "\nTrain to reach faster streets") end
end

function World:_size(id)
    local definition = self.Context.Config.SizeById and self.Context.Config.SizeById[id]
    return definition and (definition.Scale or definition.SizeScale) or (id == "Giant" and 1.5 or id == "Big" and 1.25 or 1)
end

function World:RenderHouse(player, record)
    local plot = self:GetPlot(player)
    local definition = self.Context.Config.HouseById[record.DefinitionId]
    if not plot or not definition then return nil end
    local position = self:SlotPosition(plot, record.Slot)
    if not position then return nil end
    self:RemoveHouse(player, record.Id)
    local construction = (record.BuildReadyAt or 0) > self.Context.Clock()
    local frame = CFrame.new(position) * plot.Frame.Rotation
    local variant = self.Context.Config.VariantById[record.Variant]
    local model, anchor = Factory.House(plot.Model, "House_" .. record.Id, frame, definition, variant, self:_size(record.Size), construction)
    model:SetAttribute("HouseId", record.Id)
    model:SetAttribute("HouseUID", record.Id)
    model:SetAttribute("OwnerId", player.UserId)
    model:SetAttribute("DefinitionId", record.DefinitionId)
    local rarity = self.Context.Config.Rarities[definition.Rarity]
    local text = Factory.Label(anchor, definition.Name, rarity and rarity.Color, 77, 115)
    local promptPart = Factory.Part(model, "HousePrompt", Vector3.new(1, 1, 1), frame * CFrame.new(0, 3, -9), "FFFFFF")
    promptPart.Transparency, promptPart.CanCollide, promptPart.CanTouch, promptPart.CanQuery = 1, false, false, false
    local prompt = self:_prompt(promptPart, "Take / manage house", definition.Name, function(visitor)
        if visitor == player then self:_request(visitor, "Sell", record.Id, false)
        else self:_request(visitor, "Steal", record.Id) end
    end, 0) -- The server performs the two-second hold and publishes progress.
    -- Prompt range and server distance both use the house's slot center.
    prompt.MaxActivationDistance = math.max(2, self.Context.Config.Game.InteractionRadius - 9)
    local state = { Model = model, Record = record, Label = text, Prompt = prompt, Construction = construction, Amount = 0 }
    self.Houses[player] = self.Houses[player] or {}
    self.Houses[player][record.Id] = state
    plot.Rendered[record.Id] = state
    local pad = plot.Pads[record.Slot]
    pad.Uid = record.Id
    pad.Prompt.Enabled = record.Slot <= plot.Capacity
    self:UpdateIncome(player, record.Id, 0)
    return model
end

function World:GetHouseModel(player, uid)
    local state = self.Houses[player] and self.Houses[player][uid]
    return state and state.Model or nil
end

function World:RemoveHouse(player, uid)
    local houses = self.Houses[player]
    local state = houses and houses[uid]
    if not state then return end
    local plot = self:GetPlot(player)
    if plot then
        local pad = plot.Pads[state.Record.Slot]
        if pad and pad.Uid == uid then
            pad.Uid, pad.Prompt.Enabled = nil, false
            pad.Text.Text = state.Record.Slot <= plot.Capacity and ("EMPTY SLOT " .. state.Record.Slot) or "UPGRADE BASE\nUnlock slot"
        end
        plot.Rendered[uid] = nil
    end
    state.Model:Destroy()
    houses[uid] = nil
end

function World:UpdateIncome(player, uid, amount)
    local state = self.Houses[player] and self.Houses[player][uid]
    local plot = self:GetPlot(player)
    if not state or not plot then return end
    state.Amount = math.max(0, amount or 0)
    local definition = self.Context.Config.HouseById[state.Record.DefinitionId]
    local remaining = math.max(0, (state.Record.BuildReadyAt or 0) - self.Context.Clock())
    state.Label.Text = definition.Name .. "\n" .. tostring(state.Record.Variant) .. " • " .. tostring(state.Record.Size)
        .. (remaining > 0 and ("\nBUILDING " .. math.ceil(remaining) .. "s") or "")
    plot.Pads[state.Record.Slot].Text.Text = "COLLECT " .. Factory.Money(state.Amount)
end

function World:CarryModel(player, record)
    self:ClearCarry(player)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local definition = self.Context.Config.HouseById[record.DefinitionId]
    if not root or not definition then return nil end
    local variant = self.Context.Config.VariantById[record.Variant]
    local model = Factory.House(self.Model, "CarriedPrefab_" .. player.UserId,
        root.CFrame * CFrame.new(0, 1, -4), definition, variant, 0.43 * self:_size(record.Size), true)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, false, true
            local weld = Instance.new("WeldConstraint")
            weld.Part0, weld.Part1, weld.Parent = root, part, part
        end
    end
    model:SetAttribute("HouseId", record.Id)
    model:SetAttribute("HouseUID", record.Id)
    self.Carry[player] = model
    return model
end

function World:ClearCarry(player)
    local model = self.Carry[player]
    if model then model:Destroy(); self.Carry[player] = nil end
end

function World:_offerFrame(offer)
    local site
    for _, candidate in ipairs(self.WildSites) do
        if candidate.Id == offer.SiteId or candidate == offer.Site then site = candidate; break end
    end
    return CFrame.new(offer.Position) * (site and site.Frame.Rotation or CFrame.new())
end

function World:CreatePrefab(offer)
    self:RemovePrefab(offer)
    local definition = self.Context.Config.HouseById[offer.DefinitionId]
    if not definition then return nil end
    local variant = self.Context.Config.VariantById[offer.Variant]
    local model, anchor = Factory.House(self.Model, "WildPrefab_" .. offer.Id, self:_offerFrame(offer),
        definition, variant, self:_size(offer.Size), true)
    model:SetAttribute("OfferId", offer.Id)
    local rarity = self.Context.Config.Rarities[definition.Rarity]
    offer.WorldLabel = Factory.Label(anchor, definition.Name, rarity and rarity.Color, 88, 130)
    -- RequiresLineOfSight prompts cannot be embedded inside the opaque crate.
    local promptPart = Factory.Part(model, "PrefabPrompt", Vector3.new(1, 1, 1),
        self:_offerFrame(offer) * CFrame.new(0, 3, -5.4 * self:_size(offer.Size) - 1), "FFFFFF")
    promptPart.Transparency, promptPart.CanCollide, promptPart.CanTouch, promptPart.CanQuery = 1, false, false, false
    offer.WorldPrompt = self:_prompt(promptPart, "Steal prefab box", definition.Name, function(player)
        self:_request(player, "WildSteal", offer.Id)
    end, 0) -- No second client-side timer before the server's timed hold.
    offer.WorldPrompt.MaxActivationDistance = math.max(2,
        self.Context.Config.Game.InteractionRadius - (5.4 * self:_size(offer.Size) + 1))
    offer.Model, offer.WorldSize = model, offer.Size
    self.SiteOffers[offer.Id] = offer
    self:UpdateWild(offer)
    return model
end

function World:MovePrefab(offer, position)
    offer.Position = position
    if offer.Model then
        local current = offer.Model:GetPivot()
        offer.Model:PivotTo(CFrame.new(position + Vector3.new(0, 5 * self:_size(offer.Size), 0)) * current.Rotation)
    end
end

function World:RemovePrefab(offer)
    if offer.Model then offer.Model:Destroy(); offer.Model = nil end
    offer.WorldLabel, offer.WorldPrompt = nil, nil
    self.SiteOffers[offer.Id] = nil
end

function World:UpdateWild(offer)
    if not offer.Model then return end
    if offer.WorldSize ~= offer.Size then self:CreatePrefab(offer); return end
    local definition = self.Context.Config.HouseById[offer.DefinitionId]
    offer.WorldLabel.Text = definition.Name .. "\n" .. tostring(offer.Variant) .. " • " .. tostring(offer.Size)
        .. "\nSPEED " .. tostring(offer.RequiredSpeed or 20) .. "+" .. (offer.Busy and " • RESERVED" or " • GROWING")
    offer.WorldPrompt.Enabled = offer.Busy == nil or offer.Busy == false
end

function World:RestoreGuard(site)
    if site.GuardModel then site.GuardModel:PivotTo(site.GuardFrame) end
end

function World:UpdateStandings(players)
    local lines = { "TOWN STANDINGS" }
    for index, entry in ipairs(players) do
        if index > 7 then break end
        table.insert(lines, index .. ". " .. tostring(entry.Name) .. " • " .. Factory.Money(entry.Cash)
            .. " • " .. Factory.Money(entry.Income) .. "/s")
    end
    self.StandingsText.Text = table.concat(lines, "\n")
end

function World:Tick(dt)
    self.Accumulator += dt
    if self.Accumulator < 1 then return end
    self.Accumulator %= 1
    local rebuild = {}
    for player, records in pairs(self.Houses) do
        for _, state in pairs(records) do
            if state.Construction and (state.Record.BuildReadyAt or 0) <= self.Context.Clock() then
                table.insert(rebuild, { Player = player, Record = state.Record, Amount = state.Amount })
            else self:UpdateIncome(player, state.Record.Id, state.Amount) end
        end
    end
    for _, entry in ipairs(rebuild) do
        self:RenderHouse(entry.Player, entry.Record)
        self:UpdateIncome(entry.Player, entry.Record.Id, entry.Amount)
        if self.Context.Notify then self.Context.Notify(entry.Player, "Your " .. self.Context.Config.HouseById[entry.Record.DefinitionId].Name .. " is built and earning rent!", "Built") end
    end
end

function World:Release(player)
    self:ClearCarry(player)
    local plot = self:GetPlot(player)
    if plot then
        local ids = {}
        for uid in pairs(self.Houses[player] or {}) do table.insert(ids, uid) end
        for _, uid in ipairs(ids) do self:RemoveHouse(player, uid) end
        self:SetOwner(plot, nil)
        self:SetLock(plot, false, 0)
        self:_slots(plot, self.Context.Config.Game.StartingSlots)
        plot.TreadmillText.Text = "TREADMILL 1\nTrain to reach faster streets"
    end
    self.Assigned[player], self.Houses[player] = nil, nil
    self:SetCharacterGroup(player)
    local connection = self.CharacterConnections[player]
    if connection then connection:Disconnect(); self.CharacterConnections[player] = nil end
end

function World:Shutdown()
    local players = {}
    for player in pairs(self.Assigned) do table.insert(players, player) end
    for _, player in ipairs(players) do self:Release(player) end
    if self.Model then self.Model:Destroy(); self.Model = nil end
    self.Plots, self.WildSites, self.SiteOffers = {}, {}, {}
end

return World
