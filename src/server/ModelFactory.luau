--!nonstrict
-- Original primitive scenery, without asset IDs or Toolbox dependencies.
local Factory = {}

function Factory.Color(value, fallback)
    if typeof(value) == "Color3" then return value end
    if type(value) == "string" then
        local hex = value:gsub("#", "")
        if #hex == 6 and tonumber(hex, 16) then
            return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
        end
    end
    return fallback or Color3.fromRGB(125, 183, 235)
end

function Factory.Part(parent, name, size, frame, color, material)
    local part = Instance.new("Part")
    part.Name, part.Size, part.CFrame = name, size, frame
    part.Anchored = true
    part.Color = Factory.Color(color)
    part.Material = material or Enum.Material.SmoothPlastic
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

function Factory.Model(parent, name)
    local model = Instance.new("Model")
    model.Name, model.Parent = name, parent
    return model
end

function Factory.Anchor(model, frame)
    local anchor = Factory.Part(model, "Interaction", Vector3.new(1, 1, 1), frame, "FFFFFF")
    anchor.Transparency, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = 1, false, false, false
    model.PrimaryPart = anchor
    return anchor
end

function Factory.Label(part, text, color, height, maxDistance)
    local gui = Instance.new("BillboardGui")
    gui.Name = "Label"
    gui.Size = UDim2.fromOffset(260, height or 72)
    gui.StudsOffset = Vector3.new(0, 3.2, 0)
    gui.MaxDistance, gui.AlwaysOnTop = maxDistance or 130, false
    gui.Adornee, gui.Parent = part, part
    local label = Instance.new("TextLabel")
    label.Name, label.Size = "Text", UDim2.fromScale(1, 1)
    label.BackgroundColor3, label.BackgroundTransparency = Color3.fromRGB(23, 30, 49), 0.15
    label.TextColor3, label.Text = Factory.Color(color, Color3.new(1, 1, 1)), text
    label.Font, label.TextSize, label.TextWrapped = Enum.Font.GothamBold, 18, true
    label.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius, corner.Parent = UDim.new(0, 9), label
    return label
end

function Factory.Prompt(part, action, object, radius, hold, callback)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name, prompt.ActionText, prompt.ObjectText = "Interact", action, object
    prompt.MaxActivationDistance, prompt.HoldDuration = radius or 12, hold or 0
    prompt.RequiresLineOfSight = true
    prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
    prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
    prompt.Parent = part
    if callback then prompt.Triggered:Connect(callback) end
    return prompt
end

function Factory.Money(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local scales = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
    for _, scale in ipairs(scales) do
        if amount >= scale[1] then return "$" .. string.format("%.1f", amount / scale[1]) .. scale[2] end
    end
    return "$" .. tostring(amount)
end

local function localPart(model, name, size, frame, offset, color, scale, rotation, material)
    return Factory.Part(model, name, size * scale,
        frame * CFrame.new(offset * scale) * (rotation or CFrame.new()), color, material)
end

local function windows(model, frame, scale, width, height, depth, floors)
    for row = 1, floors do
        for _, x in ipairs({ -width * 0.27, width * 0.27 }) do
            local pane = localPart(model, "Window", Vector3.new(2.2, 2.2, 0.16), frame,
                Vector3.new(x, height * row / (floors + 1) + 0.6, -depth / 2 - 0.08), "BCF3FF", scale)
            pane.Material, pane.CanCollide = Enum.Material.Glass, false
        end
    end
    localPart(model, "Door", Vector3.new(2.2, 3.7, 0.25), frame,
        Vector3.new(0, 2.2, -depth / 2 - 0.14), "513828", scale)
    localPart(model, "Doorstep", Vector3.new(4, 0.4, 2.5), frame,
        Vector3.new(0, 0.3, -depth / 2 - 1.1), "EBE4D7", scale)
end

function Factory.House(parent, name, frame, definition, variant, scale, construction)
    local model = Factory.Model(parent, name)
    scale = math.clamp(scale or 1, 0.2, 2)
    local body = Factory.Color(definition.Color)
    local trim = Factory.Color(variant and variant.Color, Color3.fromRGB(248, 243, 229))
    local anchor = Factory.Anchor(model, frame * CFrame.new(0, 5 * scale, 0))
    if construction then
        localPart(model, "PrefabBox", Vector3.new(11, 7, 10), frame, Vector3.new(0, 3.8, 0), "C89761", scale)
        localPart(model, "Strap", Vector3.new(1.2, 7.2, 10.2), frame, Vector3.new(0, 3.8, 0), trim, scale)
        localPart(model, "CrossStrap", Vector3.new(11.2, 7.2, 1.2), frame, Vector3.new(0, 3.8, 0), trim, scale)
        localPart(model, "ShippingLabel", Vector3.new(5, 2.8, 0.15), frame, Vector3.new(0, 4, -5.12), "FFF2C8", scale)
        return model, anchor
    end
    local style = string.lower(tostring(definition.Style or "cottage"))
    local width, height, depth, floors = 12, 8, 10, 1
    if style:find("tower") or style:find("town") or style:find("skyscraper") then
        width, height, depth, floors = 9, 15, 9, 3
    elseif style:find("modern") or style:find("villa") or style:find("penthouse") then
        width, height, depth, floors = 12, 10, 10, 2
    elseif style:find("castle") or style:find("palace") or style:find("temple") then
        width, height, depth, floors = 11, 10, 9, 2
    end
    localPart(model, "Foundation", Vector3.new(width + 1.5, 0.65, depth + 1.5), frame,
        Vector3.new(0, 0.45, 0), "DDD8CA", scale)
    localPart(model, "Walls", Vector3.new(width, height, depth), frame,
        Vector3.new(0, height / 2 + 0.7, 0), body, scale)
    windows(model, frame, scale, width, height, depth, floors)
    if style:find("castle") or style:find("palace") or style:find("temple") then
        for _, x in ipairs({ -6, 6 }) do
            localPart(model, "Turret", Vector3.new(3.8, 13, 4), frame, Vector3.new(x, 7, 0), trim, scale)
            for _, z in ipairs({ -1.5, 1.5 }) do
                localPart(model, "Battlement", Vector3.new(1.1, 1.8, 1), frame, Vector3.new(x, 14, z), body, scale)
            end
        end
        localPart(model, "Roof", Vector3.new(width, 0.6, depth), frame,
            Vector3.new(0, height + 1, 0), trim, scale)
    elseif style:find("modern") or style:find("villa") or style:find("penthouse")
        or style:find("tower") or style:find("town") or style:find("skyscraper") then
        localPart(model, "FlatRoof", Vector3.new(width + 1, 0.65, depth + 1), frame,
            Vector3.new(0, height + 1, 0), trim, scale)
        if floors == 2 then
            localPart(model, "Balcony", Vector3.new(width + 1, 0.5, 2.5), frame,
                Vector3.new(0, height * 0.58, -depth / 2 - 0.8), trim, scale)
        else
            localPart(model, "RoofAntenna", Vector3.new(0.3, 4, 0.3), frame,
                Vector3.new(2, height + 3, 1), trim, scale)
        end
    else
        for _, side in ipairs({ -1, 1 }) do
            localPart(model, "SlopedRoof", Vector3.new(width * 0.61, 0.65, depth + 2), frame,
                Vector3.new(side * width * 0.25, height + 1.5, 0), trim, scale,
                CFrame.Angles(0, 0, math.rad(-side * 26)))
        end
        localPart(model, "Chimney", Vector3.new(1.4, 3, 1.4), frame,
            Vector3.new(3.5, height + 2.5, 2), "795C4B", scale)
    end
    return model, anchor
end

function Factory.Landlord(parent, frame, color, tier)
    local model = Factory.Model(parent, "Landlord")
    localPart(model, "Coat", Vector3.new(3, 3.5, 1.7), frame, Vector3.new(0, 3.5, 0), color, 1)
    localPart(model, "Head", Vector3.new(2.3, 2.3, 2.3), frame, Vector3.new(0, 6.4, 0), "E5BA91", 1)
    localPart(model, "Hat", Vector3.new(3, 0.8, 2.8), frame, Vector3.new(0, 7.8, 0), "243149", 1)
    for _, x in ipairs({ -0.8, 0.8 }) do
        localPart(model, "Leg", Vector3.new(1.1, 2.3, 1.3), frame, Vector3.new(x, 1.25, 0), "243149", 1)
        localPart(model, "Arm", Vector3.new(0.9, 3, 1), frame, Vector3.new(x * 2.25, 3.5, 0), color, 1)
        localPart(model, "Eye", Vector3.new(0.2, 0.3, 0.15), frame, Vector3.new(x * 0.65, 6.7, -1.2), "243149", 1)
    end
    local anchor = Factory.Anchor(model, frame)
    local label = Factory.Label(anchor, "LANDLORD " .. tostring(tier) .. "\nProtecting prefab houses", "FFD68A", 60, 95)
    label.Parent.StudsOffset = Vector3.new(0, 10, 0)
    -- The server moves this anchored model. Contact is checked by GuardService;
    -- collidable moving scenery must not fling or trap player characters.
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide, part.CanTouch = false, false end
    end
    return model
end

return Factory
