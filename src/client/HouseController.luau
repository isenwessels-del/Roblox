--!nonstrict
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local W = require(script.Parent.Widgets)
local House = {}
House.__index = House
local ACTIONS = { "HouseRotate", "HouseConfirm", "HouseCancel", "HouseLeft", "HouseRight", "HouseUp", "HouseDown", "HouseAxis" }

function House.new(ctx)
    local self = setmetatable({ Context = ctx, Active = false }, House)
    ctx.UI:Register("House", function(parent, state) self:RenderMenu(parent, state) end)
    UserInputService.InputChanged:Connect(function(input)
        if self.Active and input.UserInputType == Enum.UserInputType.MouseMovement then self:Pointer(input.Position.X, input.Position.Y) end
    end)
    UserInputService.TouchTapInWorld:Connect(function(position, processed)
        if self.Active and not processed then self:Pointer(position.X, position.Y) end
    end)
    Players.LocalPlayer.CharacterRemoving:Connect(function() self:Cancel() end)
    RunService.RenderStepped:Connect(function(dt)
        if not self.Active then return end
        self.AxisTimer = (self.AxisTimer or 0) + dt
        if self.Axis and self.Axis.Magnitude > 0.3 and self.AxisTimer > 0.16 then
            self.AxisTimer = 0
            if math.abs(self.Axis.X) > math.abs(self.Axis.Y) then self:Nudge(if self.Axis.X > 0 then 1 else -1, 0)
            else self:Nudge(0, if self.Axis.Y > 0 then -1 else 1) end
        end
    end)
    return self
end

function House:RenderMenu(parent, state)
    if not state or not state.Profile then return end
    local p = state.Profile
    local tier = self.Context.Config.Houses[p.House.Tier]
    W.Text(parent, tier.Name .. " • TIER " .. p.House.Tier, 32, W.Colors.Teal, 21)
    W.Text(parent, "Home value $" .. W.Number(p.House.HouseValue) .. "  •  Security " .. p.House.SecurityLevel
        .. "\nDisplaying loot raises your home value. Your secured items stay safe at home.", 65, W.Colors.Muted, 14)
    local upgrade = self.Context.Config.Houses[p.House.Tier + 1]
    if upgrade then
        W.Button(parent, "Upgrade to " .. upgrade.Name .. " • $" .. W.Number(upgrade.Cost) .. " • Level " .. upgrade.RequiredLevel,
            function() self.Context:Request("House", "RequestHouseUpgrade") end)
    end
    local security = self.Context.Config.Security[p.House.SecurityLevel + 1]
    if security then W.Button(parent, "Security style: " .. security.Name .. " • $" .. W.Number(security.Cost) .. " • Level " .. security.RequiredLevel,
        function() self.Context:Request("House", "RequestSecurityUpgrade") end) end
    W.Text(parent, "HOUSE STYLE", 32, W.Colors.Orange, 18)
    local themes = {}
    for id in pairs(self.Context.Config.Game.Themes) do table.insert(themes, id) end
    table.sort(themes)
    for _, id in ipairs(themes) do
        local theme = self.Context.Config.Game.Themes[id]
        local owned = (p.OwnedThemes or {})[id]
        local selected = p.House.Theme == id
        W.Button(parent, theme.Name .. (if selected then " • Active" elseif owned then " • Apply" else " • $" .. W.Number(theme.Cost)),
            function() self.Context:Request("House", "RequestHouseCustomization", id) end, W.Color(theme.Color):Lerp(W.Colors.Panel, 0.72))
    end
    W.Text(parent, "DISPLAYED FURNITURE", 32, W.Colors.Teal, 18)
    local items = self.Context.Inventory:SortedItems(p.House.Furniture)
    if #items == 0 then W.Text(parent, "Select a secured item in Inventory, then choose Place at home.", 50, W.Colors.Muted) end
    for _, item in ipairs(items) do
        local spec = self.Context.Config.Items[item.Entry.ItemId]
        if spec then
            local card = W.Card(parent, 115)
            W.Text(card, spec.Name, 24, W.Color(self.Context.Config.Rarities[spec.Rarity].Color), 18)
            W.Text(card, "$" .. W.Number(spec.Value) .. "  •  Grid " .. item.Entry.X .. ", " .. item.Entry.Z, 24, W.Colors.Muted, 13)
            W.Button(card, "Pick up into storage (at home)", function() self.Context:Request("Gameplay", "RequestPickupItem", item.Uid) end)
        end
    end
end

function House:Begin(uid)
    self:Cancel()
    local state = self.Context.State
    if not state or not state.Runtime.Plot then return end
    local entry = state.Profile.Inventory[uid]
    local spec = entry and self.Context.Config.Items[entry.ItemId]
    if not spec then return end
    local plot = state.Runtime.Plot
    local o = plot.Origin
    self.Origin = Vector3.new(o.X, o.Y, o.Z)
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or (root.Position - self.Origin).Magnitude > self.Context.Config.Game.HomeRadius + 3 then
        self.Context.Notifications:Push("Return to your HOME beacon to place furniture.", "Warning")
        return
    end
    local world = workspace:FindFirstChild("StealAHouse")
    local plots = world and world:FindFirstChild("PlayerPlots")
    self.Plot = plots and plots:FindFirstChild("Plot" .. tostring(plot.Id))
    self.Floors = {}
    if self.Plot then
        for _, part in ipairs(self.Plot:GetDescendants()) do
            if part:IsA("BasePart") and part.Name == "Floor" then table.insert(self.Floors, part) end
        end
    end
    if #self.Floors == 0 then self.Context.Notifications:Push("Your house floor is still loading. Try again shortly.", "Warning"); return end
    self.Uid, self.Spec, self.Active, self.X, self.Z, self.Rotation = uid, spec, true, 0, 0, 0
    self.Ghost = W.Make("Part", { Name = "PlacementPreview", Anchored = true, CanCollide = false, CanTouch = false,
        CanQuery = false, Transparency = 0.5, Material = Enum.Material.Neon, CastShadow = false }, workspace)
    self.Context.UI:CloseMenu()
    self.Context.UI.Objective.Visible = false
    self.Context.Camera:Placement(self.Origin)
    self:BuildControls()
    self:BindActions()
    self:UpdateGhost()
end

function House:BuildControls()
    local controls = W.Make("Frame", { BackgroundColor3 = W.Colors.Panel, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -73), Size = UDim2.new(1, -24, 0, 172) }, self.Context.UI.Gui)
    W.Round(controls, 12)
    W.Make("UISizeConstraint", { MaxSize = Vector2.new(600, 172) }, controls)
    self.Controls = controls
    self.Caption = W.Text(controls, self.Spec.Name .. " • Tap the floor or use arrows to move", 25, W.Colors.Teal, 14)
    self.Caption.Position, self.Caption.Size = UDim2.fromOffset(10, 7), UDim2.new(1, -20, 0, 25)
    local function button(text, x, y, callback)
        local item = W.Button(controls, text, callback)
        item.Size, item.Position = UDim2.fromOffset(42, 36), UDim2.fromOffset(x, y)
    end
    button("↑", 55, 38, function() self:Nudge(0, -1) end)
    button("←", 10, 77, function() self:Nudge(-1, 0) end)
    button("↓", 55, 77, function() self:Nudge(0, 1) end)
    button("→", 100, 77, function() self:Nudge(1, 0) end)
    local rotate = W.Button(controls, "Rotate (R / RB)", function() self:Rotate() end)
    rotate.Position, rotate.Size = UDim2.fromOffset(155, 40), UDim2.new(1, -165, 0, 36)
    self.PlaceButton = W.Button(controls, "Place (Enter / A)", function() self:Confirm() end, W.Colors.Teal:Lerp(W.Colors.Panel, 0.6))
    self.PlaceButton.Position, self.PlaceButton.Size = UDim2.fromOffset(155, 80), UDim2.new(1, -165, 0, 36)
    local cancel = W.Button(controls, "Cancel (Esc / B)", function() self:Cancel() end)
    cancel.Position, cancel.Size = UDim2.fromOffset(10, 126), UDim2.new(1, -20, 0, 36)
end

function House:BindActions()
    local function bind(name, callback, ...)
        ContextActionService:BindActionAtPriority(name, function(_, state, input)
            if state == Enum.UserInputState.Begin then callback(input) end
            return Enum.ContextActionResult.Sink
        end, false, 3100, ...)
    end
    bind("HouseRotate", function() self:Rotate() end, Enum.KeyCode.R, Enum.KeyCode.ButtonR1)
    bind("HouseConfirm", function() self:Confirm() end, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
    bind("HouseCancel", function() self:Cancel() end, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
    bind("HouseLeft", function() self:Nudge(-1, 0) end, Enum.KeyCode.Left, Enum.KeyCode.A, Enum.KeyCode.DPadLeft)
    bind("HouseRight", function() self:Nudge(1, 0) end, Enum.KeyCode.Right, Enum.KeyCode.D, Enum.KeyCode.DPadRight)
    bind("HouseUp", function() self:Nudge(0, -1) end, Enum.KeyCode.Up, Enum.KeyCode.W, Enum.KeyCode.DPadUp)
    bind("HouseDown", function() self:Nudge(0, 1) end, Enum.KeyCode.Down, Enum.KeyCode.S, Enum.KeyCode.DPadDown)
    ContextActionService:BindActionAtPriority("HouseAxis", function(_, state, input)
        self.Axis = if state == Enum.UserInputState.End then Vector2.zero else Vector2.new(input.Position.X, input.Position.Y)
        return Enum.ContextActionResult.Sink
    end, false, 3100, Enum.KeyCode.Thumbstick1)
end

function House:Pointer(x, y)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local ray = camera:ScreenPointToRay(x, y)
    local params = RaycastParams.new()
    params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include, self.Floors
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
    if hit then
        local grid = self.Context.Config.Game.GridSize
        self.X = math.round((hit.Position.X - self.Origin.X) / grid) * grid
        self.Z = math.round((hit.Position.Z - self.Origin.Z) / grid) * grid
        self:UpdateGhost()
    end
end

function House:Nudge(x, z)
    if not self.Active then return end
    local grid = self.Context.Config.Game.GridSize
    local tier = self.Context.Config.Houses[self.Context.State.Profile.House.Tier]
    self.X, self.Z = math.clamp(self.X + x * grid, -tier.Width / 2, tier.Width / 2), math.clamp(self.Z + z * grid, -tier.Depth / 2, tier.Depth / 2)
    self.X, self.Z = math.round(self.X / grid) * grid, math.round(self.Z / grid) * grid
    self:UpdateGhost()
end

function House:Rotate()
    if not self.Active then return end
    self.Rotation = (self.Rotation + 90) % 360
    self:UpdateGhost()
end

function House:UpdateGhost()
    if not self.Active then return end
    local sx, sz = self.Spec.Size.X, self.Spec.Size.Z
    if self.Rotation % 180 ~= 0 then sx, sz = sz, sx end
    local tier = self.Context.Config.Houses[self.Context.State.Profile.House.Tier]
    local valid = math.abs(self.X) + sx / 2 <= tier.Width / 2 - 2 and math.abs(self.Z) + sz / 2 <= tier.Depth / 2 - 2
    if math.abs(self.X) < 4 + sx / 2 and self.Z < -tier.Depth / 2 + 9 + sz / 2 then valid = false end
    local count = 0
    for _, item in pairs(self.Context.State.Profile.House.Furniture) do
        count += 1
        local spec = self.Context.Config.Items[item.ItemId]
        if spec then
            local ix, iz = spec.Size.X, spec.Size.Z
            if item.Rotation % 180 ~= 0 then ix, iz = iz, ix end
            if math.abs(item.X - self.X) < (ix + sx) / 2 + 0.2 and math.abs(item.Z - self.Z) < (iz + sz) / 2 + 0.2 then valid = false end
        end
    end
    if count >= tier.MaxFurniture then valid = false end
    self.Valid = valid
    self.Ghost.Size = Vector3.new(self.Spec.Size.X, 2, self.Spec.Size.Z)
    local floor = self.Floors[1]
    if not floor or not floor.Parent then
        self.Floors = {}
        if self.Plot and self.Plot.Parent then
            for _, part in ipairs(self.Plot:GetDescendants()) do
                if part:IsA("BasePart") and part.Name == "Floor" then table.insert(self.Floors, part) end
            end
        end
        floor = self.Floors[1]
        if not floor then self:Cancel(); return end
    end
    local y = floor.Position.Y + floor.Size.Y / 2 + 1
    self.Ghost.CFrame = CFrame.new(self.Origin.X + self.X, y, self.Origin.Z + self.Z) * CFrame.Angles(0, math.rad(self.Rotation), 0)
    self.Ghost.Color = if valid then W.Colors.Teal else W.Colors.Danger
    self.PlaceButton.Text = if valid then "PLACE • " .. self.Rotation .. "° (Enter / A)" else "BLOCKED • move to a free spot"
end

function House:Confirm()
    if not self.Active then return end
    if not self.Valid then self.Context.Notifications:Push("Choose a free spot inside your house.", "Warning"); return end
    self.Context:Request("Gameplay", "RequestPlaceItem", self.Uid, self.X, self.Z, self.Rotation)
    self:Cancel()
end

function House:Cancel()
    self.Active, self.Axis = false, Vector2.zero
    for _, action in ipairs(ACTIONS) do ContextActionService:UnbindAction(action) end
    if self.Ghost then self.Ghost:Destroy(); self.Ghost = nil end
    if self.Controls then self.Controls:Destroy(); self.Controls = nil end
    self.Context.Camera:Restore()
    if not self.Context.UI.ActiveMenu then self.Context.UI.Objective.Visible = true end
end

function House:OnSnapshot(state)
    if not self.Active then return end
    if not state.Profile.Inventory[self.Uid] then self:Cancel(); return end
    self:UpdateGhost()
end

return House
