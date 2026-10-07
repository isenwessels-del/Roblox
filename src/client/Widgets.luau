--!nonstrict
-- UI construction and formatting only; no economy state is changed here.
local Widgets = {}
Widgets.Colors = {
    Background = Color3.fromRGB(224, 243, 255), Panel = Color3.fromRGB(250, 253, 255),
    Raised = Color3.fromRGB(231, 241, 249), Stroke = Color3.fromRGB(167, 197, 216),
    Text = Color3.fromRGB(24, 49, 70), Muted = Color3.fromRGB(68, 94, 111),
    Teal = Color3.fromRGB(74, 211, 177), Orange = Color3.fromRGB(255, 193, 82),
    Danger = Color3.fromRGB(255, 153, 158),
}

function Widgets.Make(className, properties, parent)
    local instance = Instance.new(className)
    for key, value in pairs(properties) do instance[key] = value end
    instance.Parent = parent
    return instance
end

function Widgets.Round(parent, radius)
    Widgets.Make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

function Widgets.Text(parent, text, height, color, size)
    return Widgets.Make("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or 24),
        Text = tostring(text), TextColor3 = color or Widgets.Colors.Text,
        Font = Enum.Font.GothamMedium, TextSize = size or 16, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

function Widgets.Button(parent, text, callback, color)
    local button = Widgets.Make("TextButton", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = color or Widgets.Colors.Raised,
        Text = text, TextColor3 = Widgets.Colors.Text, Font = Enum.Font.GothamBold,
        TextSize = 15, TextWrapped = true, AutoButtonColor = true, Selectable = true,
    }, parent)
    Widgets.Round(button, 8)
    button.Activated:Connect(callback)
    return button
end

function Widgets.Card(parent, height)
    local card = Widgets.Make("Frame", {
        Size = UDim2.new(1, -4, 0, height or 112), BackgroundColor3 = Widgets.Colors.Raised,
        BorderSizePixel = 0,
    }, parent)
    Widgets.Round(card)
    Widgets.Make("UIPadding", {
        PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
    }, card)
    Widgets.Make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, card)
    return card
end

function Widgets.List(parent, scrolling)
    local list = Widgets.Make(if scrolling then "ScrollingFrame" else "Frame", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
    }, parent)
    if scrolling then
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.CanvasSize = UDim2.new()
        list.ScrollBarThickness = 4
        list.ScrollBarImageColor3 = Widgets.Colors.Teal
        list.ScrollingDirection = Enum.ScrollingDirection.Y
    else
        list.Size = UDim2.new(1, 0, 0, 0)
        list.AutomaticSize = Enum.AutomaticSize.Y
    end
    Widgets.Make("UIListLayout", { Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    return list
end

function Widgets.Clear(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
end

function Widgets.Number(number)
    number = tonumber(number) or 0
    if number ~= number or math.abs(number) == math.huge then number = 0 end
    local abs = math.abs(number)
    for _, suffix in ipairs({ {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"} }) do
        if abs >= suffix[1] then return string.format("%.1f%s", number / suffix[1], suffix[2]) end
    end
    return tostring(math.floor(number))
end

function Widgets.Enabled(button, enabled)
    button.Active = enabled
    button.Selectable = enabled
    button.AutoButtonColor = enabled
    button.BackgroundTransparency = if enabled then 0 else 0.45
    button.TextTransparency = if enabled then 0 else 0.45
end

function Widgets.Color(hex)
    if typeof(hex) == "Color3" then return hex end
    if type(hex) == "string" then
        local clean = hex:gsub("#", "")
        if #clean == 6 then
            return Color3.fromRGB(tonumber(clean:sub(1, 2), 16) or 255,
                tonumber(clean:sub(3, 4), 16) or 255, tonumber(clean:sub(5, 6), 16) or 255)
        end
    end
    return Widgets.Colors.Muted
end

function Widgets.Actions(parent, leftText, leftCallback, rightText, rightCallback)
    local frame = Widgets.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38) }, parent)
    local left = Widgets.Button(frame, leftText, leftCallback)
    left.Size = UDim2.new(if rightText then 0.5 else 1, if rightText then -4 else 0, 1, 0)
    if rightText then
        local right = Widgets.Button(frame, rightText, rightCallback)
        right.Position, right.Size = UDim2.new(0.5, 4, 0, 0), UDim2.new(0.5, -4, 1, 0)
    end
    return left
end

return Widgets
