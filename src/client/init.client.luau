--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UIController = require(script:WaitForChild("UIController"))
local InputController = require(script:WaitForChild("InputController"))
local NotificationController = require(script:WaitForChild("NotificationController"))
local AudioController = require(script:WaitForChild("AudioController"))
local remotes = ReplicatedStorage:WaitForChild("HouseRemotes")
local request = remotes:WaitForChild("Request")
local ui = UIController.new({ Config = Config, Request = function(action, ...) request:FireServer(action, ...) end })
local notifications = NotificationController.new(ui)
local audio = AudioController.new(Config)
local input = InputController.new(ui)
local connections = {}
local received = false
local lastMode, paused = nil, false
table.insert(connections, remotes:WaitForChild("Snapshot").OnClientEvent:Connect(function(snapshot)
    if type(snapshot) ~= "table" then return end
    received = true
    ui:SetSnapshot(snapshot)
    if snapshot.Profile then
        notifications:SetSettings(snapshot.Profile.Settings)
        audio:SetSettings(snapshot.Profile.Settings)
    end
    local runtime = snapshot.Runtime or {}
    if runtime.DataMode ~= lastMode then
        lastMode = runtime.DataMode
        if lastMode == "StudioMemory" then
            notifications:Push("Studio temporary mode: this test session does not save your progress.", "Announcement")
        end
    end
    local nowPaused = runtime.Writable ~= true
    if nowPaused and not paused then
        notifications:Push("Your data could not be safely saved. Gameplay actions are paused until the server recovers.", "Error")
        input:SetSprint(false)
    end
    paused = nowPaused
end))
table.insert(connections, remotes:WaitForChild("Notification").OnClientEvent:Connect(function(text, kind, extra)
    notifications:Push(text, kind, extra)
    audio:Notify(kind)
end))
table.insert(connections, remotes:WaitForChild("Announcement").OnClientEvent:Connect(function(text)
    notifications:Push(text, "Announcement")
end))
local retry = task.spawn(function()
    while not received and ui.Gui.Parent do
        request:FireServer("Sync")
        task.wait(5)
        if not received then ui.Status.Text = "Loading your base and saved data… reconnect if this message stays visible." end
    end
end)
script.Destroying:Connect(function()
    if coroutine.status(retry) ~= "dead" then task.cancel(retry) end
    for _, connection in ipairs(connections) do connection:Disconnect() end
    input:Destroy()
    notifications:Destroy()
    audio:Destroy()
    ui:Destroy()
end)
