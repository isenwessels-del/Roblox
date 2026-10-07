-- NPC plots produce growing house boxes; all choices and growth happen here.
local Wild = {}
Wild.__index = Wild
function Wild.new(ctx)
    return setmetatable({ Context = ctx, Offers = {}, Sites = {}, Random = Random.new() }, Wild)
end
function Wild:_weighted(entries)
    local total = 0
    for _, entry in ipairs(entries) do total += entry.Weight end
    local choice = self.Random:NextNumber(0, total)
    for _, entry in ipairs(entries) do choice -= entry.Weight; if choice <= 0 then return entry end end
    return entries[#entries]
end
function Wild:_spawn(site)
    local ctx, eligible = self.Context, {}
    for _, definition in ipairs(ctx.Config.Houses) do
        local rank = ctx.Config.Rarities[definition.Rarity].Rank
        if rank == site.Tier or (site.Tier == 6 and rank == 7) then table.insert(eligible, definition) end
    end
    if #eligible == 0 then eligible = { ctx.Config.Houses[1] } end
    local definition, variant = self:_weighted(eligible), self:_weighted(ctx.Config.Variants)
    local offer = { Id = ctx.HttpService:GenerateGUID(false), DefinitionId = definition.Id,
        Variant = variant.Id, Size = "Normal", Position = site.Position, CreatedAt = ctx.Clock(),
        Site = site, RequiredSpeed = site.RequiredSpeed }
    offer.Model = ctx.World:CreatePrefab(offer)
    self.Offers[offer.Id], site.Offer = offer, offer
    return offer
end
function Wild:Start()
    self.Sites = self.Context.World.WildSites
    for _, site in ipairs(self.Sites) do self:_spawn(site) end
end
function Wild:Get(id) return self.Offers[id] end
function Wild:Claim(id, player)
    local offer = self.Offers[id]
    if not offer or offer.Busy then return nil end
    offer.Busy = player
    return offer
end
function Wild:Release(id, player)
    local offer = self.Offers[id]
    if not offer or offer.Busy ~= player then return end
    offer.Busy = nil
    if not offer.Model or not offer.Model.Parent then offer.Model = self.Context.World:CreatePrefab(offer) end
    self.Context.World:UpdateWild(offer)
end
function Wild:Finish(id, player)
    local offer = self.Offers[id]
    if not offer or offer.Busy ~= player then return end
    self.Context.World:RemovePrefab(offer)
    self.Offers[id], offer.Site.Offer = nil, nil
    offer.Site.NextSpawn = self.Context.Clock() + self.Context.Config.Game.WildRespawnSeconds
end
function Wild:Tick()
    local ctx = self.Context
    for _, site in ipairs(self.Sites) do
        local offer = site.Offer
        if not offer and ctx.Clock() >= (site.NextSpawn or 0) then self:_spawn(site)
        elseif offer then
            local state = offer.Busy and ctx.Steal.Carriers[offer.Busy]
            if not state or state.Phase == "Hold" then
                local age = math.max(0, offer.GrowthAge or 0, ctx.Clock() - offer.CreatedAt)
                offer.GrowthAge = age -- A wall-clock adjustment must never shrink an existing prefab.
                offer.Size = age >= ctx.Config.Game.GrowthGiantSeconds and "Giant"
                    or age >= ctx.Config.Game.GrowthBigSeconds and "Big" or "Normal"
                ctx.World:UpdateWild(offer)
            end
        end
    end
end
return Wild
