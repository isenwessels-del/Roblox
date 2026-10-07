-- Progression stays on the server: upgrades debit configured prices, treadmill
-- training consumes server elapsed time, and protection expires on a fixed clock.
local Progression = {}
Progression.__index = Progression

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

function Progression.new(ctx)
	return setmetatable({ Context = ctx, Locks = {}, Training = {}, Sprinting = {}, Joined = {} }, Progression)
end

function Progression:_now()
	return (self.Context.Now or os.clock)()
end

function Progression:_notify(player, message, kind)
	if self.Context.Notify then self.Context.Notify(player, message, kind or "Info") end
end

function Progression:_publish(player)
	if self.Context.Publish then self.Context.Publish(player) end
end

function Progression:_profile(player)
	local ctx = self.Context
	if ctx.Closing or not ctx.Data:IsWritable(player) then return nil, "Saving is unavailable. Try again shortly." end
	local profile = ctx.Data:Get(player)
	if not profile then return nil, "Your progress is still loading." end
	if profile.Pending or ctx.Houses and ctx.Houses.Busy[player] then
		return nil, "Finish your current house transaction first."
	end
	if ctx.Steal and ctx.Steal.Carriers[player] then return nil, "Bring the house home first." end
	return profile
end

function Progression:_home(player)
	local ctx = self.Context
	local plot = ctx.World:GetPlot(player)
	if not plot or plot.Owner ~= player or not ctx.AntiExploit:Character(player)
		or not ctx.World:AtHome(player) then return nil end
	return plot
end

function Progression:Speed(player)
	return self.Context.Config.Speed(self.Context.Data:Get(player))
end

function Progression:Multiplier(_player)
	-- House size and mutation multipliers are applied once by HouseService.
	return 1
end

function Progression:MovementSpeed(player)
	local ctx = self.Context
	if ctx.Steal and ctx.Steal.Carriers[player] then return ctx.Config.Game.CarrySpeed end
	if self.Training[player] then return 0 end
	return self:Speed(player) + (if self.Sprinting[player] then 6 else 0)
end

function Progression:UpdateSpeed(player)
	local _, humanoid = self.Context.AntiExploit:Character(player)
	if humanoid then
		humanoid.WalkSpeed = self:MovementSpeed(player)
		humanoid:SetAttribute("HouseTraining", self.Training[player] == true)
	end
end

function Progression:SetSprint(player, enabled)
	if type(enabled) ~= "boolean" then return false, "Invalid sprint request." end
	if not self.Context.Data:Get(player) or not self.Context.AntiExploit:Character(player) then return false end
	self.Sprinting[player] = if enabled then true else nil
	self:UpdateSpeed(player)
	return true
end

function Progression:LockDuration(player)
	local config = self.Context.Config
	local profile = self.Context.Data:Get(player)
	local security = profile and config.Security[profile.SecurityLevel]
	return config.Game.LockSeconds + (security and security.BonusSeconds or 0)
end

function Progression:_renderLock(player, state)
	local plot = self.Context.World:GetPlot(player)
	if plot then
		local remaining = math.max(0, state.Until - self:_now())
		self.Context.World:SetLock(plot, remaining > 0, remaining)
	end
end

function Progression:IsLocked(player)
	local state = self.Locks[player]
	return state ~= nil and self:_now() < state.Until
end

function Progression:OnJoin(player)
	if self.Joined[player] then return end
	self.Joined[player] = true
	local now = self:_now()
	local duration = self.Context.Config.Game.JoinShieldSeconds
	local state = { Until = now + duration, CooldownUntil = now + duration + self.Context.Config.Game.LockCooldownSeconds }
	self.Locks[player] = state
	self:_renderLock(player, state)
	self:UpdateSpeed(player)
end

function Progression:Lock(player)
	local profile, errorMessage = self:_profile(player)
	if not profile then return false, errorMessage end
	local plot = self:_home(player)
	if not plot or not self.Context.AntiExploit:Near(player, plot.LockPosition,
		self.Context.Config.Game.InteractionRadius) then return false, "Stand on your own lock pad." end
	local now = self:_now()
	local existing = self.Locks[player]
	if existing and now < existing.Until then return false, "Your base is already locked." end
	if existing and now < existing.CooldownUntil then return false, "Your lock is cooling down." end
	local untilTime = now + self:LockDuration(player)
	local state = { Until = untilTime, CooldownUntil = untilTime + self.Context.Config.Game.LockCooldownSeconds }
	self.Locks[player] = state
	self:_renderLock(player, state)
	self:_notify(player, "Base locked!", "Success")
	self:_publish(player)
	return true
end

function Progression:_upgrade(player, field, definitions, name)
	local profile, errorMessage = self:_profile(player)
	if not profile then return false, errorMessage end
	if not self:_home(player) then return false, "Return to your own base to upgrade." end
	local level = profile[field]
	if not finite(level) or level ~= math.floor(level) or level < 1 or not definitions[level] then return false end
	local nextLevel = definitions[level + 1]
	if not nextLevel then return false, name .. " is fully upgraded." end
	local cost = nextLevel.Cost
	if not finite(cost) or cost < 0 or not finite(profile.Cash) or profile.Cash < cost then
		return false, "You need more cash for this upgrade."
	end
	-- No yield between validation, debit, and level/stat changes.
	profile.Cash -= cost
	profile[field] = level + 1
	profile.Statistics.TotalSpent = math.min(1e15, profile.Statistics.TotalSpent + cost)
	if field == "BaseLevel" then
		self.Context.World:UpdateSlots(player, nextLevel.Slots)
	elseif field == "TreadmillLevel" then
		self.Context.World:UpdateTreadmill(player, level + 1, self.Training[player] == true)
	end
	self:_notify(player, name .. " upgraded!", "Success")
	self:_publish(player)
	return true
end

function Progression:SecurityUpgrade(player)
	return self:_upgrade(player, "SecurityLevel", self.Context.Config.Security, "Security")
end

function Progression:BaseUpgrade(player)
	return self:_upgrade(player, "BaseLevel", self.Context.Config.Bases, "Base")
end

function Progression:TreadmillUpgrade(player)
	return self:_upgrade(player, "TreadmillLevel", self.Context.Config.Treadmills, "Treadmill")
end

function Progression:_stopTraining(player)
	if not self.Training[player] then return end
	self.Training[player] = nil
	self:UpdateSpeed(player)
	local profile = self.Context.Data:Get(player)
	if profile and self.Context.World:GetPlot(player) then
		self.Context.World:UpdateTreadmill(player, profile.TreadmillLevel, false)
	end
	self:_publish(player)
end

function Progression:_canTrain(player)
	local profile, errorMessage = self:_profile(player)
	if not profile then return nil, errorMessage end
	local plot = self:_home(player)
	if not plot or not self.Context.AntiExploit:Near(player, plot.TreadmillPosition,
		self.Context.Config.Game.InteractionRadius) then return nil, "Stand beside your own treadmill to train." end
	return profile
end

function Progression:Train(player, enabled)
	if type(enabled) ~= "boolean" then return false, "Invalid training request." end
	-- Stopping is always allowed, including a frozen data session or death.
	if not enabled then self:_stopTraining(player); return true end
	local profile, errorMessage = self:_canTrain(player)
	if not profile then return false, errorMessage end
	if self.Training[player] then return true end
	self.Training[player] = true
	self.Sprinting[player] = nil
	self:UpdateSpeed(player)
	self.Context.World:UpdateTreadmill(player, profile.TreadmillLevel, true)
	self:_publish(player)
	return true
end

function Progression:ClaimDaily(player)
	local profile, errorMessage = self:_profile(player)
	if not profile then return false, errorMessage end
	if not self:_home(player) then return false, "Return to your own base to claim your reward." end
	local now = (self.Context.Clock or os.time)()
	if not finite(now) or now < 0 then return false end
	local day = math.floor(now / 86400)
	if day <= profile.DailyDay then return false, "Today's reward has already been claimed." end
	local rewards = self.Context.Config.DailyRewards
	local streak = if day == profile.DailyDay + 1 then profile.DailyStreak % #rewards + 1 else 1
	local credited = math.min(rewards[streak], self.Context.Config.Game.MaxCash - profile.Cash)
	if credited <= 0 then return false, "Your wallet is full." end
	-- Claim marker and cash change together, without a yield or client timestamp.
	profile.DailyDay, profile.DailyStreak = day, streak
	profile.Cash += credited
	profile.Statistics.TotalEarned = math.min(1e15, profile.Statistics.TotalEarned + credited)
	self:_notify(player, "Daily reward claimed!", "Success")
	self:_publish(player)
	return true
end

function Progression:Rebirth(_player, _confirmed)
	return false, "This game progresses through base and treadmill upgrades."
end

function Progression:Tick(dt)
	if not finite(dt) or dt <= 0 then return end
	for player in pairs(self.Training) do
		local profile = self:_canTrain(player)
		local treadmill = profile and self.Context.Config.Treadmills[profile.TreadmillLevel]
		if not treadmill then
			self:_stopTraining(player)
		else
			local before = self:Speed(player)
			profile.SpeedXP = math.min(1e9, profile.SpeedXP + treadmill.Rate * dt)
			self:UpdateSpeed(player)
			if self:Speed(player) ~= before then self:_publish(player) end
		end
	end
	for player, state in pairs(self.Locks) do self:_renderLock(player, state) end
end

function Progression:Release(player)
	self:_stopTraining(player)
	local plot = self.Context.World:GetPlot(player)
	if plot then self.Context.World:SetLock(plot, false, 0) end
	self.Locks[player], self.Sprinting[player], self.Joined[player] = nil, nil, nil
end

return Progression
