--!nonstrict
-- Explicit client boot order. Clients display snapshots and request actions only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Context = { Config = Config, Remotes = remotes, State = nil }

function Context:Request(group, name, ...)
    local folder = self.Remotes:FindFirstChild(group)
    local remote = folder and folder:FindFirstChild(name)
    if remote and remote:IsA("RemoteEvent") then remote:FireServer(...)
    else
        warn("Missing game remote: " .. group .. "." .. name)
        if self.Notifications then self.Notifications:Push("This action is unavailable. Please rejoin if it continues.", "Error") end
    end
end

Context.UI = require(script.UIController).new(Context)
Context.Camera = require(script.CameraController).new(Context)
Context.Audio = require(script.AudioController).new(Context)
Context.Notifications = require(script.NotificationController).new(Context)
Context.Inventory = require(script.InventoryController).new(Context)
Context.House = require(script.HouseController).new(Context)
Context.Progression = require(script.ProgressionController).new(Context)
Context.Interaction = require(script.InteractionController).new(Context)
Context.Robbery = require(script.RobberyController).new(Context)
Context.Input = require(script.InputController).new(Context)

local uiRemotes = remotes:WaitForChild("UI")
uiRemotes:WaitForChild("Snapshot").OnClientEvent:Connect(function(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.Profile) ~= "table" or type(snapshot.Runtime) ~= "table" then return end
    Context.State = snapshot
    Context.UI:OnSnapshot(snapshot)
    Context.House:OnSnapshot(snapshot)
    Context.Audio:OnSnapshot(snapshot)
end)
uiRemotes:WaitForChild("Notification").OnClientEvent:Connect(function(text, kind)
    Context.Notifications:Push(text, kind)
    if (kind == "Shop" or kind == "House") and Context.UI.ActiveMenu ~= kind then Context.UI:ToggleMenu(kind) end
    if kind == "Success" then Context.Audio:Play("Success") end
end)
uiRemotes:WaitForChild("RareItemFound").OnClientEvent:Connect(function(data) Context.Notifications:Rare(data) end)
uiRemotes:WaitForChild("AlarmTriggered").OnClientEvent:Connect(function(text) Context.Robbery:Alarm(text) end)
uiRemotes:WaitForChild("HeatChanged").OnClientEvent:Connect(function(heat) Context.Robbery:Heat(heat) end)
uiRemotes:WaitForChild("Announcement").OnClientEvent:Connect(function(text) Context.Notifications:Push(text, "Announcement", true) end)
-- Join snapshots can precede client readiness. A bounded retry handles that race.
Context:Request("UI", "RequestSync")
task.spawn(function()
    for _ = 1, 5 do
        task.wait(3)
        if Context.State then return end
        Context:Request("UI", "RequestSync")
    end
end)
