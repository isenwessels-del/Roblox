-- Production spawn/growth state machine; Random and world models are injected boundaries.
local Config = require("../src/shared/Config")
local Random = { new = function()
    return { Fraction = 0, NextNumber = function(self, low, high)
        return low + (high - low) * self.Fraction
    end }
end }
local Wild = require("../src/server/WildHouseService")
local checks = 0
local function check(condition, message) assert(condition, message); checks += 1 end
local function count(entries)
    local total = 0
    for _ in pairs(entries) do total += 1 end
    return total
end
local function fixture()
    local now, guid = 1000, 0
    local ctx = { Config = Config, Steal = { Carriers = {} } }
    ctx.Clock = function() return now end
    ctx.HttpService = { GenerateGUID = function()
        guid += 1
        return "wild-" .. guid
    end }
    -- Model allocation, redraw and destruction are Roblox engine boundaries.
    local world = { WildSites = {}, Models = {}, Updates = {}, Removed = {} }
    ctx.World = world
    for i = 1, Config.Game.WildMax do
        table.insert(world.WildSites, { Id = "site-" .. i, Tier = math.ceil(i / 3),
            Position = { X = i * 10, Y = 3, Z = 0 }, RequiredSpeed = math.ceil(i / 3) * 10 })
    end
    function world:CreatePrefab(offer)
        local model = { Parent = self, Id = offer.Id, Size = offer.Size, Site = offer.Site }
        table.insert(self.Models, model)
        return model
    end
    function world:UpdateWild(offer)
        table.insert(self.Updates, { Id = offer.Id, Size = offer.Size, Model = offer.Model })
        if offer.Model then offer.Model.Size = offer.Size end
    end
    function world:RemovePrefab(offer)
        table.insert(self.Removed, offer.Id)
        if offer.Model then offer.Model.Parent = nil end
    end
    local service = Wild.new(ctx)
    return service, ctx, function(value) now = value end
end

do
    local wild, ctx, setTime = fixture()
    wild:Start()
    check(count(wild.Offers) == 18 and #wild.Sites == 18, "eighteen configured NPC sites create eighteen bounded offers")
    local seen = {}
    for _, site in ipairs(wild.Sites) do
        local offer = site.Offer
        check(offer ~= nil and wild:Get(offer.Id) == offer and not seen[offer.Id], "each site has one unique registered offer")
        seen[offer.Id] = true
        check(offer.Site == site and offer.Position == site.Position and offer.RequiredSpeed == site.RequiredSpeed,
            "offer uses server site position and access speed")
        local rank = Config.Rarities[Config.HouseById[offer.DefinitionId].Rarity].Rank
        check(rank == site.Tier or (site.Tier == 6 and rank == 7), "generated rarity is eligible for its street")
        check(offer.Size == "Normal" and offer.Variant == "Normal" and offer.Model.Parent == ctx.World,
            "new model starts at ordinary size and deterministic first variant")
    end
    wild:Tick()
    check(count(wild.Offers) == 18 and #ctx.World.Models == 18, "ticking occupied sites never duplicates offers")
    local offer = wild.Sites[1].Offer
    setTime(1044); wild:Tick()
    check(offer.Size == "Normal", "growth stays normal before forty-five seconds")
    setTime(1045); wild:Tick()
    check(offer.Size == "Big", "growth becomes big exactly at forty-five seconds")
    setTime(1119); wild:Tick()
    check(offer.Size == "Big", "big growth remains before giant threshold")
    setTime(1120); wild:Tick()
    check(offer.Size == "Giant" and offer.Model.Size == "Giant", "giant threshold updates the world boundary at one hundred twenty seconds")
    check(count(wild.Offers) == 18 and #ctx.World.Models == 18, "growth redraws retain existing offer identities and model count")
    setTime(1050); wild:Tick()
    check(offer.Size == "Giant", "clock regression never shrinks an already grown prefab")
end

do
    local wild, ctx = fixture()
    -- Fraction just below one reaches the last weighted eligible definition.
    -- Real data places Secrets after Mythics; lower tiers must never receive either.
    wild.Random.Fraction = 1 - 1e-10
    wild:Start()
    for _, site in ipairs(wild.Sites) do
        local rank = Config.Rarities[Config.HouseById[site.Offer.DefinitionId].Rarity].Rank
        check(rank == (site.Tier == 6 and 7 or site.Tier), "weighted upper tail admits Secrets only on final street")
        check(site.Offer.Variant == "Void", "variant weighting also uses server random draw")
    end
    local entries = { { Id = "heavy", Weight = 8 }, { Id = "light", Weight = 2 } }
    wild.Random.Fraction = 0.79
    check(wild:_weighted(entries).Id == "heavy", "weighted selection respects cumulative eighty percent first bucket")
    wild.Random.Fraction = 0.81
    check(wild:_weighted(entries).Id == "light", "weighted selection reaches lighter cumulative bucket")
    check(#ctx.World.Models == 18, "rarity and variant choices allocate no extra models")
end

do
    local wild, ctx, setTime = fixture()
    wild:Start()
    local a, b, offer = {}, {}, wild.Sites[1].Offer
    check(wild:Claim("missing", a) == nil and count(wild.Offers) == 18, "invalid offer ID cannot create a free claim")
    check(wild:Claim(offer.Id, a) == offer and offer.Busy == a, "first claimant receives provisional reservation")
    check(wild:Claim(offer.Id, b) == nil and wild:Claim(offer.Id, a) == nil, "contested and duplicate claims cannot reserve same house")
    ctx.Steal.Carriers[a] = { Phase = "Hold" }
    setTime(1045); wild:Tick()
    check(offer.Size == "Big", "a timed hold still allows the source house to grow")
    ctx.Steal.Carriers[a].Phase = "Carry"
    local updates = #ctx.World.Updates
    setTime(1120); wild:Tick()
    check(offer.Size == "Big", "carried provisional house freezes its committed pickup size")
    local ownUpdates = 0
    for i = updates + 1, #ctx.World.Updates do
        if ctx.World.Updates[i].Id == offer.Id then ownUpdates += 1 end
    end
    check(ownUpdates == 0, "carried source is not redrawn at its unattended street site")
    wild:Release(offer.Id, b)
    check(offer.Busy == a, "nonclaimant cannot release another player's reservation")
    wild:Finish(offer.Id, b)
    check(wild:Get(offer.Id) == offer and offer.Site.Offer == offer, "nonclaimant cannot finish or schedule replacement")
    local oldModel, oldId, oldSite = offer.Model, offer.Id, offer.Site
    oldModel.Parent = nil
    wild:Release(offer.Id, a)
    check(offer.Busy == nil and offer.Model ~= oldModel and offer.Model.Parent == ctx.World,
        "cancelled carrier recreates destroyed street model")
    check(offer.Id == oldId and offer.Site == oldSite and offer.Size == "Big" and wild:Get(oldId) == offer,
        "release preserves UID, site and carried size rather than spawning a reroll")
    check(offer.Model.Id == oldId and offer.Model.Site == oldSite and offer.Model.Size == "Big",
        "replacement model is rendered from the original offer")
    wild:Tick()
    check(offer.Size == "Giant", "released house resumes growth from original creation time")
    local models = #ctx.World.Models
    wild:Release(offer.Id, a)
    check(#ctx.World.Models == models, "duplicate release does not recreate a live model")
    ctx.Steal.Carriers[a] = nil
    check(wild:Claim(offer.Id, b) == offer, "released same UID can be claimed by another player")
end

do
    local wild, ctx, setTime = fixture()
    wild:Start()
    local player, offer = {}, wild.Sites[1].Offer
    local site, id = offer.Site, offer.Id
    wild:Claim(id, player)
    setTime(1010); wild:Finish(id, player)
    check(wild:Get(id) == nil and site.Offer == nil and count(wild.Offers) == 17,
        "completed theft removes one source offer and vacates only its site")
    check(site.NextSpawn == 1030 and offer.Model.Parent == nil and #ctx.World.Removed == 1,
        "completion destroys source model and schedules twenty-second respawn")
    wild:Finish(id, player); wild:Release(id, player)
    check(#ctx.World.Removed == 1 and site.NextSpawn == 1030, "replayed completion cannot delay or duplicate respawn")
    setTime(1029); wild:Tick()
    check(site.Offer == nil and count(wild.Offers) == 17, "site remains empty through nineteenth respawn second")
    setTime(1000); wild:Tick()
    check(site.Offer == nil, "regressing clock cannot bypass a future respawn deadline")
    setTime(1030); wild:Tick()
    check(site.Offer and site.Offer.Id ~= id and site.Offer.Size == "Normal" and site.Offer.CreatedAt == 1030,
        "respawn creates a new unique ordinary house at exact deadline")
    check(count(wild.Offers) == 18 and #ctx.World.Models == 19, "respawn restores exactly one missing offer")
    wild:Tick(); wild:Tick()
    check(count(wild.Offers) == 18 and #ctx.World.Models == 19, "repeated deadline ticks do not spawn extra houses")
end

do
    local wild, _, setTime = fixture()
    wild:Start()
    local offer = wild.Sites[1].Offer
    setTime(900); wild:Tick()
    check(offer.Size == "Normal", "negative growth age is clamped to normal size")
    setTime(1045); wild:Tick()
    check(offer.Size == "Big", "clock recovery restores age-based growth")
end

print("PASS: " .. checks .. " production WildHouseService spawn, growth, reservation, release and respawn checks")
