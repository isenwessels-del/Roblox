--!nonstrict
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Input = {}
Input.__index = Input

function Input.new(ctx)
    local self = setmetatable({ Context = ctx, Sprinting = false }, Input)
    ContextActionService:BindAction("HeistSprint", function(_, state)
        if state == Enum.UserInputState.Begin then
            self.Sprinting = true
            ctx:Request("Gameplay", "RequestSprint", true)
        elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
            self.Sprinting = false
            ctx:Request("Gameplay", "RequestSprint", false)
        end
        return Enum.ContextActionResult.Sink
    end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
    ContextActionService:SetTitle("HeistSprint", "SPRINT")
    ContextActionService:SetPosition("HeistSprint", UDim2.new(1, -92, 1, -145))
    ContextActionService:BindActionAtPriority("HeistInventory", function(_, state)
        if state == Enum.UserInputState.Begin then ctx.UI:ToggleMenu("Inventory") end
        return Enum.ContextActionResult.Sink
    end, false, 2100, Enum.KeyCode.Tab, Enum.KeyCode.ButtonStart)
    ContextActionService:BindAction("HeistClose", function(_, state)
        if state == Enum.UserInputState.Begin and ctx.UI.ActiveMenu then ctx.UI:CloseMenu(); return Enum.ContextActionResult.Sink end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.ButtonB)
    UserInputService.WindowFocusReleased:Connect(function()
        if self.Sprinting then self.Sprinting = false; ctx:Request("Gameplay", "RequestSprint", false) end
    end)
    Players.LocalPlayer.CharacterRemoving:Connect(function() self.Sprinting = false end)
    return self
end

return Input
