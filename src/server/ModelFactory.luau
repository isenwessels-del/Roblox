-- Built-in geometry only: every item has a recognizable silhouette without asset permissions.
local ModelFactory = {}

local DARK = Color3.fromRGB(31, 36, 47)
local WOOD = Color3.fromRGB(133, 91, 61)
local WHITE = Color3.fromRGB(222, 227, 228)
local RARITY = {
    Common = Color3.fromRGB(171, 184, 197), Uncommon = Color3.fromRGB(98, 205, 140),
    Rare = Color3.fromRGB(82, 156, 244), Epic = Color3.fromRGB(170, 105, 235),
    Legendary = Color3.fromRGB(255, 194, 77), Mythic = Color3.fromRGB(243, 89, 140),
    Secret = Color3.fromRGB(93, 235, 232),
}

function ModelFactory.Part(parent, name, size, cf, color, material)
    local part = Instance.new("Part")
    part.Name, part.Size, part.CFrame = name, size, cf
    part.Anchored, part.CanCollide, part.CanTouch = true, true, false
    part.Color, part.Material = color, material or Enum.Material.SmoothPlastic
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

function ModelFactory.Label(part, text, color, height, distance)
    local gui = Instance.new("BillboardGui")
    gui.Name, gui.Size = "Label", UDim2.fromOffset(220, 58)
    gui.StudsOffset = Vector3.new(0, height or 4, 0)
    gui.MaxDistance, gui.AlwaysOnTop = distance or 72, false
    gui.Parent = part
    local label = Instance.new("TextLabel")
    label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
    label.Text, label.TextColor3 = text, color or Color3.new(1, 1, 1)
    label.TextStrokeTransparency, label.TextStrokeColor3 = 0.3, DARK
    label.TextSize, label.Font = 16, Enum.Font.GothamBold
    label.TextWrapped, label.Parent = true, gui
    return label
end

function ModelFactory.Prompt(part, action, title, callback, duration, distance)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText, prompt.ObjectText = action, title
    prompt.HoldDuration, prompt.MaxActivationDistance = duration or 0, distance or 10
    prompt.RequiresLineOfSight = true
    prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
    prompt.Parent = part
    prompt.Triggered:Connect(callback)
    return prompt
end

function ModelFactory.Furniture(item, rarityConfig, parent, cf)
    local model = Instance.new("Model")
    model.Name = item.Id or item.ItemId or "Furniture"
    local accent = (rarityConfig and rarityConfig.Color) or RARITY[item.Rarity] or WHITE
    if type(accent) == "string" then accent = Color3.fromHex((string.gsub(accent, "#", ""))) end
    local id = string.lower(model.Name .. " " .. (item.ModelKind or ""))
    local category = string.lower(item.Category or "Furniture")
    local width, depth = (item.Size and item.Size.X) or item.Width or 3, (item.Size and item.Size.Z) or item.Depth or 3
    local primary
    local function p(name, x, y, z, sx, sy, sz, color, material)
        local part = ModelFactory.Part(model, name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), color, material)
        primary = primary or part
        return part
    end
    local function legs(top, w, d, height, color)
        for _, x in ipairs({ -w / 2 + 0.25, w / 2 - 0.25 }) do
            for _, z in ipairs({ -d / 2 + 0.25, d / 2 - 0.25 }) do
                p("Leg", x, top - height / 2, z, 0.25, height, 0.25, color)
            end
        end
    end
    if string.find(id, "toilet") then
        p("Pedestal", 0, 0.6, 0, width * 0.4, 1.2, depth * 0.45, WHITE)
        p("Bowl", 0, 1.45, -depth * 0.12, width * 0.8, 1.2, depth * 0.66, accent).Shape = Enum.PartType.Ball
        p("Seat", 0, 2, -depth * 0.12, width * 0.82, 0.2, depth * 0.65, WHITE)
        p("Tank", 0, 2.25, depth * 0.3, width * 0.72, 2, depth * 0.3, accent)
        p("Flush", width * 0.24, 2.7, depth * 0.13, 0.3, 0.2, 0.15, DARK)
    elseif string.find(id, "duck") or string.find(id, "chicken") then
        p("DisplayFoot", 0, 0.2, 0, width * 0.8, 0.4, depth * 0.8, DARK)
        p("Body", 0, 1.3, depth * 0.08, width * 0.78, 1.9, depth * 0.64, accent).Shape = Enum.PartType.Ball
        p("Head", 0, 2.55, -depth * 0.2, width * 0.45, 1.3, depth * 0.38, accent).Shape = Enum.PartType.Ball
        p("Beak", 0, 2.4, -depth * 0.42, width * 0.35, 0.25, depth * 0.12, Color3.fromRGB(255, 150, 67))
        for _, side in ipairs({ -1, 1 }) do
            p("Eye", side * width * 0.13, 2.8, -depth * 0.37, 0.14, 0.14, 0.1, DARK)
        end
        if string.find(id, "chicken") then
            p("Comb", 0, 3.2, -depth * 0.2, width * 0.2, 0.4, depth * 0.15, Color3.fromRGB(231, 81, 97))
        end
    elseif string.find(id, "dinosaur") or string.find(id, "dragon") then
        p("DisplayBase", 0, 0.2, 0, width, 0.4, depth, DARK)
        p("Body", 0, 1.6, 0, width * 0.64, 2.2, depth * 0.5, accent).Shape = Enum.PartType.Ball
        p("Neck", -width * 0.27, 2.8, -depth * 0.15, width * 0.16, 2, depth * 0.2, accent)
        p("Head", -width * 0.25, 3.7, -depth * 0.24, width * 0.38, 1, depth * 0.3, accent)
        p("Tail", width * 0.3, 1.7, depth * 0.18, width * 0.3, 0.6, depth * 0.2, accent)
        p("Eye", -width * 0.29, 3.9, -depth * 0.4, 0.16, 0.16, 0.1, DARK)
        for _, side in ipairs({ -1, 1 }) do
            p("Leg", side * width * 0.2, 0.8, 0, width * 0.12, 1.2, depth * 0.2, accent)
        end
    elseif string.find(id, "spoon") then
        p("Base", 0, 0.2, 0, width * 0.75, 0.4, depth, DARK)
        p("Handle", 0, 1.4, depth * 0.1, width * 0.15, 0.3, depth * 0.6, accent, Enum.Material.Metal)
        p("SpoonBowl", 0, 1.45, -depth * 0.3, width * 0.65, 0.5, depth * 0.34, accent, Enum.Material.Metal).Shape = Enum.PartType.Ball
    elseif string.find(id, "ufo") then
        local saucer = p("Saucer", 0, 1.7, 0, 0.55, width, depth, accent, Enum.Material.Metal)
        saucer.Shape = Enum.PartType.Cylinder
        saucer.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
        p("Dome", 0, 2.2, 0, width * 0.55, 1.4, depth * 0.55, Color3.fromRGB(115, 230, 205), Enum.Material.Glass).Shape = Enum.PartType.Ball
        for _, side in ipairs({ -1, 1 }) do
            p("LandingGear", side * width * 0.25, 0.7, 0, 0.3, 1.4, 0.3, DARK)
            p("Light", side * width * 0.3, 1.85, -depth * 0.3, 0.35, 0.2, 0.35, WHITE, Enum.Material.Neon)
        end
    elseif string.find(id, "aquarium") then
        p("Stand", 0, 0.6, 0, width * 0.85, 1.2, depth * 0.85, DARK)
        p("Tank", 0, 2.5, 0, width, 2.5, depth, Color3.fromRGB(86, 198, 217), Enum.Material.Glass).Transparency = 0.3
        p("Sand", 0, 1.3, 0, width * 0.95, 0.3, depth * 0.95, Color3.fromRGB(215, 192, 125))
        p("Top", 0, 3.8, 0, width, 0.2, depth, DARK)
        p("Fish", -width * 0.15, 2.5, 0, width * 0.25, 0.45, 0.4, accent)
        p("Fish", width * 0.21, 2.1, 0, width * 0.18, 0.3, 0.3, WHITE)
    elseif string.find(id, "piano") then
        p("Body", 0, 2.4, depth * 0.08, width, 1.7, depth * 0.7, accent)
        p("Keyboard", 0, 2.3, -depth * 0.32, width * 0.9, 0.18, depth * 0.25, WHITE)
        legs(1.6, width - 0.3, depth * 0.68, 1.6, DARK)
        for index = 1, 6 do
            p("BlackKey", -width * 0.43 + index * width * 0.12, 2.43, -depth * 0.25, 0.15, 0.08, depth * 0.12, DARK)
        end
    elseif string.find(id, "sofa") or string.find(id, "couch") then
        p("Seat", 0, 1.25, 0, width, 0.8, depth, accent)
        p("Back", 0, 2.25, depth / 2 - 0.3, width, 2, 0.6, accent)
        p("LeftArm", -width / 2 + 0.3, 1.7, 0, 0.6, 1.7, depth, accent)
        p("RightArm", width / 2 - 0.3, 1.7, 0, 0.6, 1.7, depth, accent)
        legs(0.9, width - 0.2, depth - 0.2, 0.7, DARK)
        p("Cushion", -width / 4, 1.8, 0, width / 2 - 0.3, 0.25, depth - 0.7, WHITE)
        p("Cushion", width / 4, 1.8, 0, width / 2 - 0.3, 0.25, depth - 0.7, WHITE)
    elseif string.find(id, "chair") or string.find(id, "throne") or string.find(id, "stool") then
        p("Seat", 0, 1.8, 0, width, 0.45, depth, accent)
        legs(1.6, width - 0.1, depth - 0.1, 1.6, DARK)
        if not string.find(id, "stool") then
            p("Back", 0, 3, depth / 2 - 0.15, width, 2.4, 0.35, accent)
            p("BackTrim", 0, 4.25, depth / 2 - 0.15, width + 0.1, 0.18, 0.4, DARK)
        end
        if string.find(id, "throne") or string.find(id, "gaming") then
            p("Arm", -width / 2 + 0.1, 2.4, 0, 0.3, 0.3, depth, DARK)
            p("Arm", width / 2 - 0.1, 2.4, 0, 0.3, 0.3, depth, DARK)
        end
    elseif string.find(id, "bed") then
        p("Frame", 0, 0.7, 0, width, 1, depth, WOOD)
        p("Mattress", 0, 1.4, 0, width - 0.3, 0.6, depth - 0.3, WHITE)
        p("Blanket", 0, 1.75, -depth / 6, width - 0.4, 0.12, depth * 0.62, accent)
        p("Headboard", 0, 1.9, depth / 2 - 0.15, width, 3, 0.4, WOOD)
        p("Pillow", -width / 4, 1.9, depth / 3, width * 0.38, 0.3, 1, WHITE)
        p("Pillow", width / 4, 1.9, depth / 3, width * 0.38, 0.3, 1, WHITE)
    elseif (string.find(id, "table") or string.find(id, "desk"))
        and not string.find(id, "lamp") and not string.find(id, "shelf") and not string.find(id, "book") and not string.find(id, "cabinet") then
        p("Top", 0, 2.8, 0, width, 0.4, depth, WOOD)
        legs(2.6, width - 0.2, depth - 0.2, 2.6, DARK)
        p("Trim", 0, 2.45, -depth / 2 + 0.15, width - 0.25, 0.35, 0.25, accent)
    elseif string.find(id, "shelf") or string.find(id, "book") or string.find(id, "cabinet") then
        p("Left", -width / 2 + 0.15, 2.5, 0, 0.3, 5, depth, WOOD)
        p("Right", width / 2 - 0.15, 2.5, 0, 0.3, 5, depth, WOOD)
        p("Back", 0, 2.5, depth / 2 - 0.1, width, 5, 0.2, WOOD)
        for y = 0.2, 4.8, 1.15 do p("Shelf", 0, y, 0, width, 0.2, depth, WOOD) end
        for index = 1, 4 do
            p("Book", -width / 2 + index * width / 5, 1.9, 0, width / 7, 1, depth * 0.65, if index % 2 == 0 then accent else WHITE)
        end
    elseif string.find(id, "lamp") then
        p("Base", 0, 0.15, 0, width * 0.65, 0.3, depth * 0.65, DARK)
        p("Stem", 0, 1.8, 0, 0.18, 3.3, 0.18, DARK, Enum.Material.Metal)
        p("Shade", 0, 3.7, 0, width, 1, depth, accent)
        p("Light", 0, 3.1, 0, width * 0.8, 0.12, depth * 0.8, Color3.fromRGB(255, 239, 160), Enum.Material.Neon)
    elseif string.find(id, "plant") or string.find(id, "bonsai") or string.find(id, "flower") or string.find(id, "tree") then
        p("Pot", 0, 0.65, 0, width * 0.65, 1.3, depth * 0.65, accent)
        p("Soil", 0, 1.32, 0, width * 0.6, 0.12, depth * 0.6, WOOD)
        p("Stem", 0, 2.2, 0, 0.22, 1.7, 0.22, WOOD)
        local leaf = p("Leaves", 0, 3.1, 0, width, 1.8, depth, Color3.fromRGB(62, 145, 95))
        leaf.Shape = Enum.PartType.Ball
        p("Branch", width * 0.14, 2.5, 0, width * 0.7, 0.6, depth * 0.7, Color3.fromRGB(93, 183, 111)).Shape = Enum.PartType.Ball
    elseif string.find(id, "statue") or string.find(id, "trophy") or string.find(id, "sculpt") then
        p("Plinth", 0, 0.35, 0, width, 0.7, depth, DARK, Enum.Material.Marble)
        p("Body", 0, 1.9, 0, width * 0.5, 2.4, depth * 0.4, accent, Enum.Material.Metal)
        p("Head", 0, 3.55, 0, width * 0.45, 1, depth * 0.45, accent, Enum.Material.Metal).Shape = Enum.PartType.Ball
        p("Arm", -width * 0.35, 2.5, 0, width * 0.24, 1.6, depth * 0.25, accent, Enum.Material.Metal)
        p("Arm", width * 0.35, 2.5, 0, width * 0.24, 1.6, depth * 0.25, accent, Enum.Material.Metal)
    elseif string.find(id, "painting") or string.find(id, "art") or string.find(id, "portrait") then
        p("Frame", 0, 2.5, depth * 0.2, width, 4, 0.35, WOOD)
        p("Canvas", 0, 2.5, depth * 0.2 - 0.21, width - 0.45, 3.55, 0.06, accent)
        p("AbstractSun", -width / 5, 3.15, depth * 0.2 - 0.27, width * 0.35, 1.1, 0.07, WHITE).Shape = Enum.PartType.Ball
        p("Stand", 0, 0.5, 0, 0.3, 1, 0.3, DARK)
        p("Foot", 0, 0.15, 0, width * 0.75, 0.3, depth, DARK)
    elseif string.find(id, "car") or string.find(id, "bike") or string.find(id, "scooter") or category == "vehicles" or category == "vehicle" then
        p("Body", 0, 1.25, 0, width * 0.95, 1.25, depth * 0.85, accent, Enum.Material.Metal)
        p("Cabin", 0, 2.35, depth * 0.05, width * 0.72, 1.4, depth * 0.4, DARK)
        p("Windshield", 0, 2.45, -depth * 0.16, width * 0.62, 0.8, 0.1, Color3.fromRGB(124, 207, 220), Enum.Material.Glass)
        for _, x in ipairs({ -width * 0.46, width * 0.46 }) do
            for _, z in ipairs({ -depth * 0.22, depth * 0.22 }) do
                local wheel = p("Wheel", x, 0.8, z, 0.45, 1.5, 1.5, DARK)
                wheel.Shape = Enum.PartType.Cylinder
            end
        end
        p("Headlight", -width * 0.27, 1.4, -depth * 0.43, 0.6, 0.35, 0.15, WHITE, Enum.Material.Neon)
        p("Headlight", width * 0.27, 1.4, -depth * 0.43, 0.6, 0.35, 0.15, WHITE, Enum.Material.Neon)
    elseif string.find(id, "fridge") or string.find(id, "refriger") or string.find(id, "washer") then
        p("Body", 0, 2.6, 0, width, 5.2, depth * 0.8, WHITE, Enum.Material.Metal)
        p("Door", 0, 2.6, -depth * 0.4 - 0.05, width - 0.25, 4.85, 0.12, accent)
        p("Handle", width * 0.3, 3, -depth * 0.4 - 0.15, 0.15, 1.4, 0.2, DARK)
        p("Seam", 0, 3.6, -depth * 0.4 - 0.11, width, 0.08, 0.12, DARK)
    elseif string.find(id, "oven") or string.find(id, "microwave") or string.find(id, "coffee") or category == "appliances" or category == "appliance" then
        p("Body", 0, 1.55, 0, width, 3.1, depth * 0.8, accent, Enum.Material.Metal)
        p("Window", 0, 1.45, -depth * 0.4 - 0.04, width * 0.78, 1.8, 0.1, DARK)
        p("Handle", 0, 2.5, -depth * 0.4 - 0.15, width * 0.6, 0.14, 0.2, WHITE)
        for _, x in ipairs({ -width / 4, width / 4 }) do
            p("Hotplate", x, 3.13, 0, width * 0.3, 0.1, depth * 0.45, DARK)
        end
    elseif string.find(id, "tv") or string.find(id, "screen") or string.find(id, "monitor") or string.find(id, "pc") or category == "electronics" then
        p("Stand", 0, 0.18, 0, width * 0.6, 0.35, depth * 0.6, DARK)
        p("Stem", 0, 0.8, 0, 0.35, 1, 0.35, DARK)
        p("ScreenFrame", 0, 2.25, 0, width, 2.6, 0.3, DARK)
        p("Display", 0, 2.25, -0.18, width - 0.25, 2.35, 0.08, accent, Enum.Material.Neon)
        p("ScreenGraphic", -width / 6, 2.25, -0.24, width * 0.35, 1.5, 0.04, WHITE)
        if string.find(id, "pc") or string.find(id, "computer") then
            p("Tower", width * 0.36, 0.75, depth * 0.26, width * 0.25, 1.5, depth * 0.38, DARK)
            p("RGB", width * 0.36, 0.85, depth * 0.26 - depth * 0.2, width * 0.15, 1.2, 0.04, accent, Enum.Material.Neon)
        end
    elseif string.find(id, "safe") or string.find(id, "vault") then
        p("Vault", 0, 2, 0, width, 4, depth, DARK, Enum.Material.Metal)
        p("Door", 0, 2, -depth / 2 - 0.08, width - 0.35, 3.65, 0.18, accent, Enum.Material.Metal)
        p("Dial", 0, 2.15, -depth / 2 - 0.23, 0.7, 0.7, 0.25, WHITE).Shape = Enum.PartType.Ball
    else
        -- Collectible display pieces use a pedestal and faceted jewel rather than a generic cube.
        p("Base", 0, 0.25, 0, width, 0.5, depth, WOOD)
        p("Pedestal", 0, 1.1, 0, width * 0.55, 1.2, depth * 0.55, DARK)
        local jewel = p("Collectible", 0, 2.4, 0, width * 0.65, 1.8, depth * 0.65, accent, Enum.Material.Metal)
        jewel.CFrame *= CFrame.Angles(0, math.pi / 4, math.pi / 12)
        p("Trim", 0, 1.85, 0, width * 0.8, 0.2, depth * 0.8, WHITE)
    end
    model.PrimaryPart = primary
    -- An exposed interaction point prevents a fridge door or mattress from hiding its own prompt.
    local attachment = Instance.new("Attachment")
    attachment.Name = "InteractionAttachment"
    attachment.Position = primary.CFrame:PointToObjectSpace((cf * CFrame.new(0, 5.8, 0)).Position)
    attachment.Parent = primary
    model:SetAttribute("ItemId", item.Id or item.ItemId)
    model:SetAttribute("Rarity", item.Rarity)
    if item.Rarity == "Legendary" or item.Rarity == "Mythic" or item.Rarity == "Secret" then
        local glow = Instance.new("Highlight")
        glow.Name, glow.FillTransparency = "RarityAccent", 0.93
        glow.OutlineColor, glow.OutlineTransparency = accent, 0.4
        glow.DepthMode, glow.Parent = Enum.HighlightDepthMode.Occluded, model
    end
    model.Parent = parent
    return model
end

return ModelFactory
