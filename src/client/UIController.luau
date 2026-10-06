--!nonstrict
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local W = require(script.Parent.Widgets)
local C = W.Colors
local UI = {}
UI.__index = UI

function UI.new(ctx)
    local self = setmetatable({ Context = ctx, Builders = {}, ActiveMenu = nil }, UI)
    self.Gui = W.Make("ScreenGui", { Name = "StealAHouseUI", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10 }, Players.LocalPlayer:WaitForChild("PlayerGui"))
    local hud = W.Make("Frame", { Size = UDim2.new(1, -24, 0, 98), Position = UDim2.fromOffset(12, 10),
        BackgroundColor3 = C.Background, BackgroundTransparency = 0.08, BorderSizePixel = 0 }, self.Gui)
    W.Round(hud, 14)
    self.Brand = W.Text(hud, "STEAL A HOUSE", 27, C.Teal, 19)
    self.Brand.Position, self.Brand.Size = UDim2.fromOffset(12, 5), UDim2.new(0.6, -12, 0, 27)
    self.Connection = W.Text(hud, "Loading your home...", 24, C.Muted, 12)
    self.Connection.Position, self.Connection.Size, self.Connection.TextXAlignment = UDim2.new(0.55, 0, 0, 7), UDim2.new(0.45, -12, 0, 24), Enum.TextXAlignment.Right
    self.Stats = {}
    for i, label in ipairs({ "CASH", "GEMS", "LEVEL", "HOME VALUE" }) do
        local stat = W.Text(hud, label .. "  --", 27, if i == 1 then C.Orange else C.Text, 14)
        stat.Size, stat.Position = UDim2.new(0.25, -12, 0, 27), UDim2.new((i - 1) * 0.25, 12, 0, 35)
        self.Stats[i] = stat
    end
    self.HeatBar, self.HeatText = self:Meter(hud, 0, C.Danger, "HEAT 0 / 100")
    self.BagBar, self.BagText = self:Meter(hud, 0.5, C.Teal, "BAG 0 / 5")
    self.Objective = W.Make("TextLabel", { Position = UDim2.fromOffset(12, 117), Size = UDim2.new(1, -24, 0, 51),
        BackgroundColor3 = C.Panel, BorderSizePixel = 0, TextColor3 = C.Text, Font = Enum.Font.GothamMedium,
        TextSize = 14, TextWrapped = true, Text = "STEAL. ESCAPE. BUILD. PROTECT." }, self.Gui)
    W.Round(self.Objective)
    self.Tabs = W.Make("ScrollingFrame", { BackgroundColor3 = C.Background, BorderSizePixel = 0,
        Size = UDim2.new(1, -24, 0, 56), Position = UDim2.new(0, 12, 1, -67),
        CanvasSize = UDim2.new(0, 700, 0, 0), ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarImageColor3 = C.Teal }, self.Gui)
    W.Round(self.Tabs)
    self.TabButtons = {}
    for i, name in ipairs({ "Inventory", "House", "Shop", "Collection", "Quests", "Settings", "Leaderboard" }) do
        local button = W.Button(self.Tabs, name, function() self:ToggleMenu(name) end)
        button.Size, button.Position = UDim2.fromOffset(94, 42), UDim2.fromOffset(5 + (i - 1) * 99, 5)
        self.TabButtons[name] = button
    end
    self.Menu = W.Make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
        Size = UDim2.fromOffset(680, 520), BackgroundColor3 = C.Panel, BorderSizePixel = 0, Visible = false }, self.Gui)
    W.Round(self.Menu, 14)
    W.Make("UIStroke", { Color = C.Stroke, Thickness = 1 }, self.Menu)
    self.Title = W.Text(self.Menu, "Inventory", 42, C.Teal, 22)
    self.Title.Size, self.Title.Position = UDim2.new(1, -85, 0, 42), UDim2.fromOffset(18, 4)
    local close = W.Button(self.Menu, "X", function() self:CloseMenu() end)
    close.Size, close.Position = UDim2.fromOffset(40, 34), UDim2.new(1, -49, 0, 8)
    self.Content = W.List(self.Menu, true)
    self.Content.Position, self.Content.Size = UDim2.fromOffset(15, 56), UDim2.new(1, -30, 1, -69)
    self.Loading = W.Make("TextLabel", { BackgroundColor3 = C.Background, BackgroundTransparency = 0.05,
        Size = UDim2.fromScale(1, 1), TextColor3 = C.Teal, Font = Enum.Font.GothamBold, TextSize = 26,
        Text = "STEAL A HOUSE\n\nLoading your home and collection...", TextWrapped = true, ZIndex = 20 }, self.Gui)
    task.delay(15, function()
        if self.Loading.Parent and self.Loading.Visible then self.Loading.Text = "STEAL A HOUSE\n\nStill loading. Waiting for the server..." end
    end)
    local function resize()
        local camera = workspace.CurrentCamera
        local size = if camera then camera.ViewportSize else Vector2.new(1024, 768)
        self.Menu.Size = UDim2.fromOffset(math.min(680, size.X - 24), math.max(130, math.min(530, size.Y - 210)))
        self.Tabs.CanvasSize = UDim2.fromOffset(math.max(700, size.X - 24), 0)
        for _, stat in ipairs(self.Stats) do stat.TextSize = if size.X < 500 then 11 else 15 end
    end
    local camera = workspace.CurrentCamera
    if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        camera = workspace.CurrentCamera
        if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
        resize()
    end)
    resize()
    return self
end

function UI:Meter(parent, column, color, text)
    local label = W.Text(parent, text, 18, C.Muted, 11)
    label.Size, label.Position = UDim2.new(0.5, -24, 0, 18), UDim2.new(column, 12, 0, 64)
    local track = W.Make("Frame", { BackgroundColor3 = C.Raised, BorderSizePixel = 0,
        Size = UDim2.new(0.5, -24, 0, 5), Position = UDim2.new(column, 12, 0, 85) }, parent)
    W.Round(track, 4)
    local bar = W.Make("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
    W.Round(bar, 4)
    return bar, label
end

function UI:Register(name, builder) self.Builders[name] = builder end

function UI:MenuSignature()
    local state = self.Context.State
    if not state or not state.Profile then return "Loading" end
    local p, r = state.Profile, state.Runtime or {}
    local data
    if self.ActiveMenu == "Inventory" then data = { p.Inventory, r.Carry }
    elseif self.ActiveMenu == "Shop" then data = { p.Inventory, p.Backpack, p.Tools }
    elseif self.ActiveMenu == "House" then data = { p.House, p.OwnedThemes }
    elseif self.ActiveMenu == "Collection" then data = p.Collection
    elseif self.ActiveMenu == "Settings" then data = p.Settings
    elseif self.ActiveMenu == "Leaderboard" then
        local board = state.Leaderboard or {}
        data = { board.Live or board, board.Global, board.PersistenceEnabled }
    else
        data = table.clone(state.Quests or {})
        if data.DailyReward then
            data.DailyReward = table.clone(data.DailyReward)
            data.DailyReward.SecondsRemaining = math.ceil((data.DailyReward.SecondsRemaining or 0) / 60)
        end
    end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    return if ok then encoded else nil
end

function UI:RenderMenu()
    if not self.ActiveMenu then return end
    -- Heat snapshots must not destroy a button while a touch press is held.
    local signature = self:MenuSignature()
    if signature and self.Signature == signature then return end
    self.Signature = signature
    local oldY = self.Content.CanvasPosition.Y
    local selected = GuiService.SelectedObject
    local restoreFocus = selected and selected:IsDescendantOf(self.Menu)
    W.Clear(self.Content)
    local builder = self.Builders[self.ActiveMenu]
    if builder then builder(self.Content, self.Context.State) else W.Text(self.Content, "Waiting for your profile...", 55) end
    self.Content.CanvasPosition = Vector2.new(0, oldY)
    if not self.Modal and (restoreFocus or UserInputService.GamepadEnabled) then
        for _, child in ipairs(self.Content:GetDescendants()) do
            if child:IsA("TextButton") and child.Visible then GuiService.SelectedObject = child; break end
        end
    end
end

function UI:ToggleMenu(name)
    if self.ActiveMenu == name then self:CloseMenu(); return end
    if self.Context.House and self.Context.House.Active then self.Context.House:Cancel() end
    self.ActiveMenu, self.Menu.Visible, self.Objective.Visible = name, true, false
    self.Signature = nil
    self.Title.Text = name:upper()
    for tab, button in pairs(self.TabButtons) do button.TextColor3 = if tab == name then C.Teal else C.Text end
    self.Content.CanvasPosition = Vector2.zero
    self:RenderMenu()
end

function UI:CloseMenu()
    self.ActiveMenu, self.Menu.Visible, self.Objective.Visible = nil, false, true
    if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Menu) then GuiService.SelectedObject = nil end
    for _, button in pairs(self.TabButtons) do button.TextColor3 = C.Text end
end

function UI:Confirm(title, text, callback)
    if self.Modal then self.Modal:Destroy() end
    local overlay = W.Make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(),
        BackgroundTransparency = 0.28, Text = "", AutoButtonColor = false, ZIndex = 50 }, self.Gui)
    self.Modal = overlay
    local card = W.Card(overlay, 212)
    card.AnchorPoint, card.Position, card.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(0.86, 0, 0, 212)
    W.Make("UISizeConstraint", { MaxSize = Vector2.new(460, 212) }, card)
    card.ZIndex = 51
    W.Text(card, title, 33, C.Orange, 22)
    W.Text(card, text, 83, C.Text, 15)
    local function close()
        overlay:Destroy()
        if self.Modal == overlay then self.Modal = nil end
        if UserInputService.GamepadEnabled then
            GuiService.SelectedObject = if self.ActiveMenu then self.Menu:FindFirstChildWhichIsA("TextButton", true) else nil
        end
    end
    local accept = W.Actions(card, "Confirm sale", function() close(); callback() end, "Keep item", close)
    if UserInputService.GamepadEnabled then GuiService.SelectedObject = accept end
end

function UI:OnSnapshot(state)
    local p, r = state.Profile, state.Runtime or {}
    if not p then return end
    self.Loading.Visible = false
    self.Stats[1].Text = "CASH $" .. W.Number(p.Cash)
    self.Stats[2].Text = "GEMS " .. W.Number(p.Gems)
    self.Stats[3].Text = "LEVEL " .. tostring(p.Level)
    self.Stats[4].Text = "HOME $" .. W.Number(p.House.HouseValue)
    self.Connection.Text = if r.DataWritable == false then "Profile read-only"
        elseif r.DataStatus == "StudioMemory" then "Studio • temporary"
        elseif r.DataStatus == "Persistent" then "Persistent profile" else tostring(r.DataStatus or "Connected")
    self:UpdateHeat(r.Heat or 0)
    local weight, capacity = r.CarryWeight or 0, r.Capacity or 5
    self.BagText.Text = "BACKPACK  " .. weight .. " / " .. capacity
    self.BagBar.Size = UDim2.fromScale(math.clamp(weight / math.max(1, capacity), 0, 1), 1)
    local robbery = r.Robbery or {}
    local quest = state.Quests
    if robbery.Active then
        self.Objective.Text = "HEIST: " .. tostring(robbery.TargetName or robbery.TargetHouse or "House") .. "  |  Grab loot, avoid police, return to your HOME beacon to secure it."
    elseif #((r.Carry) or {}) > 0 then
        self.Objective.Text = "YOUR HAUL IS AT RISK  |  Return to your HOME beacon to secure these items."
    elseif quest and quest.Tutorial and not quest.Tutorial.Complete then
        self.Objective.Text = "FIRST HEIST  " .. tostring(quest.Tutorial.Step or 1) .. "/5  |  " .. tostring(quest.Tutorial.Text)
    else self.Objective.Text = "STEAL. ESCAPE. BUILD. PROTECT.  |  Enter a district house. Return home to secure loot. Sell at the orange shop." end
    if r.Event then
        local event = if type(r.Event) == "table" then r.Event.Name or r.Event.Id else r.Event
        self.Brand.Text = "STEAL A HOUSE  /  " .. tostring(event)
    else self.Brand.Text = "STEAL A HOUSE" end
    self:RenderMenu()
end

function UI:UpdateHeat(heat)
    heat = math.clamp(tonumber(heat) or 0, 0, 100)
    local status = if heat >= 81 then "CRITICAL" elseif heat >= 61 then "WANTED" elseif heat >= 41 then "ALERT" elseif heat >= 21 then "SUSPICIOUS" else "SAFE"
    self.HeatText.Text = "HEAT " .. math.floor(heat) .. " / 100  " .. status
    self.HeatBar.Size = UDim2.fromScale(heat / 100, 1)
    self.HeatBar.BackgroundColor3 = if heat > 60 then C.Danger elseif heat > 20 then C.Orange else C.Teal
end

return UI
