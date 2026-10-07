-- One bootstrap; gameplay, persistence, presentation, and defense stay modular.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local ctx = {
    Config = require(shared.Config), Schema = require(shared.ProfileSchema),
    Validation = require(shared.Utilities.Validation), Players = Players,
    ReplicatedStorage = ReplicatedStorage, Workspace = workspace,
    HttpService = game:GetService("HttpService"), Clock = os.time, Now = os.clock,
    Ready = {}, Closing = false,
}
local function construct(name) return require(script:WaitForChild(name)).new(ctx) end
ctx.Notify = function(player, text, kind, extra)
    if ctx.Remotes and player.Parent == Players then ctx.Remotes.Notification:FireClient(player, text, kind or "Info", extra) end
end
ctx.Announce = function(text) if ctx.Remotes then ctx.Remotes.Announcement:FireAllClients(text) end end
ctx.Request = function(player, action, ...) if ctx.Network then ctx.Network:Request(player, action, ...) end end
local publishing = {}
local function standings()
    local rows = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local profile = ctx.Data:Get(player)
        if profile and ctx.Ready[player] then
            local income = 0
            for _, record in ipairs(ctx.Houses:List(player)) do
                if record.BuildReadyAt <= ctx.Clock() and not ctx.Steal:IsHeld(record.Id) then income += ctx.Houses:Rate(record) end
            end
            table.insert(rows, { Name = player.DisplayName, UserId = player.UserId,
                Cash = profile.Cash, Income = income, Rebirths = 0 })
        end
    end
    table.sort(rows, function(a, b) return a.Income > b.Income end)
    return rows
end
ctx.Publish = function(player)
    if not ctx.Remotes or not ctx.Ready[player] or publishing[player] or player.Parent ~= Players then return end
    local profile, plot = ctx.Data:Get(player), ctx.World:GetPlot(player)
    if not profile or not plot then return end
    publishing[player] = true
    local status = ctx.Data:GetStatus(player)
    publishing[player] = nil
    local houses, rate = {}, 0
    for _, record in ipairs(ctx.Houses:List(player)) do
        local building = record.BuildReadyAt > ctx.Clock()
        if not building and not ctx.Steal:IsHeld(record.Id) then rate += ctx.Houses:Rate(record) end
        table.insert(houses, { Id = record.Id, DefinitionId = record.DefinitionId, Variant = record.Variant,
            Size = record.Size, Slot = record.Slot, Income = profile.Income[record.Id] or 0,
            Building = building, BuildRemaining = math.max(0, record.BuildReadyAt - ctx.Clock()) })
    end
    local market = {}
    for _, definition in ipairs(ctx.Config.Houses) do
        table.insert(market, { Id = definition.Id, DefinitionId = definition.Id, Variant = "Normal",
            Size = "Normal", Price = definition.Price, Income = definition.Income })
    end
    local carrier, lock = ctx.Steal.Carriers[player], ctx.Progression.Locks[player]
    local carry, hold
    if carrier then
        local name = ctx.Config.HouseById[carrier.Record.DefinitionId].Name
        if carrier.Phase == "Hold" then
            hold = { Name = name, Progress = math.clamp((ctx.Now() - carrier.StartedAt) / ctx.Config.Game.StealHoldSeconds, 0, 1) }
        else carry = { Name = name, Id = carrier.Id,
            SecondsRemaining = math.max(0, ctx.Config.Game.CarryTimeoutSeconds - (ctx.Now() - carrier.CarriedAt)),
            Committing = carrier.Phase == "Committing" } end
    end
    local speedLevel = math.floor(math.sqrt(profile.SpeedXP / 20))
    ctx.Remotes.Snapshot:FireClient(player, {
        Profile = ctx.Schema.Clone(profile), Houses = houses, Market = market, Standings = standings(), ServerTime = ctx.Clock(),
        Runtime = { DataMode = status.Mode, Writable = status.Writable, PlotId = plot.Id,
            Slots = ctx.Houses:Capacity(player), Multiplier = 1, IncomePerSecond = rate,
            LockRemaining = lock and math.max(0, lock.Until - ctx.Now()) or 0,
            LockCooldown = lock and math.max(0, lock.CooldownUntil - ctx.Now()) or 0,
            Carry = carry, StealHold = hold, Training = ctx.Progression.Training[player] == true,
            Speed = ctx.Progression:Speed(player), SpeedXP = profile.SpeedXP,
            TrainingRate = ctx.Config.Treadmills[profile.TreadmillLevel].Rate, NextSpeedXP = (speedLevel + 1) ^ 2 * 20,
            BaseLevel = profile.BaseLevel, TreadmillLevel = profile.TreadmillLevel,
            NextBase = ctx.Config.Bases[profile.BaseLevel + 1], NextTreadmill = ctx.Config.Treadmills[profile.TreadmillLevel + 1],
            NextSecurity = ctx.Config.Security[profile.SecurityLevel + 1], AtHome = ctx.World:AtHome(player),
        },
    })
end
ctx.Data = construct("DataService")
ctx.AntiExploit = construct("AntiExploitService")
ctx.Ownership = construct("OwnershipService")
ctx.World = construct("WorldService")
ctx.Houses = construct("HouseService")
ctx.Progression = construct("ProgressionService")
ctx.Wild = construct("WildHouseService")
ctx.Steal = construct("StealService")
ctx.Guards = construct("GuardService")
ctx.Network = construct("NetworkService")
ctx.Remotes = ctx.Network.Remotes
ctx.World:Init()
ctx.Wild:Start()
ctx.PlayerService = construct("PlayerService")
ctx.BeforeDataRelease = function(player) ctx.PlayerService:Cleanup(player) end
ctx.BeforeDataClose = function()
    ctx.Closing = true
    for _, player in ipairs(Players:GetPlayers()) do ctx.Steal:Release(player); ctx.Progression:Train(player, false) end
    ctx.Guards:Shutdown()
end
ctx.Data:Start()
ctx.PlayerService:Start()
local errors = {}
local function safe(name, callback)
    local ok, err = pcall(callback)
    if not ok and (not errors[name] or ctx.Now() - errors[name] > 10) then
        errors[name] = ctx.Now(); warn("[Steal a House]", name, err)
    end
end
task.spawn(function()
    local last, ticks = ctx.Now(), 0
    while not ctx.Closing do
        task.wait(0.2)
        local now = ctx.Now()
        local dt = math.min(now - last, 1)
        last, ticks = now, ticks + 1
        safe("Movement", function() ctx.AntiExploit:Tick() end)
        safe("Progression", function() ctx.Progression:Tick(dt) end)
        safe("Stealing", function() ctx.Steal:Tick(dt) end)
        safe("Guards", function() ctx.Guards:Tick(dt) end)
        safe("Rent", function() ctx.Houses:Tick(dt) end)
        safe("World", function() ctx.World:Tick(dt) end)
        if ticks % 5 == 0 then
            safe("Wild houses", function() ctx.Wild:Tick(dt) end)
            local rows = standings()
            safe("Standings", function() ctx.World:UpdateStandings(rows) end)
            for _, player in ipairs(Players:GetPlayers()) do safe("Snapshot", function() ctx.Publish(player) end) end
        end
    end
end)
