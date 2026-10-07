-- Optional, bounded client audio. Empty configuration IDs keep the game silent.
local SoundService = game:GetService("SoundService")
local Audio = {}
Audio.__index = Audio

local notificationSounds = {
    Stolen = "Steal", Collected = "Collect", Built = "Build", Rare = "Rare",
    Success = "Buy", Hit = "Hit",
}

local function soundId(value)
    if type(value) ~= "string" and type(value) ~= "number" then return nil end
    local id = tostring(value):match("^rbxassetid://(%d+)$") or tostring(value):match("^(%d+)$")
    if not id or tonumber(id) == 0 then return nil end
    return "rbxassetid://" .. id
end

function Audio.new(config)
    local self = setmetatable({ Sounds = {}, MusicEnabled = true, SFXEnabled = true }, Audio)
    self.Folder = Instance.new("Folder")
    self.Folder.Name = "StealAHouseAudio"
    self.Folder.Parent = SoundService
    for key, value in pairs(config.Game.Audio or {}) do
        local id = soundId(value)
        if id then
            local sound = Instance.new("Sound")
            sound.Name, sound.SoundId = key, id
            sound.Volume = if key == "Music" then 0.2 else 0.35
            sound.Looped = key == "Music"
            sound.Parent = self.Folder
            self.Sounds[key] = sound
        end
    end
    return self
end

function Audio:SetSettings(settings)
    settings = settings or {}
    self.MusicEnabled, self.SFXEnabled = settings.Music ~= false, settings.SFX ~= false
    local music = self.Sounds.Music
    if music then
        if self.MusicEnabled and not music.IsPlaying then music:Play()
        elseif not self.MusicEnabled then music:Stop() end
    end
    if not self.SFXEnabled then
        for key, sound in pairs(self.Sounds) do if key ~= "Music" then sound:Stop() end end
    end
end

function Audio:Notify(kind)
    if not self.SFXEnabled then return end
    local sound = self.Sounds[notificationSounds[kind]]
    if sound then sound:Stop(); sound:Play() end
end

function Audio:Destroy()
    self.Folder:Destroy()
    self.Sounds = {}
end

return Audio
