--!nonstrict
-- This controller displays server snapshots. Prices, ownership and timers are
-- never supplied by the client when requesting an action.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Widgets = require(script.Parent.Widgets)
local C = Widgets.Colors
local UI = {}
UI.__index = UI

local function money(value) return "$" .. Widgets.Number(value) end
local function seconds(value) return tostring(math.max(0, math.ceil(tonumber(value) or 0))) .. "s" end
local function childrenSignature(rows)
    local parts = {}
    for _, row in ipairs(rows or {}) do
        table.insert(parts, table.concat({ tostring(row.Id), tostring(row.DefinitionId),
            tostring(row.Slot), tostring(row.Variant), tostring(row.Size) }, ":"))
    end
    return table.concat(parts, "|")
end

function UI.new(context)
    local self = setmetatable({
        Config = context.Config, Send = context.Request, Snapshot = nil,
        Menu = nil, SellUid = nil, Connections = {}, MenuButtons = {},
        Cards = {}, ActionButtons = {}, Controls = {}, Sprinting = false,
    }, UI)
    self:Build()
    return self
end

function UI:CanAct()
    return self.Snapshot ~= nil and self.Snapshot.Profile ~= nil
        and self.Snapshot.Runtime ~= nil and self.Snapshot.Runtime.Writable == true
        and self.Snapshot.Profile.Pending == nil
end

function UI:IsTraining()
    return self.Snapshot ~= nil and self.Snapshot.Runtime ~= nil
        and self.Snapshot.Runtime.Training == true
end

function UI:Request(action, ...)
    local stopping = (action == "Sprint" or action == "Train") and select(1, ...) == false
    if action ~= "Sync" and not stopping and not self:CanAct() then
        if self.Toast then
            local pending = self.Snapshot and self.Snapshot.Profile and self.Snapshot.Profile.Pending
            self.Toast(if pending then "Finish your current house transaction before starting another action."
                else "Your saved data is unavailable. Actions are paused.", "Error")
        end
        return
    end
    self.Send(action, ...)
end

function UI:Build()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild("StealAHouseUI")
    if existing then existing:Destroy() end
    self.Gui = Widgets.Make("ScreenGui", {
        Name = "StealAHouseUI", ResetOnSpawn = false, IgnoreGuiInset = false,
        DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
    }, playerGui)
    self.Hud = Widgets.Make("Frame", {
        Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(470, 88),
        BackgroundColor3 = C.Panel, BorderSizePixel = 0,
    }, self.Gui)
    Widgets.Round(self.Hud, 14)
    self.Title = Widgets.Text(self.Hud, "STEAL A HOUSE", 24, C.Text, 18)
    self.Title.Position, self.Title.Size = UDim2.fromOffset(12, 4), UDim2.new(1, -24, 0, 24)
    self.Cash = Widgets.Text(self.Hud, "Loading your town…", 24, C.Text, 17)
    self.Cash.Position, self.Cash.Size = UDim2.fromOffset(12, 28), UDim2.new(1, -24, 0, 24)
    self.Rate = Widgets.Text(self.Hud, "Rent and speed will appear here", 20, C.Muted, 13)
    self.Rate.Position, self.Rate.Size = UDim2.fromOffset(12, 55), UDim2.new(1, -24, 0, 22)
    self.Status = Widgets.Make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 103),
        Size = UDim2.new(1, -26, 0, 52), BackgroundColor3 = C.Panel,
        BackgroundTransparency = 0.08, BorderSizePixel = 0,
        Text = "Waiting for the server…", TextColor3 = C.Text,
        TextWrapped = true, TextSize = 14, Font = Enum.Font.GothamMedium,
    }, self.Gui)
    Widgets.Round(self.Status, 12)
    self.MenuRail = Widgets.Make("Frame", {
        Position = UDim2.fromOffset(12, 167), Size = UDim2.fromOffset(108, 226),
        BackgroundTransparency = 1,
    }, self.Gui)
    local menuLayout = Widgets.Make("UIListLayout", { Padding = UDim.new(0, 6) }, self.MenuRail)
    for _, name in ipairs({ "Houses", "Shop", "Index", "Standings" }) do
        local button = Widgets.Button(self.MenuRail, name, function() self:Open(name) end, C.Panel)
        button.Name = name
        self.MenuButtons[name] = button
    end
    local utility = Widgets.Make("Frame", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10),
        Size = UDim2.fromOffset(94, 84), BackgroundTransparency = 1,
    }, self.Gui)
    Widgets.Make("UIListLayout", { Padding = UDim.new(0, 6) }, utility)
    Widgets.Button(utility, "Daily", function() self:Open("Daily") end, C.Orange)
    Widgets.Button(utility, "Settings", function() self:Open("Settings") end, C.Panel)
    self.Utility = utility
    self.ControlBar = Widgets.Make("Frame", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
        Size = UDim2.fromOffset(500, 48), BackgroundTransparency = 1,
    }, self.Gui)
    local definitions = {
        { "Bat", "Bat [R]", function() self:Request("Bat") end },
        { "Sprint", "Run [Shift]", function()
            if self.Controls.Sprint then self.Controls.Sprint(not self.Sprinting) end
        end },
        { "Train", "Train [T]", function() self:Request("Train", not self:IsTraining()) end },
        { "Lock", "Lock [L]", function() self:Request("Lock") end },
        { "Collect", "Collect [V]", function() self:Request("CollectAll") end },
    }
    for index, definition in ipairs(definitions) do
        local button = Widgets.Button(self.ControlBar, definition[2], definition[3], C.Panel)
        button.Name = definition[1]
        button.Size = UDim2.new(0.2, -5, 1, 0)
        button.Position = UDim2.new((index - 1) * 0.2, 2, 0, 0)
        button.TextSize = 13
        Widgets.Enabled(button, false)
        self.ActionButtons[definition[1]] = button
    end
    self.Shade = Widgets.Make("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.4, BorderSizePixel = 0, Visible = false, ZIndex = 5,
        Active = true,
    }, self.Gui)
    self.Panel = Widgets.Make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(630, 520), BackgroundColor3 = C.Panel,
        BorderSizePixel = 0, ZIndex = 6,
    }, self.Shade)
    Widgets.Round(self.Panel, 16)
    self.PanelTitle = Widgets.Text(self.Panel, "", 40, C.Text, 22)
    self.PanelTitle.Position, self.PanelTitle.Size = UDim2.fromOffset(16, 6), UDim2.new(1, -72, 0, 40)
    self.CloseButton = Widgets.Button(self.Panel, "X", function() self:Close() end)
    self.CloseButton.Position, self.CloseButton.Size = UDim2.new(1, -48, 0, 8), UDim2.fromOffset(38, 38)
    self.Content = Widgets.List(self.Panel, true)
    self.Content.Position, self.Content.Size = UDim2.fromOffset(16, 55), UDim2.new(1, -32, 1, -69)
    self.NoticeArea = Widgets.Make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160),
        Size = UDim2.new(1, -32, 0, 78), BackgroundTransparency = 1, ZIndex = 20,
    }, self.Gui)
    local function resize()
        local camera = Workspace.CurrentCamera
        local viewport = if camera then camera.ViewportSize else Vector2.new(800, 600)
        local small = viewport.X < 680
        local short = viewport.Y < 480
        self.Hud.Size = UDim2.fromOffset(math.max(180, math.min(if small then viewport.X - 125 else 470, viewport.X - 24)), if short then 74 else 88)
        self.Title.Position = UDim2.fromOffset(12, if short then 1 else 4)
        self.Cash.Position = UDim2.fromOffset(12, if short then 22 else 28)
        self.Rate.Position = UDim2.fromOffset(12, if short then 46 else 55)
        self.Title.TextSize = if small then 15 else 18
        self.Cash.TextSize = if small then 14 else 17
        self.Rate.TextSize = if small then 11 else 13
        self.ControlBar.Size = UDim2.fromOffset(math.min(520, viewport.X - 20), 48)
        self.ControlBar.Position = UDim2.new(0.5, 0, 1, if UserInputService.TouchEnabled then -132 else -12)
        self.Panel.Size = UDim2.fromOffset(math.max(220, math.min(660, viewport.X - 24)), math.max(190, math.min(590, viewport.Y - 82)))
        self.Status.Position = UDim2.new(0.5, 0, 0, if short then 87 else 103)
        self.Status.Size = UDim2.new(1, -26, 0, if short then 38 else 52)
        self.Status.TextSize = if short then 12 else 14
        self.MenuRail.Position = UDim2.fromOffset(12, if short then 132 else 167)
        self.MenuRail.Size = if short then UDim2.fromOffset(viewport.X - 24, 34) else UDim2.fromOffset(if small then 88 else 108, 226)
        menuLayout.FillDirection = if short then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
        self.NoticeArea.Position = UDim2.new(0.5, 0, 0, if short then 87 else 160)
        self.NoticeArea.Size = UDim2.new(1, -32, 0, if short then 38 else 78)
        for _, button in pairs(self.MenuButtons) do
            button.TextSize = if small then 13 else 15
            button.Size = if short then UDim2.new(0.25, -5, 0, 34) else UDim2.new(1, 0, 0, 38)
        end
    end
    local cameraConnection
    local function watchCamera()
        if cameraConnection then cameraConnection:Disconnect() end
        if Workspace.CurrentCamera then
            cameraConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
        end
        resize()
    end
    table.insert(self.Connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera))
    table.insert(self.Connections, { Disconnect = function() if cameraConnection then cameraConnection:Disconnect() end end })
    watchCamera()
end

function UI:SetControls(controls) self.Controls = controls end
function UI:SetSprint(enabled)
    self.Sprinting = enabled
    self.ActionButtons.Sprint.Text = if enabled then "Walk" else "Run [Shift]"
end

function UI:UpdateSelection()
    for _, button in pairs(self.MenuButtons) do button.Selectable = self.Menu == nil end
    for _, child in ipairs(self.Utility:GetChildren()) do
        if child:IsA("GuiButton") then child.Selectable = self.Menu == nil end
    end
    for _, button in pairs(self.ActionButtons) do
        button.Selectable = self.Menu == nil and button.Active
    end
end

function UI:Open(name, uid)
    if name == self.Menu and name ~= "Sell" then self:Close(); return end
    if name == "Sell" then
        if not self:FindHouse(uid) then return end
        self.ReturnMenu = self.Menu or "Houses"
        self.SellUid = uid
    end
    self.Menu, self.MenuSignature = name, nil
    self.Shade.Visible = true
    self.PanelTitle.Text = if name == "Sell" then "Confirm sale" else name
    self.Content.CanvasPosition = Vector2.zero
    if self.Sprinting and self.Controls.Sprint then self.Controls.Sprint(false) end
    self:RenderMenu(true)
    self:UpdateSelection()
    if GuiService.SelectedObject then GuiService.SelectedObject = self.CloseButton end
end

function UI:Close()
    local oldMenu = self.Menu
    self.Menu, self.SellUid, self.MenuSignature = nil, nil, nil
    self.Shade.Visible = false
    self:UpdateSelection()
    if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Panel) then
        GuiService.SelectedObject = self.MenuButtons[oldMenu] or self.MenuButtons.Houses
    end
end

function UI:FindHouse(uid)
    for _, house in ipairs(if self.Snapshot then self.Snapshot.Houses or {} else {}) do
        if house.Id == uid then return house end
    end
    return nil
end

function UI:Definition(id)
    return self.Config.HouseById[id] or { Name = "House", Rarity = "Common", Income = 0, Price = 0 }
end

function UI:HouseName(house)
    local definition = self:Definition(house.DefinitionId)
    local variant = self.Config.VariantById[house.Variant]
    local size = self.Config.SizeById[house.Size or "Normal"]
    return (if size and size.Id ~= "Normal" then size.Name .. " " else "")
        .. (if variant and variant.Id ~= "Normal" then variant.Name .. " " else "") .. definition.Name
end

function UI:ClearContent()
    self.Cards, self.MenuActions = {}, {}
    self.TrainingInfo = nil
    Widgets.Clear(self.Content)
end

function UI:Action(parent, text, key, action, ...)
    local arguments = table.pack(...)
    local button = Widgets.Button(parent, text, function() self:Request(action, table.unpack(arguments, 1, arguments.n)) end)
    button:SetAttribute("FocusKey", key)
    if action == "Buy" or action == "Collect" or action == "CollectAll"
        or action == "BaseUpgrade" or action == "TreadmillUpgrade" or action == "SecurityUpgrade" then
        button:SetAttribute("HomeRequired", true)
    end
    self.MenuActions = self.MenuActions or {}
    table.insert(self.MenuActions, button)
    Widgets.Enabled(button, self:CanAct())
    return button
end

function UI:RenderMenu(force)
    if not self.Menu then return end
    local snapshot, name = self.Snapshot, self.Menu
    if not snapshot or not snapshot.Profile then
        self:ClearContent()
        Widgets.Text(self.Content, "Waiting for your saved data…", 48, C.Muted)
        return
    end
    local profile, runtime = snapshot.Profile, snapshot.Runtime or {}
    local signature
    if name == "Houses" then
        signature = childrenSignature(snapshot.Houses) .. ":" .. tostring(runtime.Slots) .. ":" .. tostring(runtime.Multiplier)
    elseif name == "Shop" then
        signature = table.concat({ profile.BaseLevel or 1, profile.TreadmillLevel or 1, profile.SecurityLevel or 0, childrenSignature(snapshot.Market) }, ":")
    elseif name == "Index" then
        local found = {}
        for id, owned in pairs(profile.Collection or {}) do if owned then table.insert(found, id) end end
        table.sort(found)
        signature = table.concat(found, ":")
    elseif name == "Settings" then
        signature = tostring(profile.Settings and profile.Settings.Music) .. tostring(profile.Settings and profile.Settings.SFX) .. tostring(profile.Settings and profile.Settings.ReducedEffects) .. tostring(runtime.DataMode) .. tostring(runtime.Writable)
    elseif name == "Daily" then
        signature = tostring(profile.DailyDay) .. ":" .. tostring(profile.DailyStreak) .. ":" .. tostring(math.floor((snapshot.ServerTime or 0) / 86400))
    elseif name == "Sell" then
        signature = tostring(self.SellUid) .. ":" .. tostring(self:FindHouse(self.SellUid) ~= nil)
    else
        local rows = {}
        for _, standing in ipairs(snapshot.Standings or {}) do table.insert(rows, tostring(standing.UserId) .. ":" .. tostring(standing.Cash) .. ":" .. tostring(standing.Income)) end
        signature = table.concat(rows, "|")
    end
    if force or self.MenuSignature ~= signature then
        local scroll = self.Content.CanvasPosition
        local selected = GuiService.SelectedObject
        local focusKey = if selected and selected:IsDescendantOf(self.Content) then selected:GetAttribute("FocusKey") else nil
        self:ClearContent()
        self.MenuSignature = signature
        if name == "Houses" then
            Widgets.Text(self.Content, "Your houses · " .. #snapshot.Houses .. "/" .. tostring(runtime.Slots or 10) .. " pads", 30, C.Muted)
            Widgets.Text(self.Content, "Rent begins after construction. Collect it at your base; keep the gate locked to protect your houses.", 52, C.Muted, 14)
            self:Action(self.Content, "Collect all rent at my base", "collectAll", "CollectAll")
            if #snapshot.Houses == 0 then Widgets.Text(self.Content, "Steal a house box from an NPC property and bring it home, or buy a starter house in the shop.", 74, C.Muted) end
            local sorted = table.clone(snapshot.Houses)
            table.sort(sorted, function(a, b) return a.Slot < b.Slot end)
            for _, house in ipairs(sorted) do
                local definition = self:Definition(house.DefinitionId)
                local rarity = self.Config.Rarities[definition.Rarity]
                local card = Widgets.Card(self.Content, 150)
                Widgets.Text(card, "Pad " .. house.Slot .. " · " .. self:HouseName(house), 28, if rarity then Widgets.Color(rarity.Color):Lerp(C.Text, 0.55) else C.Text, 17)
                Widgets.Text(card, definition.Rarity .. " · " .. money(definition.Income * ((self.Config.VariantById[house.Variant] or {}).Multiplier or 1) * ((self.Config.SizeById[house.Size or "Normal"] or {}).IncomeMultiplier or 1) * (runtime.Multiplier or 1)) .. "/s", 24, C.Muted, 13)
                local state = Widgets.Text(card, "", 24, C.Text, 14)
                local actions = Widgets.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38) }, card)
                local collect = self:Action(actions, "Collect", house.Id .. ":collect", "Collect", house.Id)
                collect.Size = UDim2.new(0.5, -4, 1, 0)
                local sell = Widgets.Button(actions, "Sell…", function() self:Open("Sell", house.Id) end, C.Orange)
                sell.Position, sell.Size = UDim2.new(0.5, 4, 0, 0), UDim2.new(0.5, -4, 1, 0)
                sell:SetAttribute("FocusKey", house.Id .. ":sell")
                table.insert(self.MenuActions, sell)
                self.Cards[house.Id] = { State = state, Collect = collect, Sell = sell }
            end
        elseif name == "Shop" then
            Widgets.Text(self.Content, "Buy houses and upgrades at your own base. Collect rent to afford more pads and faster training.", 56, C.Muted, 14)
            self.TrainingInfo = Widgets.Text(self.Content, "", 52, C.Text, 14)
            for _, upgrade in ipairs({
                { "Base", runtime.NextBase, "BaseUpgrade", "More pads for your house collection." },
                { "Treadmill", runtime.NextTreadmill, "TreadmillUpgrade", "Earn speed faster while training at home." },
                { "Security", runtime.NextSecurity, "SecurityUpgrade", "Keep your gate locked for longer." },
            }) do
                local card = Widgets.Card(self.Content, 117)
                Widgets.Text(card, upgrade[1] .. " upgrade", 25, C.Text, 17)
                local benefit = upgrade[4]
                if upgrade[2] then
                    if upgrade[1] == "Base" then benefit = tostring(upgrade[2].Slots) .. " house pads at the next level."
                    elseif upgrade[1] == "Treadmill" then benefit = Widgets.Number(upgrade[2].Rate) .. " speed XP per second while training."
                    elseif upgrade[1] == "Security" then benefit = tostring(self.Config.Game.LockSeconds + upgrade[2].BonusSeconds) .. " seconds of gate protection." end
                end
                Widgets.Text(card, benefit, 25, C.Muted, 13)
                if upgrade[2] then
                    local cost = upgrade[2].Cost or upgrade[2].Price or 0
                    local button = self:Action(card, "Upgrade · " .. money(cost), "upgrade:" .. upgrade[1], upgrade[3])
                    button:SetAttribute("Cost", cost)
                else Widgets.Text(card, "Maximum level reached", 34, C.Teal) end
            end
            Widgets.Text(self.Content, "House shop · normal size, normal variant", 32, C.Text)
            for _, offer in ipairs(snapshot.Market or {}) do
                local definition = self:Definition(offer.DefinitionId)
                local card = Widgets.Card(self.Content, 123)
                Widgets.Text(card, definition.Name, 25, C.Text, 17)
                Widgets.Text(card, definition.Rarity .. " · base rent " .. money(offer.Income) .. "/s", 24, C.Muted, 13)
                local button = self:Action(card, "Buy · " .. money(offer.Price), "buy:" .. offer.DefinitionId, "Buy", offer.DefinitionId)
                button:SetAttribute("Cost", offer.Price)
            end
        elseif name == "Index" then
            local count = 0
            for _, definition in ipairs(self.Config.Houses) do if profile.Collection[definition.Id] then count += 1 end end
            Widgets.Text(self.Content, "Discovered " .. count .. "/" .. #self.Config.Houses .. " house designs", 32, C.Text)
            Widgets.Text(self.Content, "Discover houses by buying them or successfully carrying them home. Variants and sizes change your rent.", 54, C.Muted, 14)
            for _, definition in ipairs(self.Config.Houses) do
                local discovered = profile.Collection[definition.Id] == true
                local card = Widgets.Card(self.Content, 73)
                Widgets.Text(card, (if discovered then "✓ " else "○ ") .. definition.Name, 25, if discovered then C.Text else C.Muted, 16)
                Widgets.Text(card, definition.Rarity .. " · " .. (if discovered then "Discovered" else "Not yet discovered"), 22, C.Muted, 13)
            end
            Widgets.Text(self.Content, "Mutations", 30, C.Text)
            for _, variant in ipairs(self.Config.Variants) do
                Widgets.Text(self.Content, variant.Name .. " · " .. tostring(variant.Multiplier) .. "× rent", 28, C.Muted, 14)
            end
        elseif name == "Standings" then
            Widgets.Text(self.Content, "Players in this town · current cash and rent", 38, C.Muted, 14)
            for index, standing in ipairs(snapshot.Standings or {}) do
                local card = Widgets.Card(self.Content, 75)
                Widgets.Text(card, tostring(index) .. ". " .. tostring(standing.Name), 25, C.Text)
                Widgets.Text(card, money(standing.Cash) .. " cash · " .. money(standing.Income) .. "/s rent", 24, C.Muted, 14)
            end
        elseif name == "Settings" then
            Widgets.Text(self.Content, "Progress storage: " .. (if runtime.DataMode == "StudioMemory" then "temporary Studio session" else "online saves enabled"), 38, C.Muted, 14)
            Widgets.Text(self.Content, "Choose how your town looks and sounds.", 38, C.Muted, 14)
            for _, setting in ipairs({ { "Music", "Music" }, { "SFX", "Sound effects" }, { "ReducedEffects", "Reduced visual effects" } }) do
                local enabled = profile.Settings[setting[1]] == true
                self:Action(self.Content, setting[2] .. ": " .. (if enabled then "ON" else "OFF"), "setting:" .. setting[1], "Setting", setting[1], not enabled)
            end
            Widgets.Text(self.Content, "Keyboard: R defend · Shift run · T train · L lock · V collect. Touch: use the buttons. Controller: X interact, D-pad Up houses, B close, R2 defend, L3 run, Y train; navigate menus with the D-pad.", 90, C.Muted, 14)
        elseif name == "Daily" then
            Widgets.Text(self.Content, "Daily cash bonus · one claim per UTC day", 38, C.Text)
            Widgets.Text(self.Content, "Return on consecutive days to grow your streak. Missing a day resets the streak.", 48, C.Muted, 14)
            for day, reward in ipairs(self.Config.DailyRewards) do
                Widgets.Text(self.Content, "Day " .. day .. " · " .. money(reward), 28, C.Muted, 15)
            end
            local claimed = tonumber(profile.DailyDay) == math.floor((snapshot.ServerTime or 0) / 86400)
            local button = self:Action(self.Content, if claimed then "Claimed today" else "Claim today's reward", "daily", "Daily")
            button:SetAttribute("Unavailable", claimed)
            Widgets.Enabled(button, self:CanAct() and not claimed)
        elseif name == "Sell" then
            local house = self:FindHouse(self.SellUid)
            if not house then
                Widgets.Text(self.Content, "This house is no longer yours. The sale has been cancelled.", 70, C.Muted)
            else
                local definition = self:Definition(house.DefinitionId)
                Widgets.Text(self.Content, self:HouseName(house), 45, C.Text, 21)
                Widgets.Text(self.Content, "Sell this house permanently? It will stop earning rent and leave your base.", 68, C.Muted, 16)
                local rank = (self.Config.Rarities[definition.Rarity] or {}).Rank or 1
                if rank >= 4 or house.Variant ~= "Normal" or house.Size ~= "Normal" then
                    Widgets.Text(self.Content, "This is a special house. Check its rarity, mutation and size before selling.", 60, C.Text, 15)
                end
                local uid = house.Id
                local confirm = Widgets.Button(self.Content, "Yes, sell this house", function()
                    -- Recheck the UID against the latest snapshot; the server
                    -- independently validates ownership and the sale intent.
                    if self:FindHouse(uid) then self:Request("Sell", uid, true) end
                    self:Close()
                end, C.Danger)
                confirm:SetAttribute("FocusKey", "confirmSell")
                confirm:SetAttribute("HomeRequired", true)
                table.insert(self.MenuActions, confirm)
                Widgets.Button(self.Content, "Keep my house", function() self:Close() end, C.Teal)
            end
        end
        self.Content.CanvasPosition = scroll
        local restored = false
        if focusKey then
            for _, descendant in ipairs(self.Content:GetDescendants()) do
                if descendant:IsA("GuiButton") and descendant:GetAttribute("FocusKey") == focusKey then
                    GuiService.SelectedObject = descendant
                    restored = true
                    break
                end
            end
        end
        if selected and not restored and not selected.Parent then GuiService.SelectedObject = self.CloseButton end
    end
    for _, button in ipairs(self.MenuActions or {}) do
        local homeAllowed = not button:GetAttribute("HomeRequired") or runtime.AtHome ~= false
        local cost = button:GetAttribute("Cost")
        Widgets.Enabled(button, self:CanAct() and button:GetAttribute("Unavailable") ~= true
            and homeAllowed and (not cost or profile.Cash >= cost))
    end
    if name == "Shop" and self.TrainingInfo then
        local speed, xp = runtime.Speed or self.Config.Speed(profile), runtime.SpeedXP or profile.SpeedXP or 0
        local rate = runtime.TrainingRate or (self.Config.Treadmills[profile.TreadmillLevel] or {}).Rate or 0
        local nextXP = runtime.NextSpeedXP
        if nextXP == nil and speed < 80 then nextXP = 20 * (((speed - self.Config.Game.MoveSpeed) / 2) + 1) ^ 2 end
        self.TrainingInfo.Text = "Speed " .. Widgets.Number(speed) .. " · " .. Widgets.Number(xp) .. " XP · treadmill " .. Widgets.Number(rate) .. " XP/s\n"
            .. (if nextXP then "Next speed increase at " .. Widgets.Number(nextXP) .. " XP" else "Maximum speed reached")
    end
    if name == "Houses" then
        for _, house in ipairs(snapshot.Houses or {}) do
            local card = self.Cards[house.Id]
            if card then
                card.State.Text = if house.Building then "Building · ready in " .. seconds(house.BuildRemaining) else "Rent waiting: " .. money(house.Income)
                Widgets.Enabled(card.Collect, self:CanAct() and not house.Building and runtime.AtHome ~= false)
            end
        end
    end
end

function UI:SetSnapshot(snapshot)
    if type(snapshot) ~= "table" then return end
    self.Snapshot = snapshot
    local profile, runtime = snapshot.Profile, snapshot.Runtime or {}
    if profile then
        self.Cash.Text = money(profile.Cash) .. "  ·  Bank " .. money(profile.Bank)
        self.Rate.Text = money(runtime.IncomePerSecond) .. "/s rent  ·  Speed " .. Widgets.Number(runtime.Speed) .. "  ·  Base " .. tostring(runtime.BaseLevel or profile.BaseLevel or 1)
    end
    local status = {}
    if runtime.Writable ~= true then table.insert(status, "DATA PAUSED · actions are disabled")
    elseif profile and profile.Pending then table.insert(status, "Finishing your house transaction…") end
    if runtime.DataMode == "StudioMemory" then table.insert(status, "Studio temporary · saves are not kept") end
    if runtime.Carry then
        table.insert(status, "Carry " .. tostring(runtime.Carry.Name) .. " home · " .. seconds(runtime.Carry.SecondsRemaining))
    elseif runtime.StealHold then
        table.insert(status, "Picking up " .. tostring(runtime.StealHold.Name) .. " · " .. math.floor(math.clamp(runtime.StealHold.Progress or 0, 0, 1) * 100) .. "%")
    elseif runtime.Training then table.insert(status, "Training speed · stay on your own treadmill") end
    if (runtime.LockRemaining or 0) > 0 then
        table.insert(status, "Gate locked · " .. seconds(runtime.LockRemaining))
    elseif (runtime.LockCooldown or 0) > 0 then table.insert(status, "Lock ready in " .. seconds(runtime.LockCooldown))
    else table.insert(status, "Gate open · lock your base before exploring") end
    if #status == 0 then table.insert(status, "Explore NPC properties, steal a house box, and carry it home") end
    self.Status.Text = table.concat(status, "  •  ")
    for _, button in pairs(self.ActionButtons) do Widgets.Enabled(button, self:CanAct()) end
    self.ActionButtons.Train.Text = if runtime.Training then "Stop train" else "Train [T]"
    if runtime.Training and self.Sprinting and self.Controls.Sprint then self.Controls.Sprint(false) end
    self.ActionButtons.Lock.Text = if (runtime.LockRemaining or 0) > 0 then "Locked" else "Lock [L]"
    Widgets.Enabled(self.ActionButtons.Lock, self:CanAct() and (runtime.LockRemaining or 0) <= 0 and (runtime.LockCooldown or 0) <= 0)
    Widgets.Enabled(self.ActionButtons.Collect, self:CanAct() and runtime.AtHome ~= false)
    self:RenderMenu(false)
    self:UpdateSelection()
end

function UI:Destroy()
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    self.Connections = {}
    if self.Gui then self.Gui:Destroy() end
end

return UI
