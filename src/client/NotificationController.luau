--!nonstrict
local Widgets = require(script.Parent.Widgets)
local TweenService = game:GetService("TweenService")
local Notifications = {}
Notifications.__index = Notifications

function Notifications.new(ui)
    local self = setmetatable({ UI = ui, Queue = {}, Running = false, Destroyed = false }, Notifications)
    ui.Toast = function(text, kind) self:Push(text, kind) end
    return self
end

function Notifications:SetSettings(settings)
    self.ReducedEffects = settings and settings.ReducedEffects == true
    if self.ReducedEffects and self.Tween then
        self.Tween:Cancel()
        if self.Current then
            self.Current.BackgroundTransparency, self.Current.TextTransparency = 0, 0
        end
    end
end

function Notifications:Push(text, kind, extra)
    if self.Destroyed or type(text) ~= "string" then return end
    if kind == "Shop" then
        if self.UI.Menu ~= "Shop" then self.UI:Open("Shop") end
        return
    end
    if kind == "ConfirmSell" then
        if type(extra) == "string" then self.UI:Open("Sell", extra) end
        return
    end
    if #self.Queue >= 6 then table.remove(self.Queue, 1) end
    table.insert(self.Queue, { Text = text:sub(1, 420), Kind = kind })
    self:ShowNext()
end

function Notifications:ShowNext()
    if self.Running or self.Destroyed or #self.Queue == 0 then return end
    self.Running = true
    local entry = table.remove(self.Queue, 1)
    local color = if entry.Kind == "Error" then Widgets.Colors.Danger
        elseif entry.Kind == "Announcement" then Widgets.Colors.Orange else Widgets.Colors.Teal
    local label = Widgets.Make("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0,
        Text = entry.Text, TextColor3 = Widgets.Colors.Text, TextWrapped = true,
        TextSize = 16, Font = Enum.Font.GothamBold, ZIndex = 20,
    }, self.UI.NoticeArea)
    Widgets.Round(label, 12)
    Widgets.Make("UIPadding", {
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
    }, label)
    label.TextScaled = true
    Widgets.Make("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = 16 }, label)
    self.Current = label
    if not self.ReducedEffects then
        label.BackgroundTransparency, label.TextTransparency = 1, 1
        self.Tween = TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0, TextTransparency = 0,
        })
        self.Tween:Play()
    end
    self.Timer = task.delay(5, function()
        if self.Destroyed then return end
        label:Destroy()
        self.Current, self.Running = nil, false
        self:ShowNext()
    end)
end

function Notifications:Destroy()
    self.Destroyed = true
    if self.Tween then self.Tween:Cancel() end
    if self.Timer and coroutine.status(self.Timer) ~= "dead" then task.cancel(self.Timer) end
    if self.Current then self.Current:Destroy() end
    self.Queue = {}
end

return Notifications
