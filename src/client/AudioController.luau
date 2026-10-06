--!nonstrict
local SoundService = game:GetService("SoundService")
local Audio = {}
Audio.__index = Audio

function Audio.new(ctx)
    local self = setmetatable({ Context = ctx, Sounds = {} }, Audio)
    -- Zero/unset assets remain silent. Only developer-provided, licensed assets play.
    for name, id in pairs(ctx.Config.Game.Audio or {}) do
        if type(id) == "number" and id > 0 then
            local sound = Instance.new("Sound")
            sound.Name, sound.SoundId = "StealAHouse_" .. name, "rbxassetid://" .. tostring(id)
            sound.Volume, sound.Looped = if name == "Music" then 0.25 else 0.45, name == "Music"
            sound.Parent = SoundService
            self.Sounds[name] = sound
        end
    end
    return self
end

function Audio:Play(name)
    local settings = self.Context.State and self.Context.State.Profile.Settings or {}
    if name == "Music" and settings.Music == false or name ~= "Music" and settings.SFX == false then return end
    local sound = self.Sounds[name]
    if sound then sound:Play() end
end

function Audio:OnSnapshot(state)
    local settings = state.Profile.Settings
    for name, sound in pairs(self.Sounds) do
        local enabled = if name == "Music" then settings.Music else settings.SFX
        if not enabled then sound:Stop()
        elseif name == "Music" and not sound.IsPlaying then sound:Play() end
    end
end

return Audio
