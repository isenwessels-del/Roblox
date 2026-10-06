--!nonstrict
-- Placement uses a local overhead camera. All world movement stays server-controlled.
local Camera = {}
Camera.__index = Camera
function Camera.new(ctx)
    local self = setmetatable({ Context = ctx }, Camera)
    game:GetService("RunService"):BindToRenderStep("HeistCameraEffects", Enum.RenderPriority.Camera.Value + 1, function()
        if not self.ShakeUntil or os.clock() > self.ShakeUntil then return end
        local camera = workspace.CurrentCamera
        local profile = self.Context.State and self.Context.State.Profile
        if not camera or camera.CameraType ~= Enum.CameraType.Custom or profile and (profile.Settings.CameraShake == false or profile.Settings.ReducedEffects) then return end
        local amplitude = math.max(0, self.ShakeUntil - os.clock()) * 0.08
        camera.CFrame *= CFrame.new(math.sin(os.clock() * 65) * amplitude, math.cos(os.clock() * 47) * amplitude, 0)
    end)
    return self
end
function Camera:Shake(duration) self.ShakeUntil = os.clock() + duration end
function Camera:Placement(origin)
    self:Restore()
    local camera = workspace.CurrentCamera
    if not camera then return end
    self.Previous = { Camera = camera, Type = camera.CameraType, Subject = camera.CameraSubject, CFrame = camera.CFrame }
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.lookAt(origin + Vector3.new(0, 58, 34), origin, Vector3.yAxis)
end
function Camera:Restore()
    local old = self.Previous
    if not old then return end
    self.Previous = nil
    if old.Camera and old.Camera.Parent then
        old.Camera.CameraType = old.Type
        old.Camera.CameraSubject = old.Subject
        old.Camera.CFrame = old.CFrame
    end
end
return Camera
