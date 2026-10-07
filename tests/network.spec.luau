-- Execute the production router; engine construction is a labelled boundary.
local Network = require("../src/server/NetworkService")
local checks = 0
local function check(condition, message) assert(condition, message); checks += 1 end
local player = { UserId = 42 }
local calls, notifications, publishes, rateCalls, movementCalls = {}, 0, 0, 0, 0
local profile = { Settings = { Music = true, SFX = true, ReducedEffects = false } }
local ctx = { Closing = false, Ready = { [player] = true }, RateAllowed = true, MovementAllowed = true, Writable = true }
ctx.Validation = { Id = function(value, maximum)
    return type(value) == "string" and #value > 0 and #value <= maximum and value:match("^[%w_%-:]+$") ~= nil
end }
ctx.Data = { Get = function() return profile end, IsWritable = function() return ctx.Writable end }
ctx.AntiExploit = {
    Rate = function(_, p, action) check(p == player, "rate checks actual sender"); rateCalls += 1; return ctx.RateAllowed end,
    ValidateMovement = function(_, p) check(p == player, "movement checks actual sender"); movementCalls += 1; return ctx.MovementAllowed end,
}
ctx.Notify = function() notifications += 1 end
ctx.Publish = function(p) check(p == player, "snapshot for actual sender"); publishes += 1 end
local function service(names)
    local result = {}
    for _, name in ipairs(names) do
        result[name] = function(_, p, ...)
            check(p == player, "service receives actual sender")
            table.insert(calls, { Name = name, Args = table.pack(...) })
            return true, "ok"
        end
    end
    return result
end
ctx.Houses = service({ "Buy", "Sell", "Collect" })
ctx.Steal = service({ "Attempt", "AttemptWild", "Bat" })
ctx.Progression = service({ "Train", "SetSprint", "Lock", "BaseUpgrade", "TreadmillUpgrade", "SecurityUpgrade", "ClaimDaily" })
local router = setmetatable({ Context = ctx }, Network)
local function reset() table.clear(calls); notifications, publishes, rateCalls, movementCalls = 0, 0, 0, 0 end

for _, action in ipairs({ "GiveCash", "CompleteSteal", "Teleport", "SetOwner", "SetIncome", "Rebirth", "", string.rep("a", 33) }) do
    reset(); router:Request(player, action, "uid", 1000000)
    check(#calls == 0 and rateCalls == 0 and movementCalls == 0, "unknown action rejected before routing")
end
for _, action in ipairs({ true, 5, {}, function() end }) do
    reset(); router:Request(player, action)
    check(#calls == 0 and rateCalls == 0, "non-string action rejected")
end
for _, flag in ipairs({ "RateAllowed", "MovementAllowed", "Writable" }) do
    ctx[flag] = false; reset(); router:Request(player, "Buy", "starter_cottage")
    check(#calls == 0, flag .. " stops purchases")
    ctx[flag] = true
end
ctx.Ready[player] = nil; reset(); router:Request(player, "Buy", "starter_cottage")
check(#calls == 0, "loading sender cannot transact")
router:Request(player, "Sync"); check(publishes == 1, "loading sender can request snapshot")
ctx.Ready[player] = true
ctx.Closing = true; reset(); router:Request(player, "Buy", "starter_cottage")
check(#calls == 0 and rateCalls == 0, "closing server declines requests")
ctx.Closing = false

reset(); router:Request(player, "Buy", "starter_cottage", -999)
check(#calls == 1 and calls[1].Name == "Buy" and calls[1].Args.n == 1
    and calls[1].Args[1] == "starter_cottage", "buy forwards definition only; price discarded")
for _, action in ipairs({ "Buy", "Steal", "WildSteal", "Sell", "Collect" }) do
    for _, id in ipairs({ {}, false, 99, "", "../../../bad", string.rep("b", 101) }) do
        reset(); router:Request(player, action, id)
        check(#calls == 0, "malformed item/offer ID blocked for " .. action)
    end
end
local routes = { Steal = "Attempt", WildSteal = "AttemptWild", Collect = "Collect", CollectAll = "Collect",
    Lock = "Lock", Bat = "Bat", BaseUpgrade = "BaseUpgrade", TreadmillUpgrade = "TreadmillUpgrade",
    SecurityUpgrade = "SecurityUpgrade", Daily = "ClaimDaily" }
for action, method in pairs(routes) do
    reset(); router:Request(player, action, "house_uid")
    check(#calls == 1 and calls[1].Name == method, "allowlisted " .. action .. " routes correctly")
end
reset(); router:Request(player, "Sell", "house_uid", "true")
check(#calls == 0, "string does not bypass sale confirmation")
router:Request(player, "Sell", "house_uid", true)
check(#calls == 1 and calls[1].Args[2] == true, "boolean confirmation forwarded for revalidation")
for _, action in ipairs({ "Sprint", "Train" }) do
    reset(); router:Request(player, action, 5000)
    check(#calls == 0, "training/sprint cannot accept requested stat number")
    router:Request(player, action, true); check(#calls == 1, "boolean movement state accepted")
    ctx.Writable = false; ctx.Ready[player] = nil
    reset(); router:Request(player, action, false)
    check(#calls == 1 and movementCalls == 0, "frozen sender can stop own movement mode")
    ctx.Writable = true; ctx.Ready[player] = true
end
reset(); router:Request(player, "Setting", "Cash", true)
check(profile.Settings.Cash == nil and publishes == 0, "setting cannot create economy field")
router:Request(player, "Setting", "Music", false)
check(profile.Settings.Music == false and publishes == 1, "known boolean setting changed")
router:Request(player, "Setting", "Music", {})
check(profile.Settings.Music == false, "non-boolean setting ignored")
reset(); router:Request(player, "OpenShop")
check(notifications == 1 and #calls == 0, "shop display does not buy anything")
print("PASS: " .. checks .. " production router authority and malformed-request checks")
