--!nonstrict
local TweenService = game:GetService("TweenService")
local W = require(script.Parent.Widgets)
local Notifications = {}
Notifications.__index = Notifications

function Notifications.new(ctx)
    local self = setmetatable({ Context = ctx, Queue = {} }, Notifications)
    self.Container = W.Make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(1, -12, 0, 178),
        AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0.9, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 60 }, ctx.UI.Gui)
    W.Make("UISizeConstraint", { MaxSize = Vector2.new(390, 600) }, self.Container)
    W.Make("UIListLayout", { Padding = UDim.new(0, 7), HorizontalAlignment = Enum.HorizontalAlignment.Right }, self.Container)
    return self
end

function Notifications:Push(text, kind, force, overrideColor)
    local settings = self.Context.State and self.Context.State.Profile.Settings or {}
    if settings.Notifications == false and not force and kind ~= "Error" and kind ~= "Alarm" then return end
    if type(text) == "table" then text = text.Text or text.Message or "Notification" end
    text = tostring(text)
    local color = overrideColor or (if kind == "Error" or kind == "Alarm" then W.Colors.Danger elseif kind == "Warning" then W.Colors.Orange else W.Colors.Teal)
    local toast = W.Make("TextLabel", { BackgroundColor3 = W.Colors.Panel, BorderSizePixel = 0,
        Text = text, TextColor3 = color, Font = Enum.Font.GothamMedium, TextSize = 15, TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 65), ZIndex = 60 }, self.Container)
    W.Round(toast, 10)
    W.Make("UIStroke", { Color = color, Thickness = 1, Transparency = 0.5 }, toast)
    W.Make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, toast)
    table.insert(self.Queue, toast)
    if #self.Queue > 3 then local old = table.remove(self.Queue, 1); old:Destroy() end
    if not settings.ReducedEffects then
        toast.TextTransparency, toast.BackgroundTransparency = 1, 1
        TweenService:Create(toast, TweenInfo.new(0.18), { TextTransparency = 0, BackgroundTransparency = 0.03 }):Play()
    end
    task.delay(if force then 7 else 4, function()
        local index = table.find(self.Queue, toast)
        if index then table.remove(self.Queue, index) end
        if toast.Parent then toast:Destroy() end
    end)
end

function Notifications:Rare(data)
    if type(data) ~= "table" then return end
    local rarity = self.Context.Config.Rarities[data.Rarity]
    self:Push(tostring(data.Rarity or "Rare") .. " FIND!  " .. tostring(data.Name or data.ItemId)
        .. "  •  $" .. W.Number(data.Value) .. "\nEscape and return home to secure it.", "Rare", true, if rarity then W.Color(rarity.Color) else nil)
    self.Context.Audio:Play("Rare")
end

return Notifications
