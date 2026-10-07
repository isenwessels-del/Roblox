--!nonstrict
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Input = {}
Input.__index = Input

function Input.new(ui)
    local self = setmetatable({ UI = ui, Sprinting = false, Bound = {}, Connections = {} }, Input)
    local function bind(name, callback, ...)
        local key = "StealAHouse_" .. name
        table.insert(self.Bound, key)
        ContextActionService:BindAction(key, function(_, state)
            -- A key released while a menu or chat box is open must still stop
            -- held sprinting; opening UI never swallows the release edge.
            if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
                callback(state)
                return Enum.ContextActionResult.Pass
            end
            if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
            if ui.Menu then return Enum.ContextActionResult.Sink end
            callback(state)
            return Enum.ContextActionResult.Sink
        end, false, ...)
    end
    bind("Bat", function(state) if state == Enum.UserInputState.Begin then ui:Request("Bat") end end, Enum.KeyCode.R, Enum.KeyCode.ButtonR2)
    bind("Sprint", function(state)
        if state == Enum.UserInputState.Begin then self:SetSprint(true)
        elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then self:SetSprint(false) end
    end, Enum.KeyCode.LeftShift)
    bind("SprintToggle", function(state) if state == Enum.UserInputState.Begin then self:SetSprint(not self.Sprinting) end end, Enum.KeyCode.ButtonL3)
    bind("Train", function(state)
        if state == Enum.UserInputState.Begin then ui:Request("Train", not ui:IsTraining()) end
    end, Enum.KeyCode.T, Enum.KeyCode.ButtonY)
    bind("Lock", function(state) if state == Enum.UserInputState.Begin then ui:Request("Lock") end end, Enum.KeyCode.L)
    bind("Collect", function(state) if state == Enum.UserInputState.Begin then ui:Request("CollectAll") end end, Enum.KeyCode.V)
    local function menuAction(name, keys, callback)
        local key = "StealAHouse_" .. name
        table.insert(self.Bound, key)
        ContextActionService:BindAction(key, function(_, state)
            if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
            if state == Enum.UserInputState.Begin and callback() then return Enum.ContextActionResult.Sink end
            return Enum.ContextActionResult.Pass
        end, false, table.unpack(keys))
    end
    menuAction("Menu", { Enum.KeyCode.DPadUp }, function()
        if ui.Menu then return false end -- Up navigates menus; X remains available for world prompts.
        ui:Open("Houses")
        if ui.Menu then GuiService.SelectedObject = ui.CloseButton end
        return true
    end)
    menuAction("CloseMenu", { Enum.KeyCode.ButtonB }, function()
        if not ui.Menu then return false end
        ui:Close()
        return true
    end)
    ui:SetControls({ Sprint = function(enabled) self:SetSprint(enabled) end })
    table.insert(self.Connections, Players.LocalPlayer.CharacterAdded:Connect(function() self:SetSprint(false) end))
    table.insert(self.Connections, UserInputService.WindowFocusReleased:Connect(function() self:SetSprint(false) end))
    return self
end

function Input:SetSprint(enabled)
    enabled = enabled == true
    if enabled and not self.UI:CanAct() then return end
    if self.Sprinting == enabled then return end
    self.Sprinting = enabled
    self.UI:SetSprint(enabled)
    self.UI:Request("Sprint", enabled)
end

function Input:Destroy()
    self:SetSprint(false)
    for _, name in ipairs(self.Bound) do ContextActionService:UnbindAction(name) end
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
end

return Input
