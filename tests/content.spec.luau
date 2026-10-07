-- Executed against the actual modules by content_runner.py. Roblox require
-- lookup is adapted only; configuration and schema behavior remain unchanged.
local Config = require("../src/shared/Config")
local Schema = require("../src/shared/ProfileSchema")

local checks = 0
local function expect(condition, description)
	checks += 1
	assert(condition, description)
end

local function bad(change, label)
	local profile = Schema.New(1000)
	change(profile)
	local ok, valid = pcall(Schema.Validate, profile)
	expect(ok and valid == false, "Malformed profile must fail closed: " .. label)
end

expect(Config.Game.MaxPlayers == 7, "Seven simultaneous home bases")
expect(Config.Game.StartingCash == 500, "Starter cash")
expect(Config.Game.ProfileStore ~= Config.Game.OwnershipStore, "Separate durable ledgers")
expect(Config.Game.ProfileStore ~= "StealAHouseProfiles_v2", "Furniture saves remain isolated")
expect(Config.Game.StudioPersistence == false, "Studio default uses isolated memory")
expect(Config.Game.AutoSaveSeconds < Config.Game.SessionLeaseSeconds - 15, "Renew before lease expires")
expect(#Config.Houses == 24, "Twenty-four original collectible houses")
expect(#Config.Variants == 4 and #Config.Sizes == 3, "Mutations and sizes")
expect(#Config.Rebirths == 0, "Unsupported rebirth does not offer fake progression")
expect(#Config.Bases == 6 and #Config.Treadmills >= 8 and #Config.Security == 6, "All real upgrades available")
expect(#Config.DailyRewards == 7, "Daily reward cycle")
local rarityCount, rarityCoverage = 0, {}
for id, rarity in pairs(Config.Rarities) do
	rarityCount += 1
	expect(string.match(rarity.Color, "^[%x]+$") ~= nil and #rarity.Color == 6, "Rarity RGB")
	expect(rarity.Rank >= 1 and rarity.Rank <= 7, "Rarity rank")
	rarityCoverage[id] = 0
end
expect(rarityCount == 7, "Seven rarities")
local previousPrice, previousIncome = 0, 0
for _, house in ipairs(Config.Houses) do
	expect(Config.HouseById[house.Id] == house, "Map preserves exact definition")
	expect(type(house.Name) == "string" and #house.Name > 0, "Readable original name")
	expect(rarityCoverage[house.Rarity] ~= nil, "Known rarity")
	expect(house.Price > previousPrice and house.Income > previousIncome, "Ordered progression")
	expect(house.Weight > 0 and house.Weight < math.huge, "Selectable weighted house")
	expect(type(house.Style) == "string" and #house.Style > 0, "Procedural model style")
	expect(string.match(house.Color, "^[%x]+$") ~= nil and #house.Color == 6, "House RGB")
	rarityCoverage[house.Rarity] += 1
	previousPrice, previousIncome = house.Price, house.Income
end
for _, count in pairs(rarityCoverage) do expect(count >= 2, "Every rarity has multiple collectible houses") end

local variantWeight, multiplier = 0, 0
for _, variant in ipairs(Config.Variants) do
	expect(Config.VariantById[variant.Id] == variant, "Variant map matches array")
	expect(variant.Multiplier > multiplier and variant.Weight > 0, "Mutation strength and rarity")
	variantWeight += variant.Weight
	multiplier = variant.Multiplier
end
expect(variantWeight == 100, "Mutation weights cover explicit percentage distribution")
expect(Config.VariantById.Normal.Multiplier == 1, "Starter normal income")
expect(Config.SizeById.Normal.ThresholdSeconds == 0, "Fresh box is normal")
expect(Config.SizeById.Big.ThresholdSeconds == 45, "Big growth time")
expect(Config.SizeById.Giant.ThresholdSeconds == 120, "Giant growth time")
for _, size in ipairs(Config.Sizes) do
	expect(Config.SizeById[size.Id] == size and size.Scale >= 1 and size.IncomeMultiplier >= 1, "Valid size model/income")
end
local lastSlots, lastCost = 0, -1
for _, base in ipairs(Config.Bases) do
	expect(base.Slots > lastSlots and base.Slots <= Config.Game.MaxSlots, "Bounded capacity progression")
	expect(base.Cost > lastCost, "Base cost progression")
	lastSlots, lastCost = base.Slots, base.Cost
end
expect(Config.Bases[1].Slots == 10 and Config.Bases[#Config.Bases].Slots == 20, "Launch slot boundaries")
lastCost = -1
local lastRate = 0
for _, treadmill in ipairs(Config.Treadmills) do
	expect(treadmill.Cost > lastCost and treadmill.Rate > lastRate, "Actual training progression")
	lastCost, lastRate = treadmill.Cost, treadmill.Rate
end
lastCost = -1
local lastBonus = -1
for _, security in ipairs(Config.Security) do
	expect(security.Cost > lastCost and security.BonusSeconds > lastBonus, "Actual lock progression")
	lastCost, lastBonus = security.Cost, security.BonusSeconds
end

expect(Config.Speed({ SpeedXP = 0 }) == 20, "Initial earned speed")
expect(Config.Speed({ SpeedXP = 19 }) == 20, "Speed increases only at threshold")
expect(Config.Speed({ SpeedXP = 20 }) == 22, "First training threshold")
expect(Config.Speed({ SpeedXP = 80 }) == 24, "Square-root training speed")
expect(Config.Speed({ SpeedXP = 18000 }) == 80, "Earned speed cap")
expect(Config.Speed({ SpeedXP = 1e12 }) == 80, "Extreme experience remains capped")
expect(Config.SprintSpeed({ SpeedXP = 18000 }) == 86, "Sprint bonus respects earned speed")
for _, xp in ipairs({ -1, math.huge, -math.huge, "100" }) do
	expect(Config.Speed({ SpeedXP = xp }) == 20, "Malformed speed cannot grant advantage")
end
expect(Config.Speed({ SpeedXP = 0 / 0 }) == 20, "NaN speed is safe")
expect(Config.Speed(nil) == 20, "Missing profile speed is safe")

local fresh = Schema.New(1000)
expect(Schema.Version == 2 and fresh.Version == 2, "Persistence envelope compatibility")
expect(Schema.Validate(fresh), "New profile validates")
expect(fresh.HasStarter == false and fresh.Pending == nil, "Starter requires durable award intent")
expect(fresh.DailyDay == -1 and fresh.DailyStreak == 0, "First daily reward is claimable")
expect(fresh.LastSeen == 1000 and fresh.CreatedAt == 1000, "Server creation timestamps")
expect(next(fresh.Income) == nil and next(fresh.Collection) == nil, "No fabricated ownership or income")
expect(fresh.Cash == 500 and fresh.Bank == 0 and fresh.Rebirths == 0, "Starter resources")
local cloned = Schema.Clone(fresh)
expect(cloned ~= fresh and cloned.Settings ~= fresh.Settings and cloned.Income ~= fresh.Income, "Deep independent snapshot")
cloned.Settings.Music = false
cloned.Income["house-1"] = 12
expect(fresh.Settings.Music == true and next(fresh.Income) == nil, "Snapshot cannot mutate original")
local migrated = Schema.Migrate(fresh, 1500)
expect(migrated ~= fresh and Schema.Validate(migrated) and migrated.LastSeen == 1000, "Valid load preserves offline timestamps")
local old = Schema.New(1000)
old.Version = 1
local result, reason = Schema.Migrate(old)
expect(result == nil and reason == "UnsupportedProfileVersion", "Unknown old game cannot create a second starter")
old.Version = 3
expect(Schema.Migrate(old) == nil, "Future schema rejected")
expect(Schema.Migrate(nil) == nil, "Missing raw data cannot masquerade as valid load")

bad(function(p) p.Cash = -1 end, "negative cash")
bad(function(p) p.Cash = 1e12 + 1 end, "cash cap")
bad(function(p) p.Cash = 0 / 0 end, "NaN cash")
bad(function(p) p.Cash = math.huge end, "infinite cash")
bad(function(p) p.Bank = -1 end, "negative bank")
bad(function(p) p.HasStarter = nil end, "unknown starter award status")
bad(function(p) p.Rebirths = 1 end, "inactive rebirth")
bad(function(p) p.BaseLevel = 7 end, "nonexistent base upgrade")
bad(function(p) p.BaseLevel = 1.5 end, "fractional base level")
bad(function(p) p.TreadmillLevel = 11 end, "nonexistent treadmill")
bad(function(p) p.SecurityLevel = 7 end, "nonexistent security")
bad(function(p) p.SpeedXP = -0.1 end, "negative experience")
bad(function(p) p.LastSeen = -1 end, "negative last seen")
bad(function(p) p.CreatedAt = "1000" end, "string timestamp")
bad(function(p) p.DailyDay = -2 end, "invalid day sentinel")
bad(function(p) p.DailyDay = 1.5 end, "fractional day")
bad(function(p) p.DailyStreak = 8 end, "out of cycle streak")
bad(function(p) p.Unknown = true end, "unexpected serialized field")
bad(function(p) p.Collection.missing = true end, "unknown collectible")
bad(function(p) p.Collection.starter_cottage = false end, "noncollection value")
bad(function(p) p.Collection[1] = true end, "array collection")
bad(function(p) p.Statistics = nil end, "missing statistics")
bad(function(p) p.Statistics.Bought = -1 end, "negative counter")
bad(function(p) p.Statistics.Stolen = 1.5 end, "fractional counter")
bad(function(p) p.Statistics.NewField = 3 end, "unknown statistic")
bad(function(p) p.Settings.SFX = 1 end, "nonboolean setting")
bad(function(p) p.Settings.NewField = true end, "unknown setting")
bad(function(p) p.Income[""] = 1 end, "empty UID")
bad(function(p) p.Income[string.rep("x", 101)] = 1 end, "oversized UID")
bad(function(p) p.Income["house.1"] = 1 end, "unapproved UID characters")
bad(function(p) p.Income["house-1"] = 0 / 0 end, "NaN income")
bad(function(p) p.Income["house-1"] = -1 end, "negative income")
bad(function(p) for i = 1, 101 do p.Income["house-" .. i] = 0 end end, "bounded income map")
bad(function(p) setmetatable(p.Income, {}) end, "unserializable metatable")
bad(function(p) setmetatable(p, {}) end, "profile metatable")

local function intent(kind)
	return { Kind = kind, Id = "house-123", DefinitionId = Config.Houses[1].Id,
		Variant = "Normal", Size = "Normal", Slot = 1, Price = if kind == "Buy" then 250 else 0,
		OperationId = "op-123:award", CreatedAt = 1000, ExpectedRevision = if kind == "Sell" then 1 else nil }
end
for _, kind in ipairs({ "Buy", "Sell", "Starter", "Wild" }) do
	local profile = Schema.New(1000)
	profile.Pending = intent(kind)
	expect(Schema.Validate(profile), "Durable " .. kind .. " intent validates")
	local snapshot = Schema.Clone(profile)
	expect(snapshot.Pending ~= profile.Pending and snapshot.Pending.Kind == kind, "Intent independently serialized")
	expect(Schema.Migrate(snapshot).Pending.OperationId == "op-123:award", "Recovery keeps idempotence key")
end
local profile = Schema.New(1000)
profile.Pending = { Kind = "Sell", Id = "house-123", Price = 100, OperationId = "sell-op-123", CreatedAt = 1000 }
expect(not Schema.Validate(profile), "Sale without canonical revision cannot be recovered safely")
profile.Pending.ExpectedRevision = 4
expect(Schema.Validate(profile), "Canonical sale compare-and-swap revision persists")
for _, kind in ipairs({ "Starter", "Wild" }) do
	profile.Pending = intent(kind)
	profile.Pending.Price = nil
	expect(Schema.Validate(profile), "Free award permits omitted price")
end
for _, change in ipairs({
	function(p) p.Kind = "Transfer" end,
	function(p) p.Id = "" end,
	function(p) p.Id = string.rep("x", 101) end,
	function(p) p.OperationId = nil end,
	function(p) p.CreatedAt = -1 end,
	function(p) p.DefinitionId = "missing" end,
	function(p) p.Variant = "Admin" end,
	function(p) p.Size = "Unlimited" end,
	function(p) p.Slot = 0 end,
	function(p) p.Slot = 21 end,
	function(p) p.Slot = 1.5 end,
	function(p) p.Price = -1 end,
	function(p) p.Price = nil end,
	function(p) p.Revision = 1 end,
	function(p) p.DefinitionId = nil end,
	function(p) p.Variant = nil end,
	function(p) p.Size = nil end,
	function(p) p.ExpectedRevision = -1 end,
	function(p) p.ExpectedRevision = 1.5 end,
}) do
	bad(function(p) p.Pending = intent("Buy"); change(p.Pending) end, "invalid purchase intent")
end
bad(function(p) p.Pending = intent("Starter"); p.Pending.Price = 1 end, "starter cannot charge")
bad(function(p) p.Pending = intent("Wild"); p.Pending.Price = 1 end, "wild award cannot charge")
bad(function(p) p.Pending = intent("Sell"); p.Pending.Price = nil end, "sale credit required")
bad(function(p) p.Pending = function() end end, "intent must be serialized table")
bad(function(p) p.Pending = p end, "cyclic intent")

for _, house in ipairs(Config.Houses) do
	for _, variant in ipairs(Config.Variants) do
		for _, size in ipairs(Config.Sizes) do
			local p = Schema.New(1000)
			p.Pending = intent("Wild")
			p.Pending.DefinitionId, p.Pending.Variant, p.Pending.Size = house.Id, variant.Id, size.Id
			p.Collection[house.Id] = true
			expect(Schema.Validate(p), "Every generated collectible combination persists")
		end
	end
end
print("PASS: " .. checks .. " actual configuration/schema checks")
