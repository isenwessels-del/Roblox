-- Server-controlled anchored landlords pursue only their stolen wild prefab.
-- Navigation is cached; no client positions or NPC network ownership are trusted.
local Guard = {}
Guard.__index = Guard

local GRACE, RADIUS, CATCH_RADIUS, PATH_INTERVAL = 6, 60, 4, 1.5

local function horizontal(delta)
    return Vector3.new(delta.X, 0, delta.Z)
end

function Guard.new(ctx)
    local pathfinding = ctx.PathfindingService
    if pathfinding == nil then pathfinding = game:GetService("PathfindingService") end
    return setmetatable({ Context = ctx, Units = {}, Now = ctx.Now or os.clock,
        Spawn = ctx.Spawn or task.spawn, Pathfinding = pathfinding, Closed = false }, Guard)
end

function Guard:_unit(site)
    local unit = self.Units[site]
    if not unit then
        unit = { Site = site, Position = site.GuardOrigin, NextPath = 0, Generation = 0 }
        self.Units[site] = unit
    end
    return unit
end

function Guard:_clear(unit, state)
    if unit.State == state then return end
    unit.State, unit.Path, unit.Index = state, nil, nil
    unit.PathTarget, unit.NextPath = nil, 0
    unit.Generation += 1 -- Discard any yielding path result for a previous carry.
end

function Guard:_route(unit, target)
    if not self.Pathfinding or unit.Computing or self.Now() < unit.NextPath then return end
    if unit.PathTarget and horizontal(target - unit.PathTarget).Magnitude < 5 and unit.Path then return end
    unit.NextPath, unit.Computing = self.Now() + PATH_INTERVAL, true
    local generation, origin = unit.Generation, unit.Position
    self.Spawn(function()
        local ok, waypoints = pcall(function()
            local path = self.Pathfinding:CreatePath({ AgentRadius = 2.5, AgentHeight = 8,
                AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 5 })
            path:ComputeAsync(origin + Vector3.new(0, 2, 0), target)
            if path.Status == Enum.PathStatus.Success then return path:GetWaypoints() end
            return nil
        end)
        unit.Computing = false
        if self.Closed or generation ~= unit.Generation then return end
        unit.Path, unit.Index, unit.PathTarget = ok and waypoints or nil, 2, target
    end)
end

function Guard:_clearLine(unit, target, character)
    local scene = self.Context.Workspace
    if not scene or not scene.Raycast then return true end
    local params = RaycastParams.new()
    params.FilterType, params.RespectCanCollide = Enum.RaycastFilterType.Exclude, true
    params.FilterDescendantsInstances = { unit.Site.GuardModel }
    if character then table.insert(params.FilterDescendantsInstances, character) end
    local origin = unit.Position + Vector3.new(0, 3.5, 0)
    return scene:Raycast(origin, target - origin, params) == nil
end

function Guard:_move(unit, target, dt, character)
    self:_route(unit, target)
    local waypoint = target
    if unit.Path then
        while unit.Path[unit.Index] and horizontal(unit.Path[unit.Index].Position - unit.Position).Magnitude < 1.4 do
            unit.Index += 1
        end
        if unit.Path[unit.Index] then waypoint = unit.Path[unit.Index].Position end
    elseif not self:_clearLine(unit, target, character) then return end
    local delta = horizontal(waypoint - unit.Position)
    local distance = delta.Magnitude
    if distance <= 0.01 then return end
    local speed = math.clamp(7.5 + (unit.Site.Tier or 1) * 0.5, 8, 11)
    local position = unit.Position + delta.Unit * math.min(distance, speed * dt)
    position = Vector3.new(position.X, unit.Site.GuardOrigin.Y, position.Z)
    unit.Position = position
    unit.Site.GuardModel:PivotTo(CFrame.lookAt(position, position + delta.Unit))
end

function Guard:Tick(dt)
    if self.Closed or self.Context.Closing then return end
    if type(dt) ~= "number" or dt ~= dt or dt <= 0 then return end
    dt = math.min(dt, 0.25)
    local ctx, active = self.Context, {}
    for player, state in pairs(ctx.Steal.Carriers) do
        local site = state.Wild and state.Offer and state.Offer.Site
        if site and site.GuardModel and site.GuardModel.Parent and state.Phase == "Carry"
            and state.CarriedAt and self.Now() - state.CarriedAt >= GRACE
            and self.Now() - state.CarriedAt < ctx.Config.Game.CarryTimeoutSeconds
            and not ctx.World:AtHome(player) then
            local root = ctx.AntiExploit:Character(player)
            if root and horizontal(root.Position - site.GuardOrigin).Magnitude <= RADIUS then
                active[site] = { State = state, Root = root, Player = player }
            end
        end
    end
    for _, site in ipairs(ctx.World.WildSites) do
        if not site.GuardModel or not site.GuardModel.Parent then continue end
        local unit, target = self:_unit(site), active[site]
        self:_clear(unit, target and target.State or nil)
        if target then
            local delta = target.Root.Position - unit.Position
            if horizontal(delta).Magnitude <= CATCH_RADIUS and math.abs(delta.Y) <= 8
                and self:_clearLine(unit, target.Root.Position, target.Player.Character) then
                ctx.Steal:Cancel(target.Player, "The landlord caught you! Your prefab returned to its plot.")
                self:_clear(unit, nil)
            else
                self:_move(unit, target.Root.Position, dt, target.Player.Character)
            end
        elseif horizontal(site.GuardOrigin - unit.Position).Magnitude > 0.25 then
            self:_move(unit, site.GuardOrigin, dt)
        else
            unit.Position = site.GuardOrigin
            site.GuardModel:PivotTo(site.GuardFrame)
        end
    end
end

function Guard:Shutdown()
    self.Closed = true
    for _, unit in pairs(self.Units) do
        unit.Generation += 1
        if unit.Site.GuardModel and unit.Site.GuardModel.Parent then
            unit.Site.GuardModel:PivotTo(unit.Site.GuardFrame)
        end
    end
    self.Units = {}
end

return Guard
