--!strict
-- Migration never replaces a malformed existing save with a fresh profile.
-- Removed content remains recoverable in ArchivedItems rather than disappearing.
local Config = require(script.Parent.Config)
local TableUtils = require(script.Parent.Utilities.TableUtils)
local Validation = require(script.Parent.Utilities.Validation)
local ProfileSchema = { Version = 2 }

local statisticNames = {
    "ItemsStolen", "SuccessfulRobberies", "FailedRobberies", "RareItemsFound",
    "LegendaryItemsFound", "MythicItemsFound", "SecretItemsFound", "TotalCashEarned",
    "TotalCashSpent", "HousesRobbed", "TimesRobbed", "ItemsSold", "HouseUpgrades",
    "SecurityUpgrades", "BackpackUpgrades", "ToolUpgrades", "ItemsPlaced", "QuestsClaimed",
    "DailyRewardsClaimed", "EventsParticipated", "RecoveredItems", "PoliceCatches",
}

function ProfileSchema.New(now: number?): any
    local statistics = {}
    for _, name in ipairs(statisticNames) do statistics[name] = 0 end
    return {
        Version = 2, Cash = Config.Economy.StartingCash, Gems = 0, XP = 0, Level = 1,
        House = {
            Tier = 1, Theme = "Default", SecurityLevel = 1, Furniture = {}, HouseValue = 0,
            Exterior = { Wall = "Default", Floor = "Default", Roof = "Default", Door = "Default" },
        },
        Inventory = {}, ArchivedItems = {}, Collection = {}, OwnedThemes = { Default = true },
        Backpack = { Level = 1 }, Tools = { LockpickLevel = 1 }, Vehicles = {},
        Quests = { Daily = {}, Weekly = {}, Day = 0, Week = 0, Progress = {}, Claimed = {} },
        Achievements = {}, Statistics = statistics,
        Settings = { Music = true, SFX = true, Notifications = true, ReducedEffects = false,
            CameraShake = true, UIScale = 1 },
        DailyReward = { CurrentDay = 1, LastClaim = 0 },
        Playtime = 0, FirstJoin = true, TutorialStep = 1, CreatedAt = now or os.time(),
    }
end

local function numberValid(value: any, maximum: number?): boolean
    return Validation.Finite(value) and value >= 0 and (maximum == nil or value <= maximum)
end

local function validateEntries(entries: any, placed: boolean, seen: any): (boolean, string?)
    if type(entries) ~= "table" then return false, "Item container is not a table." end
    for uid, entry in pairs(entries) do
        if not Validation.Id(uid) or type(entry) ~= "table" or entry.UniqueId ~= uid
            or not Validation.Id(entry.ItemId) or not numberValid(entry.AcquiredAt) then
            return false, "An item has malformed ownership data."
        end
        if seen[uid] then return false, "Duplicate item UniqueId: " .. uid end
        seen[uid] = true
        if placed and (not Validation.Finite(entry.X) or not Validation.Finite(entry.Z)
            or not Validation.Integer(entry.Rotation, 0, 270) or entry.Rotation % 90 ~= 0) then
            return false, "An item has malformed placement data."
        end
    end
    return true, nil
end

function ProfileSchema.Validate(profile: any): (boolean, string?)
    if type(profile) ~= "table" or profile.Version ~= 2 then return false, "Invalid profile schema." end
    for _, name in ipairs({ "House", "Backpack", "Tools", "Quests", "Statistics", "Settings",
        "DailyReward", "Collection", "Achievements", "OwnedThemes", "Vehicles", "ArchivedItems" }) do
        if type(profile[name]) ~= "table" then return false, "Malformed profile field: " .. name end
    end
    if not numberValid(profile.Cash, Config.Economy.MaxCash) or not numberValid(profile.Gems, 1e12)
        or not numberValid(profile.XP, Config.Economy.MaxXP)
        or not Validation.Integer(profile.Level, 1, 1e12) then return false, "Malformed currency or XP." end
    if not Validation.Integer(profile.House.Tier, 1, #Config.Houses)
        or not Validation.Integer(profile.House.SecurityLevel, 1, #Config.Security)
        or type(profile.House.Theme) ~= "string" or not numberValid(profile.House.HouseValue)
        or type(profile.House.Exterior) ~= "table" then return false, "Malformed house." end
    if not Validation.Integer(profile.Backpack.Level, 1, #Config.Backpacks)
        or not Validation.Integer(profile.Tools.LockpickLevel, 1, #Config.Tools) then
        return false, "Malformed upgrade level."
    end
    if type(profile.FirstJoin) ~= "boolean" or not Validation.Integer(profile.TutorialStep, 1, 100)
        or not numberValid(profile.Playtime) or not numberValid(profile.CreatedAt) then
        return false, "Malformed progression metadata."
    end
    for _, name in ipairs(statisticNames) do
        if not numberValid(profile.Statistics[name], 1e15) then return false, "Malformed statistic: " .. name end
    end
    for _, name in ipairs({ "Music", "SFX", "Notifications", "ReducedEffects", "CameraShake" }) do
        if type(profile.Settings[name]) ~= "boolean" then return false, "Malformed setting: " .. name end
    end
    if not Validation.Finite(profile.Settings.UIScale) or profile.Settings.UIScale < 0.75
        or profile.Settings.UIScale > 1.5 then return false, "Malformed UI scale." end
    if not Validation.Integer(profile.DailyReward.CurrentDay, 1, #Config.Economy.DailyRewards)
        or not numberValid(profile.DailyReward.LastClaim) then return false, "Malformed daily reward." end
    for _, name in ipairs({ "Daily", "Weekly", "Progress", "Claimed" }) do
        if type(profile.Quests[name]) ~= "table" then return false, "Malformed quest field: " .. name end
    end
    if not Validation.Integer(profile.Quests.Day, 0) or not Validation.Integer(profile.Quests.Week, 0) then
        return false, "Malformed quest reset time."
    end
    for _, period in ipairs({ "Daily", "Weekly" }) do
        for index, id in pairs(profile.Quests[period]) do
            if not Validation.Integer(index, 1) or not Validation.Id(id) then
                return false, "Malformed assigned quest."
            end
        end
    end
    for key, progress in pairs(profile.Quests.Progress) do
        if not Validation.Id(key) or not Validation.Integer(progress, 0) then return false, "Malformed quest progress." end
    end
    for key, claimed in pairs(profile.Quests.Claimed) do
        if not Validation.Id(key) or type(claimed) ~= "boolean" then return false, "Malformed quest claim marker." end
    end
    for id, owned in pairs(profile.OwnedThemes) do
        if not Validation.Id(id) or type(owned) ~= "boolean" then return false, "Malformed cosmetic ownership." end
    end
    for id, state in pairs(profile.Achievements) do
        if not Validation.Id(id) then return false, "Malformed achievement ID." end
        if type(state) == "table" then
            if (state.Claimed ~= nil and type(state.Claimed) ~= "boolean")
                or (state.Unlocked ~= nil and type(state.Unlocked) ~= "boolean")
                or (state.Progress ~= nil and not numberValid(state.Progress)) then
                return false, "Malformed achievement progress."
            end
        elseif type(state) ~= "boolean" then return false, "Malformed achievement state." end
    end
    for id, entry in pairs(profile.Collection) do
        if not Validation.Id(id) or type(entry) ~= "table" or type(entry.Discovered) ~= "boolean"
            or not numberValid(entry.FirstFound) or not Validation.Integer(entry.Count, 0) then
            return false, "Malformed collection entry."
        end
    end
    local seen = {}
    local ok, err = validateEntries(profile.Inventory, false, seen)
    if not ok then return false, err end
    ok, err = validateEntries(profile.House.Furniture, true, seen)
    if not ok then return false, err end
    for uid, archived in pairs(profile.ArchivedItems) do
        if not Validation.Id(uid) or type(archived) ~= "table" or type(archived.Entry) ~= "table"
            or archived.Entry.UniqueId ~= uid or not Validation.Id(archived.Entry.ItemId)
            or not numberValid(archived.Entry.AcquiredAt) or seen[uid] then
            return false, "Malformed or duplicate archived item."
        end
        seen[uid] = true
    end
    return true, nil
end

local function normalizeEntries(entries: any, location: string, archive: any, seen: any): (any?, string?)
    if type(entries) ~= "table" then return nil, "Malformed " .. location .. " container." end
    local normalized = {}
    for key, raw in pairs(entries) do
        if type(raw) ~= "table" then return nil, "Malformed item entry." end
        local entry = TableUtils.Clone(raw)
        local uid = entry.UniqueId or (if type(key) == "string" then key else nil)
        if not Validation.Id(uid) or not Validation.Id(entry.ItemId) then return nil, "Item has no valid UniqueId or ItemId." end
        if seen[uid] or archive[uid] then return nil, "Duplicate item UniqueId: " .. uid end
        seen[uid] = true
        entry.UniqueId = uid
        if entry.AcquiredAt == nil then entry.AcquiredAt = 0 end
        if not numberValid(entry.AcquiredAt) then return nil, "Malformed acquisition timestamp." end
        if location == "Furniture" then
            if entry.X == nil and type(entry.Position) == "table" then
                entry.X = entry.Position.X or entry.Position.x or entry.Position[1]
                entry.Z = entry.Position.Z or entry.Position.z or entry.Position[3] or entry.Position[2]
            end
            if type(entry.Rotation) == "table" then
                entry.Rotation = entry.Rotation.Y or entry.Rotation.y or entry.Rotation[2] or 0
            end
            entry.Rotation = entry.Rotation or 0
            if not Validation.Finite(entry.X) or not Validation.Finite(entry.Z)
                or not Validation.Integer(entry.Rotation, 0, 270) or entry.Rotation % 90 ~= 0 then
                return nil, "Malformed furniture coordinates."
            end
        end
        if Config.Items[entry.ItemId] == nil then
            archive[uid] = { Entry = entry, Location = location, Reason = "UnknownItemId" }
        else
            normalized[uid] = entry
        end
    end
    return normalized, nil
end

function ProfileSchema.Migrate(raw: any, now: number?): (any?, string?)
    if type(raw) ~= "table" then return nil, "Existing save is not a profile." end
    local version = raw.Version or 1
    if not Validation.Integer(version, 1, 2) then return nil, "Unsupported profile version; existing data was preserved." end
    local profile = TableUtils.Clone(raw)
    TableUtils.Reconcile(profile, ProfileSchema.New(now))
    if type(profile.House) ~= "table" or type(profile.ArchivedItems) ~= "table" then
        return nil, "Malformed saved house or archive."
    end
    local seen = {}
    local inventory, inventoryError = normalizeEntries(profile.Inventory, "Inventory", profile.ArchivedItems, seen)
    if not inventory then return nil, inventoryError end
    local furniture, furnitureError = normalizeEntries(profile.House.Furniture, "Furniture", profile.ArchivedItems, seen)
    if not furniture then return nil, furnitureError end
    profile.Inventory, profile.House.Furniture = inventory, furniture
    if type(profile.Collection) == "table" then
        for id, entry in pairs(profile.Collection) do
            if entry == true then profile.Collection[id] = { Discovered = true, FirstFound = 0, Count = 1 } end
        end
    end
    profile.Version = 2
    local ok, err = ProfileSchema.Validate(profile)
    if not ok then return nil, err end
    -- XP is progress within the current level; preserve the separately saved Level.
    return profile, nil
end

ProfileSchema.Clone = TableUtils.Clone
ProfileSchema.Reconcile = TableUtils.Reconcile
function ProfileSchema.Default(startingCash: number?): any
    local profile = ProfileSchema.New()
    if startingCash ~= nil then profile.Cash = startingCash end
    return profile
end
return ProfileSchema
