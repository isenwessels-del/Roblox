-- Police decisions, navigation and capture are evaluated on the server.
-- Tick runs at a low frequency; no per-frame or client-controlled AI is used.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local PoliceService = {}
PoliceService.__index = PoliceService

local function characterRoot(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
        return root, character
    end
    return nil, character
end

local function flatDistance(first, second)
    local delta = first - second
    return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

local function rigPart(model, name, size, color, offset, spawnCFrame, collidable)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.CanCollide = collidable == true
    part.Massless = name ~= "HumanoidRootPart" and name ~= "Torso"
    part.CFrame = spawnCFrame * CFrame.new(offset)
    part.Parent = model
    return part
end

local function motor(name, first, second, c0, c1)
    local joint = Instance.new("Motor6D")
    joint.Name = name
    joint.Part0 = first
    joint.Part1 = second
    joint.C0 = c0
    joint.C1 = c1
    joint.Parent = first
end

local function createRig(parent, position)
    local model = Instance.new("Model")
    model.Name = "PoliceOfficer"
    local spawnCFrame = CFrame.new(position)
    local navy = Color3.fromRGB(34, 61, 113)
    local skin = Color3.fromRGB(238, 190, 133)
    local root = rigPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), navy, Vector3.zero, spawnCFrame, false)
    root.Transparency = 1
    local torso = rigPart(model, "Torso", Vector3.new(2, 2, 1), navy, Vector3.zero, spawnCFrame, true)
    local head = rigPart(model, "Head", Vector3.new(2, 1, 1), skin, Vector3.new(0, 1.5, 0), spawnCFrame, true)
    local leftArm = rigPart(model, "Left Arm", Vector3.new(1, 2, 1), navy, Vector3.new(-1.5, 0, 0), spawnCFrame, false)
    local rightArm = rigPart(model, "Right Arm", Vector3.new(1, 2, 1), navy, Vector3.new(1.5, 0, 0), spawnCFrame, false)
    local leftLeg = rigPart(model, "Left Leg", Vector3.new(1, 2, 1), navy, Vector3.new(-0.5, -2, 0), spawnCFrame, false)
    local rightLeg = rigPart(model, "Right Leg", Vector3.new(1, 2, 1), navy, Vector3.new(0.5, -2, 0), spawnCFrame, false)
    motor("RootJoint", root, torso, CFrame.new(), CFrame.new())
    motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
    motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
    motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
    motor("Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
    motor("Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))
    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "Humanoid"
    -- New Humanoids default to R6; RigType is not changed at runtime.
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.WalkSpeed = 19
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.BreakJointsOnDeath = false
    humanoid.Parent = model
    local badge = Instance.new("BillboardGui")
    badge.Name = "PoliceLabel"
    badge.Size = UDim2.fromOffset(125, 42)
    badge.StudsOffset = Vector3.new(0, 2, 0)
    badge.MaxDistance = 100
    badge.Adornee = head
    badge.Parent = head
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = "POLICE\nInvestigating"
    label.TextColor3 = Color3.fromRGB(154, 201, 255)
    label.TextStrokeTransparency = 0.2
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Parent = badge
    model.PrimaryPart = root
    model.Parent = parent
    -- A single welded assembly is explicitly owned by the server, not a nearby client.
    pcall(function() root:SetNetworkOwner(nil) end)
    return model, root, humanoid, label
end

function PoliceService.new(ctx)
    local self = setmetatable({}, PoliceService)
    self.Ctx = ctx
    self.Units = {}
    self.LastSpawn = {}
    self.Metrics = { Ticks = 0, PathRequests = 0, Spawned = 0, Despawned = 0, Captures = 0, Live = 0 }
    self.Destroyed = false
    self.Elapsed = 0
    local gameConfig = ctx.Config and (ctx.Config.Game or ctx.Config) or {}
    self.Maximum = math.clamp(tonumber(gameConfig.MaximumPolice) or 16, 1, 16)
    self.CatchRadius = math.clamp(tonumber(gameConfig.PoliceCatchRadius) or 5, 1, 5)
    local folder = Instance.new("Folder")
    folder.Name = "Police"
    folder.Parent = ctx.World and ctx.World.Map or workspace
    self.Folder = folder
    return self
end

function PoliceService:_heat(player)
    local value = self.Ctx.Heat:Get(player)
    if type(value) == "table" then value = value.Heat or value.Value end
    if type(value) ~= "number" or value ~= value then return 0 end
    return math.clamp(value, 0, 100)
end

function PoliceService:_active(player)
    local robbery = self.Ctx.Robbery:Get(player)
    return type(robbery) == "table" and robbery.Active == true
end

function PoliceService:_atHome(player, position)
    local world = self.Ctx.World
    return world and world.IsInHome and world:IsInHome(player, position) == true
end

function PoliceService:_visible(unit, player, target)
    local _, character = characterRoot(player)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = character and { self.Folder, character } or { self.Folder }
    params.RespectCanCollide = true
    local origin = unit.Root.Position + Vector3.new(0, 1.25, 0)
    return workspace:Raycast(origin, target + Vector3.new(0, 1, 0) - origin, params) == nil
end

function PoliceService:_spawnPosition(target)
    local points = self.Ctx.World and self.Ctx.World.PoliceSpawnPositions or {}
    local choices = {}
    for _, point in ipairs(points) do
        if typeof(point) == "Vector3" then
            local distance = flatDistance(point, target)
            if distance >= 50 and distance <= 160 then table.insert(choices, point) end
        end
    end
    -- Randomized traversal avoids stacking every officer on the same spawn marker.
    for index = #choices, 2, -1 do
        local other = math.random(index)
        choices[index], choices[other] = choices[other], choices[index]
    end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { self.Folder }
    rayParams.RespectCanCollide = true
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances = { self.Folder }
    overlap.MaxParts = 24
    for _, point in ipairs(choices) do
        local ground = workspace:Raycast(point + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), rayParams)
        if not ground or ground.Normal.Y < 0.7 then continue end
        local position = ground.Position + Vector3.new(0, 3.1, 0)
        local clear = true
        for _, player in ipairs(Players:GetPlayers()) do
            local root = characterRoot(player)
            if root and (root.Position - position).Magnitude < 12 then clear = false; break end
        end
        if clear then
            for _, unit in ipairs(self.Units) do
                if (unit.Root.Position - position).Magnitude < 8 then clear = false; break end
            end
        end
        if clear then
            for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(4, 5, 4), overlap)) do
                if part.CanCollide then clear = false; break end
            end
        end
        if clear then return position end
    end
    return nil
end

function PoliceService:_spawn(player, target)
    local position = self:_spawnPosition(target)
    if not position then return end
    local model, root, humanoid, label = createRig(self.Folder, position)
    model:SetAttribute("SuspectUserId", player.UserId)
    model:SetAttribute("PoliceState", "Investigating")
    local unit = {
        Player = player, Model = model, Root = root, Humanoid = humanoid, Label = label,
        State = "Investigating", Home = position, LastSeen = target, Born = self.Elapsed,
        LastSeenAt = self.Elapsed, LastPathAt = -math.huge, PathTarget = nil,
        Waypoints = {}, Waypoint = 1, PendingPath = false, PathGeneration = 0,
        Removed = false, ReturningAt = nil,
        LastPosition = position, LastMovedAt = self.Elapsed,
    }
    table.insert(self.Units, unit)
    self.Metrics.Spawned += 1
    self.Metrics.Live = #self.Units
    self.LastSpawn[player] = self.Elapsed
end

function PoliceService:_state(unit, name)
    if unit.State == name then return end
    unit.State = name
    unit.Model:SetAttribute("PoliceState", name)
    unit.Label.Text = "POLICE\n" .. name
    unit.Label.TextColor3 = name == "Chasing" and Color3.fromRGB(255, 117, 117) or Color3.fromRGB(154, 201, 255)
    unit.Humanoid.WalkSpeed = name == "Chasing" and 24 or 19
end

function PoliceService:_navigate(unit, target, visible)
    if (unit.Root.Position - unit.LastPosition).Magnitude >= 2 then
        unit.LastPosition = unit.Root.Position
        unit.LastMovedAt = self.Elapsed
    end
    if visible then
        -- Invalidate an in-flight path so it cannot overwrite fresh direct movement.
        if unit.PendingPath then unit.PathGeneration += 1; unit.PendingPath = false end
        unit.Waypoints = {}
        unit.PathTarget = nil
        unit.Humanoid:MoveTo(target)
        return
    end
    -- A newly closed door can invalidate an otherwise cached route.
    if not unit.PendingPath and self.Elapsed - unit.LastMovedAt >= 6
        and (unit.Root.Position - target).Magnitude > 8 then
        unit.PathTarget = nil
        unit.Waypoints = {}
        unit.LastMovedAt = self.Elapsed
    end
    local moved = not unit.PathTarget or (target - unit.PathTarget).Magnitude >= 10
    if not unit.PendingPath and self.Elapsed - unit.LastPathAt >= 3 and moved then
        unit.PendingPath = true
        unit.LastPathAt = self.Elapsed
        unit.PathTarget = target
        unit.PathGeneration += 1
        self.Metrics.PathRequests += 1
        local generation = unit.PathGeneration
        local origin = unit.Root.Position
        task.spawn(function()
            local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 5 })
            local ok = pcall(function() path:ComputeAsync(origin, target) end)
            if self.Destroyed or unit.Removed or generation ~= unit.PathGeneration then path:Destroy(); return end
            unit.PendingPath = false
            if ok and path.Status == Enum.PathStatus.Success then
                unit.Waypoints = path:GetWaypoints()
                unit.Waypoint = 2
            else
                unit.Waypoints = {}
                -- Failed routes may retry after the cooldown even if the suspect stands still.
                unit.PathTarget = nil
            end
            path:Destroy()
        end)
    end
    local waypoint = unit.Waypoints[unit.Waypoint]
    while waypoint and (unit.Root.Position - waypoint.Position).Magnitude < 4 do
        unit.Waypoint += 1
        waypoint = unit.Waypoints[unit.Waypoint]
    end
    if waypoint then
        if waypoint.Action == Enum.PathWaypointAction.Jump then unit.Humanoid.Jump = true end
        unit.Humanoid:MoveTo(waypoint.Position)
    end
end

function PoliceService:_destroy(index)
    local unit = self.Units[index]
    if not unit then return end
    unit.Removed = true
    unit.PathGeneration += 1
    unit.Model:Destroy()
    table.remove(self.Units, index)
    self.Metrics.Despawned += 1
    self.Metrics.Live = #self.Units
end

function PoliceService:_destroyUnit(unit)
    local index = table.find(self.Units, unit)
    if index then self:_destroy(index) end
end

function PoliceService:_return(unit)
    if not unit.ReturningAt then unit.ReturningAt = self.Elapsed end
    self:_state(unit, "Returning")
    self:_navigate(unit, unit.Home, false)
end

function PoliceService:Tick(dt)
    if self.Destroyed then return end
    self.Metrics.Ticks += 1
    local map = self.Ctx.World and self.Ctx.World.Map
    if map and map.Parent and self.Folder.Parent ~= map then self.Folder.Parent = map end
    self.Elapsed += math.clamp(tonumber(dt) or 1, 0, 5)
    -- A robbery failure can synchronously Remove() every officer for a suspect.
    -- Iterate a bounded snapshot so that callback removal cannot shift later entries.
    local units = table.clone(self.Units)
    for index = #units, 1, -1 do
        local unit = units[index]
        if unit.Removed then continue end
        local player = unit.Player
        local root = characterRoot(player)
        if not unit.Model.Parent or not unit.Root.Parent or unit.Humanoid.Health <= 0
            or player.Parent ~= Players or not root then
            self:_destroyUnit(unit)
            continue
        end
        local heat = self:_heat(player)
        local active = self:_active(player)
        if unit.ReturningAt or not active or heat <= 20 or self:_atHome(player, root.Position)
            or self.Elapsed - unit.Born >= 100 then
            self:_return(unit)
            if self.Elapsed - unit.ReturningAt >= 8 or (unit.Root.Position - unit.Home).Magnitude < 6 then
                self:_destroyUnit(unit)
            end
            continue
        end
        local visible = self:_visible(unit, player, root.Position)
        if heat >= 60 and visible then
            unit.LastSeen = root.Position
            unit.LastSeenAt = self.Elapsed
            self:_state(unit, "Chasing")
            -- LOS, life, position and active robbery are all checked again on the server.
            if (unit.Root.Position - root.Position).Magnitude <= self.CatchRadius then
                self.Metrics.Captures += 1
                local data = self.Ctx.Data
                if data and data:IsWritable(player) then
                    local profile = data:Get(player)
                    if profile and profile.Statistics then
                        profile.Statistics.PoliceCatches = (profile.Statistics.PoliceCatches or 0) + 1
                    end
                end
                self.Ctx.Robbery:Fail(player, "Caught by police")
                if not unit.Removed then self:_return(unit) end
                continue
            end
            self:_navigate(unit, root.Position, true)
        elseif unit.State == "Chasing" or unit.State == "Searching" then
            self:_state(unit, "Searching")
            self:_navigate(unit, unit.LastSeen, false)
            if self.Elapsed - unit.LastSeenAt >= 25 then self:_return(unit) end
        else
            self:_state(unit, "Investigating")
            if visible then unit.LastSeen = root.Position end
            self:_navigate(unit, unit.LastSeen, visible)
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if #self.Units >= self.Maximum then break end
        local root = characterRoot(player)
        local heat = self:_heat(player)
        if not root or heat < 40 or not self:_active(player) or self:_atHome(player, root.Position) then continue end
        local count = 0
        for _, unit in ipairs(self.Units) do
            if unit.Player == player then count += 1 end
        end
        local desired = heat >= 85 and 3 or (heat >= 60 and 2 or 1)
        if self.Ctx.Events and self.Ctx.Events:IsActive("PoliceRaid") then
            desired = math.min(3, desired + 1)
        end
        if count < desired and self.Elapsed - (self.LastSpawn[player] or -math.huge) >= 7 then
            self:_spawn(player, root.Position)
        end
    end
end

function PoliceService:Remove(player)
    for index = #self.Units, 1, -1 do
        if self.Units[index].Player == player then self:_destroy(index) end
    end
    self.LastSpawn[player] = nil
end

function PoliceService:Shutdown()
    self.Destroyed = true
    for index = #self.Units, 1, -1 do self:_destroy(index) end
    self.LastSpawn = {}
    self.Folder:Destroy()
end

return PoliceService
