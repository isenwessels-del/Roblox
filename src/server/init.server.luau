-- Controlled startup. Services receive one private context and do not create globals.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local ctx = {
    Config = require(shared.Config), Schema = require(shared.ProfileSchema),
    Players = Players, ReplicatedStorage = ReplicatedStorage,
    HttpService = game:GetService("HttpService"), Lighting = game:GetService("Lighting"),
    Clock = os.time, Closing = false,
}
local function construct(name) return require(script:WaitForChild(name)).new(ctx) end
local network
ctx.Notify = function(player, text, kind)
    if ctx.Remotes and player.Parent == Players then ctx.Remotes.UI.Notification:FireClient(player, text, kind or "Info") end
end
ctx.Announce = function(text) if ctx.Remotes then ctx.Remotes.UI.Announcement:FireAllClients(text) end end
ctx.Request = function(player, action, ...) if network then network:Request(player, action, ...) end end
local publishing = {}
ctx.Publish = function(player)
    if publishing[player] or not ctx.Remotes or player.Parent ~= Players then return end
    local profile = ctx.Data:Get(player)
    local plot = ctx.World and ctx.World:GetPlot(player)
    if not profile or not plot then return end
    publishing[player] = true
    -- IsWritable may emit a status notification; the recursion guard keeps publishing bounded.
    local status = ctx.Data:GetStatus(player)
    publishing[player] = nil
    ctx.House:Value(player)
    ctx.Leaderboard:Update(player)
    local state = ctx.Robbery:Get(player)
    local carry = {}
    if state then for _, entry in pairs(state.Carry) do table.insert(carry, ctx.Schema.Clone(entry)) end end
    table.sort(carry, function(a, b) return a.UniqueId < b.UniqueId end)
    ctx.Remotes.UI.Snapshot:FireClient(player, {
        Profile = ctx.Schema.Clone(profile), Quests = ctx.Quest:Get(player), Leaderboard = ctx.Leaderboard:Get(),
        Runtime = {
            Heat = ctx.Heat:Get(player), Capacity = ctx.Inventory:Capacity(player), CarryWeight = ctx.Inventory:CarryWeight(player), Carry = carry,
            Robbery = { Active = state ~= nil, TargetHouse = state and state.TargetHouse, TargetName = state and state.TargetName },
            Plot = { Id = plot.Id, Origin = { X = plot.Origin.X, Y = plot.Origin.Y, Z = plot.Origin.Z } },
            DataStatus = status.Mode, DataWritable = status.Writable, DataError = status.Error,
            Event = ctx.Events:GetActive(), ShopPosition = { X = ctx.World.ShopPosition.X, Y = ctx.World.ShopPosition.Y, Z = ctx.World.ShopPosition.Z },
        },
    })
end
ctx.Data = construct("DataService")
ctx.Analytics = construct("AnalyticsService")
ctx.Events = construct("EventService")
ctx.AntiExploit = construct("AntiExploitService")
ctx.Economy = construct("EconomyService")
ctx.Inventory = construct("InventoryService")
ctx.House = construct("HouseService")
ctx.Heat = construct("HeatService")
ctx.Security = construct("SecurityService")
ctx.Quest = construct("QuestService")
ctx.World = construct("WorldService")
ctx.Items = construct("ItemService")
ctx.Robbery = construct("RobberyService")
ctx.Police = construct("PoliceService")
ctx.Leaderboard = construct("LeaderboardService")
ctx.PlayerService = construct("PlayerService")
network = construct("NetworkService")
ctx.Remotes = network.Remotes
ctx.World:Init()
ctx.Items:Start()
ctx.BeforeDataRelease = function(player) ctx.PlayerService:Cleanup(player) end
ctx.BeforeDataClose = function()
    ctx.Closing = true
    for _, player in ipairs(Players:GetPlayers()) do ctx.Robbery:Fail(player, "Server shutting down") end
    ctx.Police:Shutdown()
    ctx.Events:Destroy()
    ctx.Leaderboard:Flush()
end
ctx.PlayerService:Start()
ctx.Data:Start()
local lastError = {}
local function safeTick(name, fn)
    local ok, err = pcall(fn)
    if not ok and (not lastError[name] or os.clock() - lastError[name] > 15) then
        lastError[name] = os.clock()
        warn("[StealAHouse runtime]", name, err)
    end
end
task.spawn(function()
    local last, ticks = os.clock(), 0
    while not ctx.Closing do
        task.wait(0.5)
        local now = os.clock()
        local dt = math.min(now - last, 2)
        last, ticks = now, ticks + 1
        safeTick("Movement", function() ctx.AntiExploit:Tick() end)
        safeTick("Robbery", function() ctx.Robbery:Tick() end)
        safeTick("Heat", function() ctx.Heat:Tick(dt) end)
        safeTick("Police", function() ctx.Police:Tick(dt) end)
        safeTick("Loot", function() ctx.Items:Tick() end)
        safeTick("Events", function() ctx.Events:Tick(dt) end)
        safeTick("Leaderboards", function() ctx.Leaderboard:Tick(dt) end)
        for _, player in ipairs(Players:GetPlayers()) do
            if ctx.Data:Get(player) then
                safeTick("Progression", function() ctx.Quest:Tick(player, dt) end)
                if ctx.Data:IsWritable(player) then ctx.Data:Get(player).Playtime += dt end
                if ticks % 2 == 0 then safeTick("Snapshot", function() ctx.Publish(player) end) end
            end
        end
    end
end)
