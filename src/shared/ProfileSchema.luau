-- Ownership belongs to the canonical per-house ledger, never to this profile.
-- Fail closed on malformed saved values, including serialized economy intents.
local Config = require(script.Parent.Config)
local Schema = { Version = 2 }

local function number(value, minimum, maximum, integer)
	return type(value) == "number" and value == value and value ~= math.huge
		and value ~= -math.huge and value >= minimum and value <= maximum
		and (not integer or value == math.floor(value))
end

local function identifier(value)
	return type(value) == "string" and #value >= 1 and #value <= 100
		and string.match(value, "^[%w_%-:]+$") ~= nil
end

local function fields(value, allowed)
	if type(value) ~= "table" or getmetatable(value) ~= nil then return false end
	for key in pairs(value) do
		if type(key) ~= "string" or not allowed[key] then return false end
	end
	return true
end

local profileFields = {
	Version = true, HasStarter = true, Cash = true, Bank = true, Rebirths = true,
	BaseLevel = true, TreadmillLevel = true, SpeedXP = true, SecurityLevel = true,
	Collection = true, Statistics = true, Income = true, Settings = true,
	LastSeen = true, DailyDay = true, DailyStreak = true, Pending = true, CreatedAt = true,
}
local statisticFields = { Bought = true, Stolen = true, Defended = true, TotalEarned = true, TotalSpent = true }
local settingFields = { Music = true, SFX = true, ReducedEffects = true }
local pendingFields = {
	Kind = true, Id = true, DefinitionId = true, Variant = true, Size = true, Slot = true,
	Price = true, OperationId = true, CreatedAt = true, ExpectedRevision = true,
}

local function pendingValid(pending)
	if pending == nil then return true end
	if not fields(pending, pendingFields) or not identifier(pending.Id)
		or not identifier(pending.OperationId) or not number(pending.CreatedAt, 0, 1e12, true) then return false end
	if pending.Kind ~= "Buy" and pending.Kind ~= "Sell" and pending.Kind ~= "Starter"
		and pending.Kind ~= "Wild" then return false end
	if pending.DefinitionId ~= nil and not Config.HouseById[pending.DefinitionId] then return false end
	if pending.Variant ~= nil and not Config.VariantById[pending.Variant] then return false end
	if pending.Size ~= nil and not Config.SizeById[pending.Size] then return false end
	if pending.Slot ~= nil and not number(pending.Slot, 1, Config.Game.MaxSlots, true) then return false end
	if pending.Price ~= nil and not number(pending.Price, 0, Config.Game.MaxCash, false) then return false end
	if pending.ExpectedRevision ~= nil and not number(pending.ExpectedRevision, 0, 1e12, true) then return false end
	if pending.Kind == "Sell" then
		return pending.Price ~= nil and number(pending.ExpectedRevision, 1, 1e12 - 1, true)
	end
	if pending.DefinitionId == nil or pending.Variant == nil or pending.Size == nil or pending.Slot == nil then return false end
	if pending.Kind == "Buy" then return pending.Price ~= nil end
	return pending.Price == nil or pending.Price == 0
end

function Schema.New(now)
	now = now or os.time()
	assert(number(now, 0, 1e12, true), "Invalid profile creation time")
	return {
		Version = Schema.Version, HasStarter = false, Cash = Config.Game.StartingCash, Bank = 0,
		Rebirths = 0, BaseLevel = 1, TreadmillLevel = 1, SpeedXP = 0, SecurityLevel = 1,
		Collection = {}, Statistics = { Bought = 0, Stolen = 0, Defended = 0, TotalEarned = 0, TotalSpent = 0 },
		Income = {}, Settings = { Music = true, SFX = true, ReducedEffects = false },
		LastSeen = now, DailyDay = -1, DailyStreak = 0, CreatedAt = now,
	}
end

function Schema.Validate(profile)
	if not fields(profile, profileFields) or profile.Version ~= Schema.Version
		or type(profile.HasStarter) ~= "boolean"
		or not number(profile.Cash, 0, Config.Game.MaxCash, false)
		or not number(profile.Bank, 0, Config.Game.IncomeCap, false)
		or not number(profile.Rebirths, 0, 0, true)
		or not number(profile.BaseLevel, 1, #Config.Bases, true)
		or not number(profile.TreadmillLevel, 1, #Config.Treadmills, true)
		or not number(profile.SpeedXP, 0, 1e12, false)
		or not number(profile.SecurityLevel, 1, #Config.Security, true)
		or not number(profile.LastSeen, 0, 1e12, true)
		or not number(profile.CreatedAt, 0, 1e12, true)
		or not number(profile.DailyDay, -1, 1e8, true)
		or not number(profile.DailyStreak, 0, #Config.DailyRewards, true)
		or not pendingValid(profile.Pending) then return false end
	if not fields(profile.Statistics, statisticFields) or not fields(profile.Settings, settingFields)
		or type(profile.Collection) ~= "table" or getmetatable(profile.Collection) ~= nil
		or type(profile.Income) ~= "table" or getmetatable(profile.Income) ~= nil then return false end
	for name in pairs(statisticFields) do
		local counter = name == "Bought" or name == "Stolen" or name == "Defended"
		if not number(profile.Statistics[name], 0, 1e15, counter) then return false end
	end
	for name in pairs(settingFields) do if type(profile.Settings[name]) ~= "boolean" then return false end end
	local collections = 0
	for id, collected in pairs(profile.Collection) do
		collections += 1
		if not Config.HouseById[id] or collected ~= true or collections > #Config.Houses then return false end
	end
	local incomes = 0
	for id, value in pairs(profile.Income) do
		incomes += 1
		if not identifier(id) or not number(value, 0, Config.Game.IncomeCap, false)
			or incomes > 100 then return false end
	end
	return true
end

function Schema.Clone(profile)
	assert(Schema.Validate(profile), "Invalid profile")
	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, item in pairs(value) do result[key] = copy(item) end
		return result
	end
	return copy(profile)
end

function Schema.Migrate(raw, now)
	if type(raw) ~= "table" then return nil, "InvalidProfile" end
	-- This game has its own namespace; old furniture-game profiles are rejected.
	if raw.Version ~= Schema.Version then return nil, "UnsupportedProfileVersion" end
	if not Schema.Validate(raw) then return nil, "InvalidProfile" end
	return Schema.Clone(raw)
end

return Schema
