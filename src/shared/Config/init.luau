--!strict
-- All modules are configuration data; the server remains authoritative.
local config = {
    Game = require(script.GameConfig),
    Economy = require(script.EconomyConfig),
    Items = require(script.ItemConfig),
    Rarities = require(script.RarityConfig),
    Houses = require(script.HouseConfig),
    Backpacks = require(script.BackpackConfig),
    Security = require(script.SecurityConfig),
    Tools = require(script.ToolConfig),
    Quests = require(script.QuestConfig),
    Events = require(script.EventConfig),
    Monetization = require(script.MonetizationConfig),
}

local function freeze(value: any)
    if type(value) == "table" and not table.isfrozen(value) then
        for _, child in pairs(value) do freeze(child) end
        table.freeze(value)
    end
end
freeze(config)
return config
