--!nonstrict
local TweenService = game:GetService("TweenService")
local W = require(script.Parent.Widgets)
local Robbery = {}
Robbery.__index = Robbery

function Robbery.new(ctx)
    local self = setmetatable({ Context = ctx }, Robbery)
    self.AlarmBorder = W.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6),
        Position = UDim2.fromOffset(3, 3), Visible = false, ZIndex = 70 }, ctx.UI.Gui)
    self.Stroke = W.Make("UIStroke", { Color = W.Colors.Danger, Thickness = 5, Transparency = 0.2 }, self.AlarmBorder)
    return self
end

function Robbery:Heat(data)
    local heat = if type(data) == "table" then data.Heat else data
    self.Context.UI:UpdateHeat(heat)
end

function Robbery:Alarm(text)
    self.Context.Notifications:Push(text or "ALARM! Escape before the police reach you.", "Alarm", true)
    self.Context.Audio:Play("Alarm")
    local state = self.Context.State
    if state and state.Profile.Settings.ReducedEffects then return end
    self.Generation = (self.Generation or 0) + 1
    local generation = self.Generation
    self.AlarmBorder.Visible, self.Stroke.Transparency = true, 0.05
    TweenService:Create(self.Stroke, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true), { Transparency = 0.9 }):Play()
    self.Context.Camera:Shake(0.8)
    task.delay(4.2, function() if self.Generation == generation then self.AlarmBorder.Visible = false end end)
end

return Robbery
