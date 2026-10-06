local ItemService = {}
ItemService.__index = ItemService
function ItemService.new(ctx)
    return setmetatable({ Context = ctx, Records = {}, Slots = {}, Random = Random.new() }, ItemService)
end
function ItemService:Select(house, spawn)
    local ctx = self.Context
    local pool, total = {}, 0
    for id, item in pairs(ctx.Config.Items) do
        local rank = ctx.Config.Rarities[item.Rarity].Rank
        local minimum = tonumber(spawn.MinRarity) or ctx.Config.Rarities[spawn.MinRarity or "Common"].Rank
        local maximum = tonumber(spawn.MaxRarity) or ctx.Config.Rarities[spawn.MaxRarity or "Secret"].Rank
        local categoryAllowed = not spawn.Categories or table.find(spawn.Categories, item.Category) ~= nil
        if categoryAllowed and item.RequiredArea <= house.Area and rank >= minimum and rank <= maximum then
            local weight = math.max(0, item.SpawnWeight)
            if item.Tags and table.find(item.Tags, "Golden") and ctx.Events:IsActive("GoldenHour") then weight *= ctx.Events:Multiplier("Spawn") end
            if item.Tags and table.find(item.Tags, "Alien") and ctx.Events:IsActive("AlienInvasion") then weight *= 4 end
            if weight > 0 then total += weight; table.insert(pool, { Id = id, Weight = weight }) end
        end
    end
    if total <= 0 then return nil end
    table.sort(pool, function(a, b) return a.Id < b.Id end)
    local roll = self.Random:NextNumber(0, total)
    for _, row in ipairs(pool) do roll -= row.Weight; if roll <= 0 then return row.Id end end
    return pool[#pool].Id
end
function ItemService:Spawn(house, point)
    local ctx = self.Context
    local key = house.Id .. ":" .. point.Id
    local slot = self.Slots[key]
    if slot and slot.Record then return end
    local itemId = self:Select(house, point)
    if not itemId then return end
    local record = { UniqueId = ctx.HttpService:GenerateGUID(false), ItemId = itemId, HouseId = house.Id,
        SpawnId = point.Id, Position = point.Position, SlotKey = key }
    local ok, model = pcall(function() return ctx.World:RenderLoot(record) end)
    if not ok or not model then
        warn("[LootSpawn]", key, tostring(model))
        self.Slots[key] = { House = house, Point = point, Ready = os.clock() + 5 }
        return
    end
    record.Model = model
    self.Records[record.UniqueId] = record
    self.Slots[key] = { House = house, Point = point, Record = record }
end
function ItemService:Start()
    for _, house in pairs(self.Context.World.NPCs) do
        for _, point in ipairs(house.SpawnPoints) do self:Spawn(house, point) end
    end
end
function ItemService:Get(id) return self.Records[id] end
function ItemService:Consume(record)
    if self.Records[record.UniqueId] ~= record then return false end
    self.Records[record.UniqueId] = nil
    self.Context.World:RemoveLoot(record)
    local slot = self.Slots[record.SlotKey]
    if slot then slot.Record = nil; slot.Ready = os.clock() + self.Context.Config.Game.ItemRespawnSeconds end
    return true
end
function ItemService:Tick()
    for _, slot in pairs(self.Slots) do
        if not slot.Record and (slot.Ready or 0) <= os.clock() then self:Spawn(slot.House, slot.Point) end
    end
end
return ItemService
