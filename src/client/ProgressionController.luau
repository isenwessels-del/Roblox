--!nonstrict
local W = require(script.Parent.Widgets)
local Progression = {}
Progression.__index = Progression

function Progression.new(ctx)
    local self = setmetatable({ Context = ctx }, Progression)
    ctx.UI:Register("Quests", function(parent, state) self:Quests(parent, state) end)
    ctx.UI:Register("Settings", function(parent, state) self:Settings(parent, state) end)
    ctx.UI:Register("Leaderboard", function(parent, state) self:Leaderboard(parent, state) end)
    return self
end

function Progression:QuestRows(parent, rows, heading)
    W.Text(parent, heading, 31, W.Colors.Teal, 19)
    for _, quest in ipairs(rows or {}) do
        local card = W.Card(parent, if quest.Claimed then 86 else 122)
        local progress, target = tonumber(quest.Progress) or 0, tonumber(quest.Target) or 1
        W.Text(card, quest.Name .. "  •  " .. (if quest.Claimed then "CLAIMED" else tostring(math.min(progress, target)) .. "/" .. target), 28,
            if quest.Complete then W.Colors.Teal else W.Colors.Text, 17)
        local reward = quest.Reward or {}
        W.Text(card, "$" .. W.Number(reward.Cash) .. "  +  " .. W.Number(reward.XP) .. " XP", 22, W.Colors.Orange, 13)
        if not quest.Claimed then
            local button = W.Button(card, if quest.Complete then "Claim reward" else "In progress", function()
                if quest.Complete then self.Context:Request("Quests", "RequestQuestClaim", quest.Id) end
            end)
            if not quest.Complete then button.TextColor3, button.Selectable = W.Colors.Muted, false end
        end
    end
end

function Progression:Quests(parent, state)
    if not state or not state.Profile then return end
    local q = state.Quests
    if not q then W.Text(parent, "Quest state is loading...", 50); return end
    W.Text(parent, "LEVEL " .. tostring(q.Level or state.Profile.Level) .. "  •  " .. tostring(q.XP or state.Profile.XP) .. " / " .. tostring(q.XPRequired or "--") .. " XP", 31, W.Colors.Orange, 18)
    local daily = q.DailyReward
    if daily then
        local card = W.Card(parent, 133)
        W.Text(card, "DAILY REWARD  •  DAY " .. daily.Day, 28, W.Colors.Teal, 18)
        local bonus = if daily.ItemId and self.Context.Config.Items[daily.ItemId] then " + " .. self.Context.Config.Items[daily.ItemId].Name elseif daily.Theme then " + " .. daily.Theme .. " theme" else ""
        W.Text(card, "$" .. W.Number(daily.Cash) .. " + " .. W.Number(daily.XP) .. " XP" .. bonus, 34, W.Colors.Text, 14)
        local minutes = math.ceil((daily.SecondsRemaining or 0) / 60)
        W.Button(card, if daily.CanClaim then "Claim today's reward" else "Next reward in " .. minutes .. " min", function()
            if daily.CanClaim then self.Context:Request("Quests", "RequestDailyClaim") end
        end)
    end
    if q.Tutorial and not q.Tutorial.Complete then W.Text(parent, "FIRST HEIST  " .. q.Tutorial.Step .. "/" .. (q.Tutorial.Total or 5) .. "  •  " .. q.Tutorial.Text, 55, W.Colors.Teal, 14) end
    self:QuestRows(parent, q.Daily, "DAILY MISSIONS")
    self:QuestRows(parent, q.Weekly, "WEEKLY MISSIONS")
    self:QuestRows(parent, q.Achievements, "ACHIEVEMENTS")
end

function Progression:Settings(parent, state)
    if not state or not state.Profile then return end
    W.Text(parent, "MAKE IT YOURS", 34, W.Colors.Teal, 21)
    local settings = state.Profile.Settings or {}
    for _, setting in ipairs({ { "Music", "Music" }, { "SFX", "Sound effects" }, { "Notifications", "Notifications" },
        { "CameraShake", "Camera shake" }, { "ReducedEffects", "Reduced visual effects" } }) do
        W.Button(parent, setting[2] .. "  •  " .. (if settings[setting[1]] then "ON" else "OFF"), function()
            self.Context:Request("Settings", "RequestSetting", setting[1], not settings[setting[1]])
        end)
    end
    W.Text(parent, "CONTROLS", 33, W.Colors.Orange, 19)
    W.Text(parent, "Keyboard: hold E to interact • Shift to sprint • Tab for inventory.\nPlacement: mouse + R + Enter, or arrow keys. Esc cancels.\nTouch: hold interaction prompts; use the placement arrows.\nGamepad: X to interact • L3 sprint • Start inventory. Placement: left stick / D-pad, RB rotate, A place, B cancel.", 145, W.Colors.Muted, 14)
    W.Text(parent, "Sound only plays when the developer has configured licensed audio assets. Server controls cash, items and progression.", 62, W.Colors.Muted, 13)
end

function Progression:Leaderboard(parent, state)
    if not state then return end
    local leaderboard = state.Leaderboard or {}
    local live = leaderboard.Live or leaderboard
    W.Text(parent, "RICHEST HOMES • THIS SERVER", 34, W.Colors.Teal, 20)
    for rank, entry in ipairs(live) do
        local card = W.Card(parent, 75)
        W.Text(card, "#" .. rank .. "  " .. tostring(entry.Name or entry.DisplayName or "Player"), 28, if rank == 1 then W.Colors.Orange else W.Colors.Text, 18)
        W.Text(card, "Home $" .. W.Number(entry.HouseValue) .. "  •  Cash $" .. W.Number(entry.Cash)
            .. "  •  " .. W.Number(entry.ItemsStolen) .. " steals", 25, W.Colors.Muted, 13)
    end
    if leaderboard.PersistenceEnabled then
        W.Text(parent, "GLOBAL HOUSE VALUE • SAVED SCORES", 34, W.Colors.Orange, 18)
        local global = leaderboard.Global and leaderboard.Global.HouseValue or {}
        if #global == 0 then W.Text(parent, "Global scores update after successful profile saves.", 50, W.Colors.Muted, 14) end
        for rank, entry in ipairs(global) do W.Text(parent, "#" .. rank .. "  Player " .. entry.UserId .. "  •  $" .. W.Number(entry.Value), 33, W.Colors.Text, 15) end
    else W.Text(parent, "Global scores are available in a published game with persistence enabled.", 56, W.Colors.Muted, 14) end
end

return Progression
