-- Procedural, bounded map. No toolbox models, mesh permissions or external assets are needed.
local Lighting = game:GetService("Lighting")
local Factory = require(script.Parent.ModelFactory)

local WorldService = {}
WorldService.__index = WorldService

local COLORS = {
    Asphalt = Color3.fromRGB(42, 48, 59), Pavement = Color3.fromRGB(191, 192, 179),
    Grass = Color3.fromRGB(104, 147, 95), Ink = Color3.fromRGB(32, 39, 54),
    Cream = Color3.fromRGB(239, 224, 194), Teal = Color3.fromRGB(49, 188, 177),
    Gold = Color3.fromRGB(250, 203, 100), Wood = Color3.fromRGB(146, 107, 76),
}
local DISTRICTS = {
    { Side = -1, Z = 0, Color = "#E7BF89", Ground = "#94B687", Landmark = "Water Tower" },
    { Side = 1, Z = 0, Color = "#99BBC4", Ground = "#A3B99B", Landmark = "Town Park" },
    { Side = -1, Z = -230, Color = "#BAB3CE", Ground = "#9FA5B1", Landmark = "Clock Tower" },
    { Side = 1, Z = -230, Color = "#F0DBAC", Ground = "#C7B991", Landmark = "Golden Fountain" },
    { Side = -1, Z = 230, Color = "#ABCAB3", Ground = "#95AA81", Landmark = "Diamond Monument" },
    { Side = 1, Z = 230, Color = "#756787", Ground = "#756980", Landmark = "Alien Beacon" },
}

local function color(hex)
    return Color3.fromHex((string.gsub(hex, "#", "")))
end

local function folder(parent, name)
    local obj = Instance.new("Folder")
    obj.Name, obj.Parent = name, parent
    return obj
end

local function model(parent, name)
    local obj = Instance.new("Model")
    obj.Name, obj.Parent = name, parent
    return obj
end

local function p(parent, name, size, position, tint, material)
    return Factory.Part(parent, name, size, CFrame.new(position), tint, material)
end

local function sign(parent, position, title, subtitle, tint, width)
    local board = p(parent, "Sign", Vector3.new(width or 18, 6, 0.45), position + Vector3.new(0, 7, 0), tint or COLORS.Ink)
    board.CanCollide = false
    local post = p(parent, "SignPost", Vector3.new(0.5, 5, 0.5), position + Vector3.new(0, 2.5, 0), COLORS.Wood, Enum.Material.Wood)
    post.CanCollide = false
    local surface = Instance.new("SurfaceGui")
    surface.Name, surface.Face, surface.CanvasSize = "SignText", Enum.NormalId.Front, Vector2.new(600, 200)
    surface.Parent = board
    local text = Instance.new("TextLabel")
    text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
    text.Text = title .. (if subtitle then "\n" .. subtitle else "")
    local boardColor = tint or COLORS.Ink
    text.TextColor3 = if boardColor.R * 0.3 + boardColor.G * 0.59 + boardColor.B * 0.11 > 0.55 then COLORS.Ink else COLORS.Cream
    text.TextScaled = true
    text.Font, text.Parent = Enum.Font.GothamBold, surface
    return board
end

local function tree(parent, position, tint)
    local trunk = p(parent, "TreeTrunk", Vector3.new(1.3, 6, 1.3), position + Vector3.new(0, 3, 0), COLORS.Wood, Enum.Material.Wood)
    local crown = p(parent, "TreeCrown", Vector3.new(9, 9, 9), position + Vector3.new(0, 8.5, 0), tint or Color3.fromRGB(73, 126, 87))
    crown.Shape = Enum.PartType.Ball
    trunk.CanCollide, crown.CanCollide = false, false
end

local function street(parent, x, z, width, depth)
    p(parent, "Street", Vector3.new(width, 0.18, depth), Vector3.new(x, 0.2, z), COLORS.Asphalt, Enum.Material.Asphalt)
    if width > depth then
        p(parent, "Sidewalk", Vector3.new(width, 0.35, 5), Vector3.new(x, 0.3, z - depth / 2 - 2.5), COLORS.Pavement, Enum.Material.Concrete)
        p(parent, "Sidewalk", Vector3.new(width, 0.35, 5), Vector3.new(x, 0.3, z + depth / 2 + 2.5), COLORS.Pavement, Enum.Material.Concrete)
        for offset = -width / 2 + 10, width / 2 - 10, 24 do
            p(parent, "LaneStripe", Vector3.new(10, 0.025, 0.35), Vector3.new(x + offset, 0.305, z), COLORS.Cream)
        end
    else
        p(parent, "Sidewalk", Vector3.new(5, 0.35, depth), Vector3.new(x - width / 2 - 2.5, 0.3, z), COLORS.Pavement, Enum.Material.Concrete)
        p(parent, "Sidewalk", Vector3.new(5, 0.35, depth), Vector3.new(x + width / 2 + 2.5, 0.3, z), COLORS.Pavement, Enum.Material.Concrete)
        for offset = -depth / 2 + 10, depth / 2 - 10, 24 do
            p(parent, "LaneStripe", Vector3.new(0.35, 0.025, 10), Vector3.new(x, 0.305, z + offset), COLORS.Cream)
        end
    end
end

-- A walk-through doorway and open roof keep every room readable from the Roblox camera.
local function shell(parent, origin, width, depth, tint, trim, upgraded)
    local floor = p(parent, "Floor", Vector3.new(width, 1, depth), origin - Vector3.new(0, 0.5, 0), COLORS.Cream, Enum.Material.WoodPlanks)
    local height, doorWidth = 10, 9
    p(parent, "BackWall", Vector3.new(width, height, 0.7), origin + Vector3.new(0, height / 2, depth / 2), tint)
    for _, side in ipairs({ -1, 1 }) do
        p(parent, "SideWall", Vector3.new(0.7, height, depth), origin + Vector3.new(side * width / 2, height / 2, 0), tint)
        p(parent, "FrontWall", Vector3.new((width - doorWidth) / 2, height, 0.7),
            origin + Vector3.new(side * (width + doorWidth) / 4, height / 2, -depth / 2), tint)
        p(parent, "WindowFrame", Vector3.new(5.3, 3.5, 0.3),
            origin + Vector3.new(side * width * 0.31, 5.5, -depth / 2 - 0.4), trim)
        p(parent, "WindowGlass", Vector3.new(4.65, 2.85, 0.15),
            origin + Vector3.new(side * width * 0.31, 5.5, -depth / 2 - 0.62), Color3.fromRGB(119, 186, 200), Enum.Material.Glass)
        p(parent, "WindowCross", Vector3.new(0.15, 2.85, 0.15),
            origin + Vector3.new(side * width * 0.31, 5.5, -depth / 2 - 0.74), trim)
        p(parent, "Column", Vector3.new(1.1, height + 0.5, 1.1),
            origin + Vector3.new(side * width / 2, height / 2, -depth / 2), trim)
    end
    p(parent, "DoorLintel", Vector3.new(doorWidth, 2, 0.75), origin + Vector3.new(0, height - 1, -depth / 2), trim)
    p(parent, "WelcomeMat", Vector3.new(8, 0.12, 3), origin + Vector3.new(0, 0.1, -depth / 2 + 2), trim)
    p(parent, "FrontStep", Vector3.new(10, 0.6, 3), origin + Vector3.new(0, -0.7, -depth / 2 - 1.5), COLORS.Pavement)
    p(parent, "BackCornice", Vector3.new(width + 1.5, 0.7, 1.5), origin + Vector3.new(0, height + 0.4, depth / 2), trim)
    for _, side in ipairs({ -1, 1 }) do
        p(parent, "SideCornice", Vector3.new(1.5, 0.7, depth + 1.5), origin + Vector3.new(side * width / 2, height + 0.4, 0), trim)
    end
    p(parent, "FrontCornice", Vector3.new(width + 1.5, 0.7, 1.5), origin + Vector3.new(0, height + 0.4, -depth / 2), trim)
    if upgraded then
        p(parent, "Rug", Vector3.new(width * 0.45, 0.08, depth * 0.45), origin + Vector3.new(0, 0.055, 1), trim)
    end
    return floor
end

function WorldService.new(ctx)
    return setmetatable({ ctx = ctx, Plots = {}, NPCs = {}, LootModels = {}, PoliceSpawnPositions = {},
        Metrics = { StaticParts = 0, NPCs = 0, SpawnPoints = 0, LootLive = 0, HomeRenders = 0 } }, WorldService)
end

function WorldService:_prompt(part, action, title, callbackAction, arguments, hold)
    local target = part:FindFirstChild("InteractionAttachment") or part
    return Factory.Prompt(target, action, title, function(player)
        self.ctx.Request(player, callbackAction, table.unpack(arguments or {}))
    end, hold or 0, self.ctx.Config.Game.InteractionDistance)
end

function WorldService:_landmark(parent, origin, definition)
    local name, tint = definition.Landmark, color(definition.Color)
    local landmark = model(parent, name)
    p(landmark, "Plaza", Vector3.new(32, 0.6, 28), origin + Vector3.new(0, 0.2, 0), COLORS.Pavement)
    if name == "Town Park" then
        p(landmark, "Lawn", Vector3.new(29, 0.2, 25), origin + Vector3.new(0, 0.6, 0), COLORS.Grass)
        tree(landmark, origin, Color3.fromRGB(70, 141, 105))
        p(landmark, "ParkBench", Vector3.new(8, 1, 3), origin + Vector3.new(0, 2, -9), COLORS.Wood)
        p(landmark, "ParkBenchBack", Vector3.new(8, 3, 0.5), origin + Vector3.new(0, 3, -7.5), COLORS.Wood)
    elseif name == "Golden Fountain" then
        p(landmark, "Basin", Vector3.new(17, 1.5, 17), origin + Vector3.new(0, 1, 0), tint, Enum.Material.Marble)
        p(landmark, "Water", Vector3.new(15, 0.2, 15), origin + Vector3.new(0, 1.85, 0), COLORS.Teal, Enum.Material.Glass)
        p(landmark, "Column", Vector3.new(2, 9, 2), origin + Vector3.new(0, 5.5, 0), COLORS.Gold, Enum.Material.Metal)
        p(landmark, "UpperBasin", Vector3.new(8, 1, 8), origin + Vector3.new(0, 10, 0), COLORS.Gold)
    elseif name == "Water Tower" or name == "Clock Tower" then
        for _, x in ipairs({ -4, 4 }) do
            for _, z in ipairs({ -4, 4 }) do
                p(landmark, "Support", Vector3.new(1, 16, 1), origin + Vector3.new(x, 8, z), COLORS.Ink)
            end
        end
        p(landmark, "Tower", Vector3.new(12, 10, 12), origin + Vector3.new(0, 20, 0), tint)
        p(landmark, "Cap", Vector3.new(14, 1, 14), origin + Vector3.new(0, 25.5, 0), COLORS.Ink)
        if name == "Clock Tower" then
            p(landmark, "ClockFace", Vector3.new(7, 7, 0.3), origin + Vector3.new(0, 20, -6.2), COLORS.Cream)
            p(landmark, "ClockHand", Vector3.new(0.3, 2.8, 0.3), origin + Vector3.new(0, 21.2, -6.4), COLORS.Ink)
            p(landmark, "ClockHand", Vector3.new(2.5, 0.3, 0.3), origin + Vector3.new(1, 20, -6.4), COLORS.Ink)
        end
    else
        p(landmark, "Pedestal", Vector3.new(9, 4, 9), origin + Vector3.new(0, 2.7, 0), COLORS.Ink)
        local jewel = p(landmark, "Beacon", Vector3.new(9, 9, 9), origin + Vector3.new(0, 10, 0),
            if name == "Alien Beacon" then Color3.fromRGB(103, 255, 207) else Color3.fromRGB(139, 217, 251), Enum.Material.Neon)
        jewel.CFrame *= CFrame.Angles(0, math.pi / 4, math.pi / 4)
    end
end

function WorldService:_npc(parent, areaIndex, houseIndex, definition)
    local area = self.ctx.Config.Game.Areas[areaIndex]
    local origin = Vector3.new(definition.Side * (260 + (houseIndex - 1) * 125), 1.2, definition.Z)
    local id = "NPC_" .. areaIndex .. "_" .. houseIndex
    local houseModel = model(parent, id)
    local width, depth = 46 + areaIndex * 2, 36 + areaIndex * 2
    local floor = shell(houseModel, origin, width, depth, color(definition.Color), COLORS.Ink, true)
    houseModel.PrimaryPart = floor
    houseModel:SetAttribute("Area", areaIndex)
    houseModel:SetAttribute("HouseId", id)
    -- Four corners + central display, all far enough apart for the largest 8x8 footprint.
    local slots = {
        { "EntryDisplay", Vector3.new(-8, 0, -depth / 2 + 4), { "Furniture", "Electronics" } },
        { "LivingRoom", Vector3.new(-width * 0.27, 0, -depth * 0.23), { "Furniture", "Electronics" } },
        { "Kitchen", Vector3.new(width * 0.27, 0, -depth * 0.23), { "Appliance" } },
        { "Bedroom", Vector3.new(-width * 0.27, 0, depth * 0.23), { "Furniture" } },
        { "Gallery", Vector3.new(width * 0.27, 0, depth * 0.23), { "Art", "Electronics" } },
        { "Centerpiece", Vector3.new(0, 0, depth * 0.16), { "Furniture", "Art", "Vehicle" } },
    }
    local points, markers = {}, folder(houseModel, "SpawnPoints")
    for _, slot in ipairs(slots) do
        local point = {
            Id = slot[1], Position = origin + slot[2], Categories = slot[3],
            MinRarity = area.MinRarity, MaxRarity = area.MaxRarity, Probability = 1,
        }
        table.insert(points, point)
        local marker = p(markers, point.Id, Vector3.new(1, 0.1, 1), point.Position, COLORS.Teal)
        marker.Transparency, marker.CanCollide = 1, false
    end
    local entry = origin + Vector3.new(0, 0, -depth / 2 - 4)
    local threshold = p(houseModel, "RobberyEntrance", Vector3.new(8, 0.15, 3), entry, COLORS.Gold)
    local display = area.Name .. " • House " .. houseIndex
    Factory.Label(threshold, "ROB " .. display .. "\nLevel " .. area.RequiredLevel .. " • Security " .. area.Difficulty, COLORS.Gold, 6, 95)
    self:_prompt(threshold, "Start robbery", display, "EnterHouse", { id })
    local panelPosition = entry + Vector3.new(6, 2.5, 0)
    local panel = p(houseModel, "SecurityPanel", Vector3.new(1.6, 2, 0.7), panelPosition, COLORS.Ink, Enum.Material.Metal)
    local panelScreen = p(houseModel, "SecurityPanelScreen", Vector3.new(1.1, 1.2, 0.1), panelPosition + Vector3.new(0, 0, -0.45),
        Color3.fromRGB(235, 110, 107), Enum.Material.Neon)
    panelScreen.CanCollide, panelScreen.CanQuery = false, false
    self:_prompt(panel, "Disable security", "Security " .. area.Difficulty, "DisableSecurity", { id }, 0.75)
    local house = {
        Id = id, Origin = origin, Area = areaIndex, Difficulty = area.Difficulty,
        Model = houseModel, EntryPosition = entry, SpawnPoints = points,
        Width = width, Depth = depth,
    }
    self.NPCs[id] = house
    self.Metrics.NPCs += 1
    self.Metrics.SpawnPoints += #points
    table.insert(self.PoliceSpawnPositions, Vector3.new(origin.X + 55, 3.5, definition.Z - 55))
    table.insert(self.PoliceSpawnPositions, Vector3.new(origin.X - 55, 3.5, definition.Z - 55))
end

function WorldService:Init()
    local existing = workspace:FindFirstChild("StealAHouse")
    if existing then existing:Destroy() end
    table.clear(self.Plots)
    table.clear(self.NPCs)
    table.clear(self.LootModels)
    table.clear(self.PoliceSpawnPositions)
    self.Metrics = { StaticParts = 0, NPCs = 0, SpawnPoints = 0, LootLive = 0, HomeRenders = 0 }
    local map = folder(workspace, "StealAHouse")
    self.Map = map
    Lighting.ClockTime, Lighting.Brightness = 14, 2
    Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(147, 155, 178), Color3.fromRGB(173, 185, 194)
    Lighting.FogStart, Lighting.FogEnd = 800, 1700
    Lighting.GlobalShadows = true
    p(map, "Ground", Vector3.new(1220, 2, 850), Vector3.new(0, -1, 0), COLORS.Grass, Enum.Material.Grass)
    for _, data in ipairs({
        { Vector3.new(1220, 80, 2), Vector3.new(0, 35, -425) },
        { Vector3.new(1220, 80, 2), Vector3.new(0, 35, 425) },
        { Vector3.new(2, 80, 850), Vector3.new(-610, 35, 0) },
        { Vector3.new(2, 80, 850), Vector3.new(610, 35, 0) },
    }) do
        local boundary = p(map, "MapBoundary", data[1], data[2], COLORS.Grass)
        boundary.Transparency = 1
    end
    local roads = folder(map, "Roads")
    street(roads, 0, 0, 20, 680)
    street(roads, 0, -135, 370, 19)
    street(roads, 0, 125, 370, 19)
    street(roads, -190, -5, 17, 590)
    street(roads, 190, -5, 17, 590)
    local spawn = Instance.new("SpawnLocation")
    spawn.Name, spawn.Size, spawn.CFrame = "TownSpawn", Vector3.new(12, 1, 12), CFrame.new(0, 1, -5)
    spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
    spawn.Color, spawn.Material = COLORS.Teal, Enum.Material.Neon
    spawn.Parent = map
    sign(map, Vector3.new(0, 0, 18), "STEAL A HOUSE", "STEAL • ESCAPE • BUILD • PROTECT", COLORS.Ink, 32)
    sign(map, Vector3.new(-52, 0, -7), "← STARTER STREET", "Start a robbery at a yellow doorstep", COLORS.Teal, 25)
    sign(map, Vector3.new(51, 0, -7), "HOME DISTRICT", "Return to your green pad to secure loot", COLORS.Ink, 25)
    local playerPlots = folder(map, "PlayerPlots")
    for index = 1, self.ctx.Config.Game.MaxPlayers do
        local x = ((index - 1) % 4 - 1.5) * self.ctx.Config.Game.PlotSpacing
        local z = if index <= 4 then -72 else 72
        local origin = Vector3.new(x, 1.2, z)
        local plotModel = model(playerPlots, "Plot" .. index)
        p(plotModel, "PlotBase", Vector3.new(72, 0.7, 72), Vector3.new(x, 0.35, z), COLORS.Pavement, Enum.Material.Concrete)
        for _, side in ipairs({ -1, 1 }) do
            local hedge = p(plotModel, "Hedge", Vector3.new(1.5, 2, 70), origin + Vector3.new(side * 35, 0.2, 0), COLORS.Grass)
            hedge.CanCollide = false
        end
        local homepad = p(plotModel, "HomePad", Vector3.new(9, 0.2, 6), origin + Vector3.new(0, 0.05, -32), COLORS.Teal, Enum.Material.Neon)
        local title = Factory.Label(homepad, "Available plot", COLORS.Cream, 4, 85)
        self:_prompt(homepad, "Secure loot / open home", "Your home", "Escape", {})
        self.Plots[index] = { Id = index, Origin = origin, Model = plotModel, HomePad = homepad, Title = title, Owner = nil }
    end
    local districts = folder(map, "Districts")
    for areaIndex, definition in ipairs(DISTRICTS) do
        local area = self.ctx.Config.Game.Areas[areaIndex]
        local areaFolder = folder(districts, area.Name)
        p(areaFolder, "DistrictGround", Vector3.new(405, 0.15, 170),
            Vector3.new(definition.Side * 395, 0.1, definition.Z + 20), color(definition.Ground))
        street(roads, definition.Side * 390, definition.Z - 55, 420, 18)
        sign(areaFolder, Vector3.new(definition.Side * 218, 0, definition.Z - 40),
            string.upper(area.Name), "LEVEL " .. area.RequiredLevel .. " • SECURITY " .. area.Difficulty, color(definition.Color), 23)
        for houseIndex = 1, 3 do self:_npc(areaFolder, areaIndex, houseIndex, definition) end
        self:_landmark(areaFolder, Vector3.new(definition.Side * 390, 0, definition.Z + 66), definition)
        for treeIndex = 1, 4 do
            tree(areaFolder, Vector3.new(definition.Side * (235 + treeIndex * 80), 0, definition.Z + 98))
        end
    end
    local shop = model(map, "LootExchange")
    local shopOrigin = Vector3.new(0, 1.2, 166)
    shell(shop, shopOrigin, 58, 26, Color3.fromRGB(208, 227, 215), COLORS.Teal, false)
    local desk = p(shop, "ExchangeCounter", Vector3.new(18, 3, 3), shopOrigin + Vector3.new(0, 1.5, 4), COLORS.Teal)
    self.ShopPosition = Vector3.new(0, 1.2, 146)
    local shopPad = p(shop, "ShopEntrance", Vector3.new(8, 0.15, 5), self.ShopPosition, COLORS.Gold)
    self:_prompt(shopPad, "Sell / upgrade / shop", "Loot Exchange", "OpenShop", {})
    self:_prompt(desk, "Sell / upgrade / shop", "Loot Exchange", "OpenShop", {})
    sign(shop, Vector3.new(0, 0, 150), "LOOT EXCHANGE", "Sell loot • Buy upgrades • Get rich", COLORS.Teal, 31)
    Factory.Label(spawn, "Welcome! Find a yellow doorstep.\nYour home is a green safe zone.", COLORS.Cream, 3, 65)
    for _, object in ipairs(map:GetDescendants()) do
        if object:IsA("BasePart") then self.Metrics.StaticParts += 1 end
    end
end

function WorldService:Assign(player)
    local assigned = self:GetPlot(player)
    if assigned then return assigned end
    for _, plot in ipairs(self.Plots) do
        if not plot.Owner then
            plot.Owner = player
            plot.Model:SetAttribute("OwnerId", player.UserId)
            plot.Title.Text = player.DisplayName .. "'s home\nReturn here to secure loot"
            return plot
        end
    end
    return nil
end

function WorldService:GetPlot(player)
    for _, plot in ipairs(self.Plots) do
        if plot.Owner == player then return plot end
    end
    return nil
end

function WorldService:Release(playerOrPlot)
    local plot = if type(playerOrPlot) == "table" and playerOrPlot.Model then playerOrPlot else self:GetPlot(playerOrPlot)
    if not plot then return end
    local home = plot.Model:FindFirstChild("Home")
    if home then home:Destroy() end
    plot.Owner, plot.Width, plot.Depth = nil, nil, nil
    plot.Model:SetAttribute("OwnerId", nil)
    plot.Title.Text = "Available plot"
end

function WorldService:RenderHome(player, profile)
    local plot = self:GetPlot(player)
    if not plot then return end
    self.Metrics.HomeRenders += 1
    local previous = plot.Model:FindFirstChild("Home")
    if previous then previous:Destroy() end
    local house = profile.House
    local tier = self.ctx.Config.Houses[house.Tier] or self.ctx.Config.Houses[1]
    local theme = self.ctx.Config.Game.Themes[house.Theme] or self.ctx.Config.Game.Themes.Default
    local home = model(plot.Model, "Home")
    plot.Width, plot.Depth = tier.Width, tier.Depth
    local floor = shell(home, plot.Origin, tier.Width, tier.Depth, color(theme.Color), COLORS.Ink, house.Tier >= 2)
    home.PrimaryPart = floor
    home:SetAttribute("OwnerId", player.UserId)
    home:SetAttribute("HouseTier", house.Tier)
    local displayed = folder(home, "Furniture")
    for uniqueId, placement in pairs(house.Furniture) do
        local item = self.ctx.Config.Items[placement.ItemId]
        if item then
            local cf = CFrame.new(plot.Origin + Vector3.new(placement.X, 0, placement.Z)) * CFrame.Angles(0, math.rad(placement.Rotation), 0)
            local furniture = Factory.Furniture(item, self.ctx.Config.Rarities[item.Rarity], displayed, cf)
            furniture.Name = uniqueId
            furniture:SetAttribute("UniqueId", uniqueId)
            furniture:SetAttribute("OwnerId", player.UserId)
            self:_prompt(furniture.PrimaryPart, "Pick up / inspect", item.Name, "Pickup", { uniqueId, player.UserId })
        end
    end
    local securityLevel = house.SecurityLevel or 1
    local security = self.ctx.Config.Security[securityLevel]
    local devicePosition = plot.Origin + Vector3.new(tier.Width / 2 - 3, 3.5, -tier.Depth / 2 - 0.7)
    local device = p(home, "SecurityDevice", Vector3.new(2, 1.5, 1.2), devicePosition, COLORS.Ink, Enum.Material.Metal)
    local lens = p(home, "SecurityLens", Vector3.new(0.7, 0.7, 0.2), devicePosition + Vector3.new(0, 0, -0.75), COLORS.Teal, Enum.Material.Neon)
    lens.CanCollide, lens.CanQuery = false, false
    device:SetAttribute("OwnerId", player.UserId)
    self:_prompt(device, "View / upgrade security", security.Name, "InspectSecurity", { player.UserId })
    if securityLevel >= 6 then
        for _, x in ipairs({ -3.5, 3.5 }) do
            local beam = p(home, "SecurityLaser", Vector3.new(0.08, 5, 0.08),
                plot.Origin + Vector3.new(x, 2.6, -tier.Depth / 2 + 0.3), Color3.fromRGB(255, 86, 119), Enum.Material.Neon)
            beam.CanCollide = false
        end
    end
    if securityLevel >= 7 then
        p(home, "SecurityDrone", Vector3.new(3, 0.65, 3),
            plot.Origin + Vector3.new(tier.Width / 2 - 5, 8, -tier.Depth / 2 + 4), COLORS.Ink, Enum.Material.Metal)
    end
    plot.Title.Text = player.DisplayName .. "'s " .. tier.Name .. "\nSafe zone • Security " .. securityLevel
end

function WorldService:IsInHome(player, position)
    local plot = self:GetPlot(player)
    if not plot then return false end
    local delta = position - plot.Origin
    local inside = math.abs(delta.X) <= (plot.Width or 30) / 2 + 3
        and delta.Z >= -(plot.Depth or 24) / 2 - 4 and delta.Z <= (plot.Depth or 24) / 2 + 3
        and delta.Y >= -3 and delta.Y <= 20
    local padDelta = position - plot.HomePad.Position
    local atPad = math.abs(padDelta.X) <= 8 and math.abs(padDelta.Z) <= 8 and padDelta.Y >= -3 and padDelta.Y <= 12
    return inside or atPad
end

function WorldService:GetNPC(id)
    return self.NPCs[id]
end

function WorldService:GetNPCAt(position)
    for _, house in pairs(self.NPCs) do
        local delta = position - house.Origin
        if math.abs(delta.X) <= house.Width / 2 and math.abs(delta.Z) <= house.Depth / 2
            and delta.Y >= -2 and delta.Y <= 16 then return house end
    end
    return nil
end

function WorldService:RenderLoot(record)
    self:RemoveLoot(record)
    local house = self:GetNPC(record.HouseId)
    local item = self.ctx.Config.Items[record.ItemId]
    if not house or not item then return nil end
    local lootFolder = house.Model:FindFirstChild("Loot") or folder(house.Model, "Loot")
    local loot = Factory.Furniture(item, self.ctx.Config.Rarities[item.Rarity], lootFolder, CFrame.new(record.Position))
    loot.Name = record.UniqueId
    loot:SetAttribute("UniqueId", record.UniqueId)
    loot:SetAttribute("HouseId", record.HouseId)
    Factory.Label(loot.PrimaryPart, item.Name .. "\n" .. item.Rarity .. " • $" .. tostring(item.Value),
        color(self.ctx.Config.Rarities[item.Rarity].Color), 4, 36)
    self:_prompt(loot.PrimaryPart, "Steal", item.Name .. " • " .. item.Rarity, "Steal", { record.UniqueId }, 0.2)
    self.LootModels[record.UniqueId] = loot
    self.Metrics.LootLive += 1
    return loot
end

function WorldService:RemoveLoot(record)
    local uniqueId = if type(record) == "table" then record.UniqueId else record
    local existing = self.LootModels[uniqueId]
    if existing then existing:Destroy(); self.Metrics.LootLive -= 1 end
    self.LootModels[uniqueId] = nil
end

function WorldService:Shutdown()
    if self.Map then self.Map:Destroy() end
    table.clear(self.Plots)
    table.clear(self.NPCs)
    table.clear(self.LootModels)
    table.clear(self.PoliceSpawnPositions)
    self.Metrics.LootLive = 0
end

return WorldService
