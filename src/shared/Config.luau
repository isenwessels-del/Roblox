-- Original house definitions and balancing. No third-party models or purchase IDs.
local Config = {}

Config.Game = {
	MaxPlayers = 7,
	StartingCash = 500,
	StartingSlots = 10,
	MaxSlots = 20,
	MoveSpeed = 20,
	SprintSpeed = 26,
	CarrySpeed = 12,
	MovementTolerance = 14,
	InteractionRadius = 12,
	StealHoldSeconds = 2,
	CarryTimeoutSeconds = 90,
	BatRange = 9,
	BatCooldown = 1.2,
	JoinShieldSeconds = 30,
	LockSeconds = 60,
	LockCooldownSeconds = 20,
	AutoSaveSeconds = 60,
	SessionLeaseSeconds = 180,
	StudioPersistence = false,
	ProfileStore = "StealAHouse_NeighborhoodProfiles_v1",
	OwnershipStore = "StealAHouse_NeighborhoodOwnership_v1",
	IncomeCap = 1e12,
	MaxCash = 1e12,
	OfflineMaxSeconds = 14400,
	OfflineMultiplier = 0.25,
	WildRespawnSeconds = 20,
	WildMax = 18,
	ConstructionSeconds = 6,
	GrowthBigSeconds = 45,
	GrowthGiantSeconds = 120,
	Audio = { Music = "", Buy = "", Collect = "", Steal = "", Build = "", Rare = "", Hit = "" },
}

Config.Rarities = {
	Common = { Color = "B7C6CE", Rank = 1 },
	Uncommon = { Color = "72D680", Rank = 2 },
	Rare = { Color = "70B6FF", Rank = 3 },
	Epic = { Color = "B895FF", Rank = 4 },
	Legendary = { Color = "FFD36B", Rank = 5 },
	Mythic = { Color = "FF91BE", Rank = 6 },
	Secret = { Color = "A4FFF2", Rank = 7 },
}

Config.Houses = {
	{ Id = "starter_cottage", Name = "Starter Cottage", Rarity = "Common", Price = 250, Income = 2, Weight = 25, Style = "Cottage", Color = "F4D6A0" },
	{ Id = "garden_cottage", Name = "Garden Cottage", Rarity = "Common", Price = 750, Income = 5, Weight = 22, Style = "Cottage", Color = "A9D8B6" },
	{ Id = "brick_bungalow", Name = "Brick Bungalow", Rarity = "Common", Price = 1500, Income = 9, Weight = 19, Style = "Cottage", Color = "CC8F76" },
	{ Id = "sunny_cabin", Name = "Sunny Cabin", Rarity = "Common", Price = 3000, Income = 16, Weight = 16, Style = "Cottage", Color = "EFC876" },
	{ Id = "coastal_cottage", Name = "Coastal Cottage", Rarity = "Uncommon", Price = 5500, Income = 28, Weight = 13, Style = "Cottage", Color = "91CEDA" },
	{ Id = "orchard_house", Name = "Orchard House", Rarity = "Uncommon", Price = 9000, Income = 43, Weight = 11, Style = "Townhouse", Color = "BDD68B" },
	{ Id = "cedar_townhouse", Name = "Cedar Townhouse", Rarity = "Uncommon", Price = 15000, Income = 65, Weight = 9, Style = "Townhouse", Color = "BA967C" },
	{ Id = "copper_duplex", Name = "Copper Duplex", Rarity = "Uncommon", Price = 25000, Income = 100, Weight = 7, Style = "Townhouse", Color = "DA9E70" },
	{ Id = "glass_loft", Name = "Glass Loft", Rarity = "Rare", Price = 45000, Income = 170, Weight = 5, Style = "Modern", Color = "B4D6EB" },
	{ Id = "marina_villa", Name = "Marina Villa", Rarity = "Rare", Price = 75000, Income = 260, Weight = 4, Style = "Modern", Color = "7CB8D0" },
	{ Id = "hilltop_house", Name = "Hilltop House", Rarity = "Rare", Price = 125000, Income = 410, Weight = 3, Style = "Modern", Color = "D1CBAB" },
	{ Id = "atrium_estate", Name = "Atrium Estate", Rarity = "Rare", Price = 225000, Income = 680, Weight = 2.5, Style = "Modern", Color = "D6EEE4" },
	{ Id = "moonlight_manor", Name = "Moonlight Manor", Rarity = "Epic", Price = 400000, Income = 1150, Weight = 1.7, Style = "Castle", Color = "ABA0D4" },
	{ Id = "floating_chalet", Name = "Floating Chalet", Rarity = "Epic", Price = 750000, Income = 2050, Weight = 1.2, Style = "Cottage", Color = "A2D1DA" },
	{ Id = "crystal_keep", Name = "Crystal Keep", Rarity = "Epic", Price = 1400000, Income = 3600, Weight = 0.9, Style = "Castle", Color = "B4BDF0" },
	{ Id = "neon_penthouse", Name = "Neon Penthouse", Rarity = "Epic", Price = 2500000, Income = 6200, Weight = 0.65, Style = "Tower", Color = "CC9ADF" },
	{ Id = "golden_palace", Name = "Golden Palace", Rarity = "Legendary", Price = 4500000, Income = 10500, Weight = 0.4, Style = "Castle", Color = "E9C256" },
	{ Id = "sun_temple", Name = "Sun Temple", Rarity = "Legendary", Price = 8500000, Income = 19000, Weight = 0.28, Style = "Temple", Color = "F3B574" },
	{ Id = "cloud_citadel", Name = "Cloud Citadel", Rarity = "Legendary", Price = 16000000, Income = 33500, Weight = 0.18, Style = "Castle", Color = "EBDFBB" },
	{ Id = "aurora_mansion", Name = "Aurora Mansion", Rarity = "Mythic", Price = 30000000, Income = 58000, Weight = 0.10, Style = "Modern", Color = "EDA8D7" },
	{ Id = "starfall_tower", Name = "Starfall Tower", Rarity = "Mythic", Price = 55000000, Income = 97000, Weight = 0.06, Style = "Tower", Color = "B89BE8" },
	{ Id = "dragon_fortress", Name = "Dragon Fortress", Rarity = "Mythic", Price = 95000000, Income = 150000, Weight = 0.035, Style = "Castle", Color = "E98F9E" },
	{ Id = "void_observatory", Name = "Void Observatory", Rarity = "Secret", Price = 160000000, Income = 220000, Weight = 0.016, Style = "Tower", Color = "7887B7" },
	{ Id = "prismatic_sanctuary", Name = "Prismatic Sanctuary", Rarity = "Secret", Price = 250000000, Income = 320000, Weight = 0.008, Style = "Temple", Color = "93E7D4" },
}

Config.Variants = {
	{ Id = "Normal", Name = "Normal", Multiplier = 1, Weight = 84, Color = "FFFFFF" },
	{ Id = "Gold", Name = "Gold", Multiplier = 2, Weight = 12, Color = "FFD05E" },
	{ Id = "Rainbow", Name = "Rainbow", Multiplier = 4, Weight = 3, Color = "C6A5FF" },
	{ Id = "Void", Name = "Void", Multiplier = 8, Weight = 1, Color = "8579BC" },
}

Config.Sizes = {
	{ Id = "Normal", Name = "Normal", Scale = 1, IncomeMultiplier = 1, ThresholdSeconds = 0, GrowthSeconds = 0 },
	{ Id = "Big", Name = "Big", Scale = 1.25, IncomeMultiplier = 2, ThresholdSeconds = Config.Game.GrowthBigSeconds, GrowthSeconds = Config.Game.GrowthBigSeconds },
	{ Id = "Giant", Name = "Giant", Scale = 1.5, IncomeMultiplier = 4, ThresholdSeconds = Config.Game.GrowthGiantSeconds, GrowthSeconds = Config.Game.GrowthGiantSeconds },
}

Config.Bases = {
	{ Cost = 0, Slots = 10 }, { Cost = 5000, Slots = 12 },
	{ Cost = 50000, Slots = 14 }, { Cost = 250000, Slots = 16 },
	{ Cost = 1500000, Slots = 18 }, { Cost = 10000000, Slots = 20 },
}

Config.Treadmills = {
	{ Cost = 0, Rate = 0.5 }, { Cost = 1000, Rate = 1 },
	{ Cost = 5000, Rate = 2 }, { Cost = 15000, Rate = 4 },
	{ Cost = 50000, Rate = 8 }, { Cost = 150000, Rate = 12 },
	{ Cost = 500000, Rate = 20 }, { Cost = 1500000, Rate = 32 },
	{ Cost = 5000000, Rate = 50 }, { Cost = 15000000, Rate = 80 },
}

Config.Security = {
	{ Cost = 0, BonusSeconds = 0 }, { Cost = 7500, BonusSeconds = 10 },
	{ Cost = 60000, BonusSeconds = 20 }, { Cost = 400000, BonusSeconds = 35 },
	{ Cost = 2500000, BonusSeconds = 50 }, { Cost = 15000000, BonusSeconds = 70 },
}

-- Retained interface only. The reference does not establish a rebirth mechanic.
Config.Rebirths = {}
Config.DailyRewards = { 500, 1000, 2000, 4000, 7500, 12500, 25000 }

local function index(definitions)
	local result = {}
	for _, definition in ipairs(definitions) do
		assert(result[definition.Id] == nil, "Duplicate configuration ID")
		result[definition.Id] = definition
	end
	return result
end

Config.HouseById = index(Config.Houses)
Config.VariantById = index(Config.Variants)
Config.SizeById = index(Config.Sizes)

function Config.Speed(profile)
	local xp = type(profile) == "table" and profile.SpeedXP or 0
	if type(xp) ~= "number" or xp ~= xp or xp == math.huge or xp < 0 then xp = 0 end
	return math.min(80, Config.Game.MoveSpeed + math.floor(math.sqrt(xp / 20)) * 2)
end

function Config.SprintSpeed(profile)
	return Config.Speed(profile) + 6
end

return Config
