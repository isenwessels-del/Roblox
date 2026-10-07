-- Execute the real progression service with explicit clock/world/character
-- boundaries. Engine rendering and real movement remain Studio checks.
local Progression = require("../src/server/ProgressionService")
local Config = require("../src/shared/Config")
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end

local function fixture()
	local player = { UserId = 7 }
	local other = { UserId = 8 }
	local profile = {
		Cash = 1e9, Bank = 0, Rebirths = 0, BaseLevel = 1, TreadmillLevel = 1,
		SpeedXP = 0, SecurityLevel = 1, DailyDay = -1, DailyStreak = 0,
		Statistics = { TotalSpent = 0, TotalEarned = 0 },
	}
	local attrs = {}
	local humanoid = { WalkSpeed = 20 }
	function humanoid:SetAttribute(key, value) attrs[key] = value end
	local plot = { Owner = player, LockPosition = "lock", TreadmillPosition = "treadmill" }
	local f = { Player = player, Other = other, Profile = profile, Humanoid = humanoid,
		Attributes = attrs, Plot = plot, Now = 0, Clock = 86400 * 100, Home = true,
		Alive = true, Writable = true, Loaded = true, NearLock = true, NearTreadmill = true,
		LockCalls = {}, TreadmillCalls = {}, SlotCalls = {}, Publications = 0, Notices = {} }
	local ctx = { Config = Config, Data = {}, AntiExploit = {}, World = {},
		Houses = { Busy = {} }, Steal = { Carriers = {} } }
	ctx.Now = function() return f.Now end
	ctx.Clock = function() return f.Clock end
	function ctx.Data:Get(p) return if p == player and f.Loaded then profile else nil end
	function ctx.Data:IsWritable(p) return p == player and f.Loaded and f.Writable end
	function ctx.AntiExploit:Character(p)
		if p == player and f.Alive then return {}, humanoid end
		return nil
	end
	function ctx.AntiExploit:Near(p, position, radius)
		check(p == player and radius == Config.Game.InteractionRadius, "configured server interaction radius")
		if position == "lock" then return f.NearLock end
		if position == "treadmill" then return f.NearTreadmill end
		error("unexpected position")
	end
	function ctx.World:GetPlot(p) return if p == player then f.Plot else nil end
	function ctx.World:AtHome(p) return p == player and f.Home end
	function ctx.World:SetLock(p, locked, remaining)
		check(p == plot and remaining >= 0, "lock renderer receives only own plot and finite remaining")
		table.insert(f.LockCalls, { Locked = locked, Remaining = remaining })
	end
	function ctx.World:UpdateSlots(p, slots)
		check(p == player, "base slots update only upgrading player")
		table.insert(f.SlotCalls, slots)
	end
	function ctx.World:UpdateTreadmill(p, level, training)
		check(p == player and type(training) == "boolean", "treadmill state is server boolean for owner")
		table.insert(f.TreadmillCalls, { Level = level, Training = training })
	end
	ctx.Publish = function(p) check(p == player, "only affected player snapshot published"); f.Publications += 1 end
	ctx.Notify = function(p, text, kind)
		check(p == player and type(text) == "string" and type(kind) == "string", "server notifications bounded to owner")
		table.insert(f.Notices, text)
	end
	f.Context = ctx
	f.Service = Progression.new(ctx)
	return f
end

do
	local f = fixture()
	local s, p = f.Service, f.Player
	s:OnJoin(p)
	check(s:IsLocked(p), "join grants shield")
	check(s.Locks[p].Until == 30 and s.Locks[p].CooldownUntil == 50, "join shield finite with cooldown after expiration")
	check(f.LockCalls[#f.LockCalls].Remaining == 30, "join shield rendered")
	f.Now = 20
	s:OnJoin(p)
	check(s.Locks[p].Until == 30, "repeated join hook cannot renew shield")
	check(not s:Lock(p) and s.Locks[p].Until == 30, "active lock cannot be extended")
	f.Now = 30
	check(not s:IsLocked(p), "shield expires at exact boundary")
	s:Tick(1)
	check(not f.LockCalls[#f.LockCalls].Locked, "expiration opens actual world gate")
	check(not s:Lock(p), "cooldown begins after shield expiration")
	f.Now = 49.99
	check(not s:Lock(p), "lock remains unavailable until cooldown boundary")
	f.Now = 50
	check(s:Lock(p), "lock available at cooldown boundary")
	check(s.Locks[p].Until == 110 and s.Locks[p].CooldownUntil == 130, "manual lock has finite duration and subsequent cooldown")
	f.Now = 70
	check(s:SecurityUpgrade(p), "server security upgrade purchased")
	check(s:LockDuration(p) == 70 and s.Locks[p].Until == 110, "security extends next lock without refreshing current protection")
	f.Now = 110
	check(not s:IsLocked(p) and not s:Lock(p), "manual lock expires without extending itself")
	f.Now = 130
	check(s:Lock(p) and s.Locks[p].Until == 200, "upgraded security affects real subsequent lock")
	check(not s:Lock(p) and s.Locks[p].Until == 200, "repeated paid-tier lock requests still cannot extend")
	s:Release(p)
	check(s.Locks[p] == nil and s.Joined[p] == nil and not f.LockCalls[#f.LockCalls].Locked, "release removes state and opens gate")
end

do
	for _, block in ipairs({ "NearLock", "Home", "Alive", "Writable", "Loaded" }) do
		local f = fixture()
		f[block] = false
		check(not f.Service:Lock(f.Player) and f.Service.Locks[f.Player] == nil, "lock rejects unavailable " .. block)
	end
	local f = fixture()
	f.Plot.Owner = f.Other
	check(not f.Service:Lock(f.Player), "another player's plot cannot be locked")
	f.Plot.Owner = f.Player
	f.Profile.Pending = { Kind = "Buy" }
	check(not f.Service:Lock(f.Player), "lock is blocked during durable house intent")
end

do
	local f = fixture()
	local s, p, profile = f.Service, f.Player, f.Profile
	local expectedCash, expectedSpent = profile.Cash, 0
	for _, spec in ipairs({
		{ Method = "BaseUpgrade", Field = "BaseLevel", Definitions = Config.Bases },
		{ Method = "TreadmillUpgrade", Field = "TreadmillLevel", Definitions = Config.Treadmills },
		{ Method = "SecurityUpgrade", Field = "SecurityLevel", Definitions = Config.Security },
	}) do
		for level = 2, #spec.Definitions do
			local cost = spec.Definitions[level].Cost
			expectedCash -= cost
			expectedSpent += cost
			check(s[spec.Method](s, p), "valid " .. spec.Method .. " purchase at level " .. level)
			check(profile[spec.Field] == level and profile.Cash == expectedCash,
				"server configured price atomically debits and increments only selected level")
			check(profile.Statistics.TotalSpent == expectedSpent, "spend statistic matches actual configured debits")
		end
		check(not s[spec.Method](s, p) and profile.Cash == expectedCash, "max tier rejects without spending")
	end
	check(f.SlotCalls[#f.SlotCalls] == 20, "base progression enables twenty actual pads")
	check(f.TreadmillCalls[#f.TreadmillCalls].Level == #Config.Treadmills, "world treadmill displays earned level")
	check(s:Multiplier(p) == 1, "variant and size income are not multiplied twice")
	check(not s:Rebirth(p, true) and profile.Rebirths == 0, "unsupported rebirth cannot spend or grant unverified bonuses")
end

do
	for _, method in ipairs({ "BaseUpgrade", "TreadmillUpgrade", "SecurityUpgrade", "ClaimDaily" }) do
		for _, block in ipairs({ "Home", "Alive", "Writable", "Loaded" }) do
			local f = fixture()
			f[block] = false
			local oldCash = f.Profile.Cash
			check(not f.Service[method](f.Service, f.Player) and f.Profile.Cash == oldCash,
				method .. " requires available own base/profile: " .. block)
		end
		for _, block in ipairs({ "Pending", "Busy", "Carrying", "Closing", "ForeignPlot" }) do
			local f = fixture()
			if block == "Pending" then f.Profile.Pending = { Kind = "Buy" }
			elseif block == "Busy" then f.Context.Houses.Busy[f.Player] = true
			elseif block == "Carrying" then f.Context.Steal.Carriers[f.Player] = {}
			elseif block == "Closing" then f.Context.Closing = true
			else f.Plot.Owner = f.Other end
			local oldCash = f.Profile.Cash
			check(not f.Service[method](f.Service, f.Player) and f.Profile.Cash == oldCash,
				method .. " rejects " .. block .. " without economy mutation")
		end
	end
	for _, method in ipairs({ "BaseUpgrade", "TreadmillUpgrade", "SecurityUpgrade" }) do
		local f = fixture()
		f.Profile.Cash = 0
		check(not f.Service[method](f.Service, f.Player) and f.Profile.Statistics.TotalSpent == 0,
			"insufficient cash blocks " .. method)
	end
	local f = fixture()
	f.Profile.BaseLevel = 1.5
	check(not f.Service:BaseUpgrade(f.Player), "malformed profile upgrade level fails closed")
	f.Profile.BaseLevel = 1
	f.Profile.Cash = 0 / 0
	check(not f.Service:BaseUpgrade(f.Player), "nonfinite wallet cannot buy upgrades")
end

do
	local f = fixture()
	local s, p = f.Service, f.Player
	check(s:Speed(p) == 20 and s:MovementSpeed(p) == 20, "fresh player has normal server walk speed")
	check(not s:SetSprint(p, "true"), "sprint strictly validates boolean")
	check(s:SetSprint(p, true) and f.Humanoid.WalkSpeed == 26, "server sprint adds six speed")
	check(not s:Train(p, 500000), "client XP amount cannot enable training")
	check(s:Train(p, true) and s.Training[p] and f.Humanoid.WalkSpeed == 0, "treadmill toggles fixed server training state")
	check(f.Attributes.HouseTraining == true and s.Sprinting[p] == nil, "training sets character indicator and clears sprint")
	check(s:Train(p, true) and f.Profile.SpeedXP == 0, "repeated start grants no instant XP")
	s:Tick(0.25)
	check(f.Profile.SpeedXP == 0.125, "training uses current tier rate and actual fractional server dt")
	f.Profile.SpeedXP = 19.9
	s:Tick(0.25)
	check(s:Speed(p) == 22 and f.Humanoid.WalkSpeed == 0, "earned threshold updates speed without unfreezing training")
	check(s:Train(p, false) and f.Humanoid.WalkSpeed == 22 and f.Attributes.HouseTraining == false,
		"stopping restores actual earned speed without anchoring character")
	check(s:SetSprint(p, true) and f.Humanoid.WalkSpeed == 28, "sprint scales with training progress")
	f.Context.Steal.Carriers[p] = {}
	s:UpdateSpeed(p)
	check(f.Humanoid.WalkSpeed == 12 and s:Speed(p) == 22, "carrying speed takes priority without changing earned progression")
	check(not s:Train(p, true), "carrying cannot start treadmill training")
	f.Context.Steal.Carriers[p] = nil
	check(s:Train(p, true), "training resumes when hands empty")
	f.Profile.TreadmillLevel = 3
	local xp = f.Profile.SpeedXP
	s:Tick(2)
	check(f.Profile.SpeedXP == xp + 4, "higher treadmill rate applies from server profile only")
	f.Profile.SpeedXP = 1e9 - 1
	s:Tick(10)
	check(f.Profile.SpeedXP == 1e9 and s:Speed(p) == 80, "XP and earned movement speed are capped")
	s:Train(p, false)
	s:SetSprint(p, true)
	check(f.Humanoid.WalkSpeed == 86, "maximum earned sprint speed is eighty-six")
	s:Release(p)
	check(s.Training[p] == nil and s.Sprinting[p] == nil, "release clears all training and sprint references")
end

do
	for _, block in ipairs({ "NearTreadmill", "Home", "Alive", "Writable", "Loaded",
		"Pending", "Busy", "Carrying", "Closing", "ForeignPlot" }) do
		local f = fixture()
		check(f.Service:Train(f.Player, true), "setup begins valid training")
		local xp = f.Profile.SpeedXP
		if block == "Pending" then f.Profile.Pending = { Kind = "Buy" }
		elseif block == "Busy" then f.Context.Houses.Busy[f.Player] = true
		elseif block == "Carrying" then f.Context.Steal.Carriers[f.Player] = {}
		elseif block == "Closing" then f.Context.Closing = true
		elseif block == "ForeignPlot" then f.Plot.Owner = f.Other
		else f[block] = false end
		f.Service:Tick(5)
		check(f.Profile.SpeedXP == xp and f.Service.Training[f.Player] == nil,
			"each server tick stops training without awarding XP when " .. block)
		check(not f.Service:Train(f.Player, true), "training cannot restart under " .. block)
		check(f.Service:Train(f.Player, false), "stop request remains safe under " .. block)
	end
	local f = fixture()
	check(f.Service:Train(f.Player, true), "setup dt validation")
	for _, dt in ipairs({ -1, 0, 0 / 0, math.huge, -math.huge }) do
		f.Service:Tick(dt)
		check(f.Profile.SpeedXP == 0, "invalid elapsed time cannot award XP")
	end
end

do
	local f = fixture()
	local s, p, profile = f.Service, f.Player, f.Profile
	local cash, earnings = profile.Cash, 0
	for day = 100, 108 do
		f.Clock = day * 86400 + 86399
		local reward = Config.DailyRewards[(day - 100) % 7 + 1]
		cash += reward
		earnings += reward
		check(s:ClaimDaily(p), "new server UTC day allows daily reward")
		check(profile.Cash == cash and profile.Statistics.TotalEarned == earnings,
			"cash and earned stats receive exactly server configured reward")
		check(profile.DailyDay == day and profile.DailyStreak == (day - 100) % 7 + 1,
			"consecutive streak cycles after seventh reward")
		check(not s:ClaimDaily(p) and profile.Cash == cash, "same UTC day duplicate fails without awarding cash")
	end
	f.Clock = 110 * 86400
	check(s:ClaimDaily(p) and profile.DailyStreak == 1, "missed UTC day resets streak")
	f.Clock = 109 * 86400
	check(not s:ClaimDaily(p), "earlier server date cannot replay claimed rewards")
	profile.Cash = Config.Game.MaxCash - 10
	f.Clock = 111 * 86400
	local previousEarned = profile.Statistics.TotalEarned
	check(s:ClaimDaily(p) and profile.Cash == Config.Game.MaxCash,
		"daily reward safely caps wallet")
	check(profile.Statistics.TotalEarned == previousEarned + 10, "income statistics count actual credited cash")
	f.Clock = 112 * 86400
	check(not s:ClaimDaily(p) and profile.DailyDay == 111, "full wallet does not consume daily claim")
	profile.Cash = 0
	check(s:ClaimDaily(p) and profile.DailyDay == 112, "daily claim still available after freeing wallet capacity")
end

print("PASS: " .. checks .. " progression checks (server clocks, fixed locks, upgrades, training, daily rewards).")
