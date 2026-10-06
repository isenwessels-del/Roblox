-- Progression is driven by validated server actions. Claims never yield between checks and grants.
local QuestService = {}
QuestService.__index = QuestService

local TUTORIAL = {
    { Action = "VisitHouses", Text = "Enter the first house on Starter Street." },
    { Action = "StealItems", Text = "Hold E or tap a furniture prompt to steal your first item." },
    { Action = "CompleteRobbery", Text = "RUN! Bring your backpack home to secure the loot." },
    { Action = "PlaceItem", Text = "Open your inventory and display an item in your house." },
    { Action = "Upgrade", Text = "Sell spare loot, then upgrade your house or backpack from its menu." },
}

local function positiveInteger(value)
    return type(value) == "number" and value == value and value < math.huge and value >= 0 and value % 1 == 0
end

local function clockDay(now)
    return math.floor(now / 86400)
end

local function finish(self, player)
    if self.ctx.Publish then self.ctx.Publish(player) end
end

function QuestService.new(ctx)
    return setmetatable({ ctx = ctx, clock = ctx.Clock or os.time, timers = {}, eventSeen = {} }, QuestService)
end

function QuestService:_profile(player)
    local profile = self.ctx.Data:Get(player)
    if not profile or not self.ctx.Data:IsWritable(player) then return nil end
    profile.Quests = profile.Quests or {}
    local quests = profile.Quests
    quests.Daily = quests.Daily or {}
    quests.Weekly = quests.Weekly or {}
    quests.Progress = quests.Progress or {}
    quests.Claimed = quests.Claimed or {}
    profile.Achievements = profile.Achievements or {}
    profile.DailyReward = profile.DailyReward or { CurrentDay = 1, LastClaim = 0 }
    return profile
end

function QuestService:_reset(player, profile)
    local today = clockDay(self.clock())
    local week = math.floor((today + 3) / 7) -- UTC weeks start on Monday.
    local quests = profile.Quests
    if quests.Day ~= today then
        quests.Day = today
        quests.Daily = {}
        for key in pairs(quests.Progress) do
            if string.sub(key, 1, 6) == "Daily:" then quests.Progress[key] = nil end
        end
        for key in pairs(quests.Claimed) do
            if string.sub(key, 1, 6) == "Daily:" then quests.Claimed[key] = nil end
        end
        for index, difficulty in ipairs({ "Easy", "Medium", "Hard" }) do
            local eligible = {}
            for id, entry in pairs(self.ctx.Config.Quests) do
                if entry.Difficulty == difficulty then table.insert(eligible, id) end
            end
            table.sort(eligible)
            if #eligible > 0 then
                -- Stable across reconnects, with a different selection for each UTC day/player.
                local seed = today * 1103515245 + player.UserId * 97 + index * 31
                table.insert(quests.Daily, eligible[(seed % #eligible) + 1])
            end
        end
    end
    if quests.Week ~= week then
        quests.Week = week
        quests.Weekly = {}
        for key in pairs(quests.Progress) do
            if string.sub(key, 1, 7) == "Weekly:" then quests.Progress[key] = nil end
        end
        for key in pairs(quests.Claimed) do
            if string.sub(key, 1, 7) == "Weekly:" then quests.Claimed[key] = nil end
        end
        for id, entry in pairs(self.ctx.Config.Quests) do
            if entry.Difficulty == "Weekly" then table.insert(quests.Weekly, id) end
        end
        table.sort(quests.Weekly)
    end
end

function QuestService:InitPlayer(player)
    local profile = self:_profile(player)
    if not profile then return end
    self:_reset(player, profile)
    if profile.FirstJoin == false then
        profile.TutorialStep = #TUTORIAL + 1
    else
        profile.TutorialStep = math.clamp(profile.TutorialStep or 1, 1, #TUTORIAL + 1)
    end
    self:_achievements(player, profile)
end

function QuestService:XPRequired(level)
    local base = self.ctx.Config.Economy.XPPerLevel or 100
    return math.max(1, math.floor(base * (1 + (math.max(1, level) - 1) * 0.25)))
end

function QuestService:_awardXP(profile, amount)
    local multiplier = self.ctx.Events and self.ctx.Events:Multiplier("XP") or 1
    profile.XP = (profile.XP or 0) + math.floor(amount * multiplier)
    profile.Level = profile.Level or 1
    local maximum = self.ctx.Config.Economy.MaxLevel or 1000
    while profile.Level < maximum and profile.XP >= self:XPRequired(profile.Level) do
        profile.XP -= self:XPRequired(profile.Level)
        profile.Level += 1
    end
    if profile.Level >= maximum then profile.XP = math.min(profile.XP, self:XPRequired(maximum)) end
end

function QuestService:AwardXP(player, amount)
    if not positiveInteger(amount) or amount > 10000000 then return false end
    local profile = self:_profile(player)
    if not profile then return false end
    self:_awardXP(profile, amount)
    return true
end

function QuestService:_analytics(player, event, fields)
    if self.ctx.Analytics then self.ctx.Analytics:Emit(player, event, fields) end
end

function QuestService:_reward(player, profile, reward, reason)
    local cash, xp = reward.Cash or 0, reward.XP or 0
    if not positiveInteger(cash) or not positiveInteger(xp) or xp > 10000000 then return false end
    local maximum = self.ctx.Config.Economy.MaxCash or 1000000000000
    if cash > maximum or profile.Cash > maximum - cash then return false end
    profile.Cash += cash
    profile.Statistics.TotalCashEarned = math.min(1000000000000000, (profile.Statistics.TotalCashEarned or 0) + cash)
    self:_awardXP(profile, xp)
    self:_analytics(player, "CashSource", { Amount = cash, Reason = reason })
    return true
end

function QuestService:_achievements(player, profile)
    for _, definition in ipairs(self.ctx.Config.Economy.Achievements or {}) do
        local state = profile.Achievements[definition.Id]
        if type(state) ~= "table" then
            state = { Claimed = state == true, Unlocked = state == true }
            profile.Achievements[definition.Id] = state
        end
        state.Progress = math.min(definition.Target, profile.Statistics[definition.Statistic] or 0)
        if state.Progress >= definition.Target and not state.Unlocked then
            state.Unlocked = true
            if self.ctx.Notify then self.ctx.Notify(player, "Achievement unlocked: " .. definition.Name, "Success") end
            self:_analytics(player, "AchievementUnlocked", { Achievement = definition.Id })
        end
    end
end

function QuestService:UpdateTutorial(player, action)
    local profile = self:_profile(player)
    if not profile or profile.FirstJoin == false then return false end
    local index = profile.TutorialStep or 1
    local step = TUTORIAL[index]
    if not step or (step.Action ~= action and not (step.Action == "Upgrade" and action == "UpgradeHouse")) then return false end
    profile.TutorialStep = index + 1
    if index == #TUTORIAL then
        profile.FirstJoin = false
        self:_analytics(player, "TutorialCompleted", {})
        if self.ctx.Notify then self.ctx.Notify(player, "Tutorial complete. Steal, escape, build, protect!", "Success") end
    end
    return true
end

function QuestService:Progress(player, typeName, amount, detail)
    amount = amount or 1
    if type(typeName) ~= "string" or not positiveInteger(amount) or amount <= 0 then return end
    local profile = self:_profile(player)
    if not profile then return end
    self:_reset(player, profile)
    local quests = profile.Quests
    local active = self.ctx.Events and self.ctx.Events:GetActive()
    if active and (typeName == "StealItems" or typeName == "CompleteRobbery") then
        local eventKey = active.Id .. ":" .. active.StartedAt
        if self.eventSeen[player] ~= eventKey then
            self.eventSeen[player] = eventKey
            profile.Statistics.EventsParticipated = math.min(1000000000000000, (profile.Statistics.EventsParticipated or 0) + 1)
            self:Progress(player, "ParticipateInEvent", 1, active.Id)
            self:_analytics(player, "EventParticipated", { Event = active.Id })
        end
    end
    for _, period in ipairs({ "Daily", "Weekly" }) do
        for _, id in ipairs(quests[period]) do
            local definition = self.ctx.Config.Quests[id]
            local key = period .. ":" .. id
            local rarity = type(detail) == "table" and detail.Rarity or detail
            if definition and definition.Type == typeName and (not definition.Rarity or definition.Rarity == rarity) then
                quests.Progress[key] = math.min(definition.Target, (quests.Progress[key] or 0) + amount)
            end
        end
    end
    self:_achievements(player, profile)
    self:UpdateTutorial(player, typeName)
end

function QuestService:Claim(player, id)
    if type(id) ~= "string" or #id > 100 then return false, "Invalid quest." end
    local profile = self:_profile(player)
    if not profile then return false, "Your profile is not ready." end
    self:_reset(player, profile)
    local quests = profile.Quests
    if string.sub(id, 1, 12) == "Achievement:" then
        local wanted = string.sub(id, 13)
        self:_achievements(player, profile)
        for _, definition in ipairs(self.ctx.Config.Economy.Achievements or {}) do
            if definition.Id == wanted then
                local state = profile.Achievements[wanted]
                if not state or not state.Unlocked then return false, "Achievement is not complete." end
                if state.Claimed then return false, "You already claimed this achievement." end
                if not self:_reward(player, profile, { Cash = definition.Cash or 0, XP = definition.XP or 0 }, "Achievement") then
                    return false, "Reward cannot be granted right now."
                end
                state.Claimed = true
                self:_achievements(player, profile)
                finish(self, player)
                return true, "Achievement reward claimed!"
            end
        end
        return false, "Unknown achievement."
    end
    for _, period in ipairs({ "Daily", "Weekly" }) do
        for _, assigned in ipairs(quests[period]) do
            if id == assigned then
                local definition = self.ctx.Config.Quests[id]
                local key = period .. ":" .. id
                if quests.Claimed[key] then return false, "You already claimed this quest." end
                if not definition or (quests.Progress[key] or 0) < definition.Target then
                    return false, "Quest is not complete."
                end
                if not self:_reward(player, profile, definition.Reward, period .. "Quest") then
                    return false, "Reward cannot be granted right now."
                end
                quests.Claimed[key] = true
                profile.Statistics.QuestsClaimed = math.min(1000000000000000, (profile.Statistics.QuestsClaimed or 0) + 1)
                self:_analytics(player, "QuestClaimed", { Quest = id, Period = period })
                self:_achievements(player, profile)
                finish(self, player)
                return true, "Quest reward claimed!"
            end
        end
    end
    return false, "That quest is not assigned to you."
end

function QuestService:_daily(profile)
    local state = profile.DailyReward
    local now = self.clock()
    local elapsed = now - (state.LastClaim or 0)
    local interval = self.ctx.Config.Economy.DailyClaimSeconds or 86400
    local rewards = self.ctx.Config.Economy.DailyRewards or {}
    local day = math.clamp(state.CurrentDay or 1, 1, math.max(1, #rewards))
    if state.LastClaim ~= 0 and elapsed >= (self.ctx.Config.Economy.DailyResetSeconds or 172800) then day = 1 end
    return day, state.LastClaim == 0 or elapsed >= interval, math.max(0, interval - elapsed), rewards[day]
end

function QuestService:ClaimDaily(player)
    local profile = self:_profile(player)
    if not profile then return false, "Your profile is not ready." end
    local day, available, _, reward = self:_daily(profile)
    if not available then return false, "Your next daily reward is not ready yet." end
    if not reward then return false, "Daily rewards are unavailable." end
    local cash, xp = reward.Cash or 0, reward.XP or 0
    local maximum = self.ctx.Config.Economy.MaxCash or 1000000000000
    if not positiveInteger(cash) or not positiveInteger(xp) or xp > 10000000 or profile.Cash > maximum - cash then
        return false, "Reward cannot be granted right now."
    end
    -- Item gifts use the same storage checks as ordinary inventory operations.
    if reward.ItemId then
        if not self.ctx.Inventory or not self.ctx.Inventory:CanStore(player, reward.ItemId) then
            return false, "Free storage space before claiming this item reward."
        end
        local entry = self.ctx.Inventory:AddStoredItem(player, reward.ItemId, "DailyReward")
        if not entry then return false, "The daily item cannot be granted right now." end
    end
    if reward.Theme then
        profile.OwnedThemes = profile.OwnedThemes or { Default = true }
        profile.OwnedThemes[reward.Theme] = true
    end
    -- No client timestamp or requested day is used; all grants and the claim marker are synchronous.
    profile.DailyReward.LastClaim = self.clock()
    profile.DailyReward.CurrentDay = day % #self.ctx.Config.Economy.DailyRewards + 1
    profile.Statistics.DailyRewardsClaimed = math.min(1000000000000000, (profile.Statistics.DailyRewardsClaimed or 0) + 1)
    self:_reward(player, profile, reward, "DailyReward")
    self:_achievements(player, profile)
    self:_analytics(player, "DailyRewardClaimed", { Day = day })
    finish(self, player)
    return true, "Day " .. day .. " reward claimed!"
end

function QuestService:Get(player)
    local profile = self.ctx.Data:Get(player)
    if not profile or not profile.Quests then return { Daily = {}, Weekly = {}, Achievements = {} } end
    local output = { Daily = {}, Weekly = {}, Achievements = {} }
    for _, period in ipairs({ "Daily", "Weekly" }) do
        for _, id in ipairs(profile.Quests[period] or {}) do
            local definition = self.ctx.Config.Quests[id]
            if definition then
                local key = period .. ":" .. id
                local progress = profile.Quests.Progress[key] or 0
                table.insert(output[period], {
                    Id = id, Name = definition.Name, Type = definition.Type,
                    Rarity = definition.Rarity, Difficulty = definition.Difficulty,
                    Target = definition.Target, Progress = progress,
                    Complete = progress >= definition.Target, Claimed = profile.Quests.Claimed[key] == true,
                    CanClaim = progress >= definition.Target and profile.Quests.Claimed[key] ~= true,
                    Reward = { Cash = definition.Reward.Cash or 0, XP = definition.Reward.XP or 0 },
                })
            end
        end
    end
    for _, definition in ipairs(self.ctx.Config.Economy.Achievements or {}) do
        local state = profile.Achievements[definition.Id] or {}
        table.insert(output.Achievements, {
            Id = "Achievement:" .. definition.Id, Name = definition.Name,
            Progress = type(state) == "table" and (state.Progress or 0) or 0,
            Target = definition.Target, Complete = type(state) == "table" and state.Unlocked == true,
            Claimed = type(state) == "table" and state.Claimed == true,
            CanClaim = type(state) == "table" and state.Unlocked == true and state.Claimed ~= true,
            Reward = { Cash = definition.Cash or 0, XP = definition.XP or 0 },
        })
    end
    local day, available, remaining, reward = self:_daily(profile)
    output.DailyReward = {
        Day = day, CanClaim = available, SecondsRemaining = remaining,
        Cash = reward and reward.Cash or 0, XP = reward and reward.XP or 0,
        ItemId = reward and reward.ItemId, Theme = reward and reward.Theme,
    }
    local index = profile.TutorialStep or 1
    output.Tutorial = {
        Step = index, Total = #TUTORIAL, Complete = profile.FirstJoin == false or index > #TUTORIAL,
        Text = TUTORIAL[index] and TUTORIAL[index].Text or "Steal. Escape. Build. Protect.",
        Action = TUTORIAL[index] and TUTORIAL[index].Action,
    }
    output.Level = profile.Level
    output.XP = profile.XP
    output.XPRequired = self:XPRequired(profile.Level or 1)
    output.DailyResetAt = (clockDay(self.clock()) + 1) * 86400
    return output
end

function QuestService:Tick(player, dt)
    self.timers[player] = (self.timers[player] or 0) + dt
    if self.timers[player] < 10 then return end
    self.timers[player] = 0
    local profile = self:_profile(player)
    if profile then
        self:_reset(player, profile)
        self:_achievements(player, profile)
    end
end

function QuestService:Remove(player)
    self.timers[player] = nil
    self.eventSeen[player] = nil
end

return QuestService
