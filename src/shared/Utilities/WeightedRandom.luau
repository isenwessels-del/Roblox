--!strict
-- Inject a function returning a number in [0, 1) for deterministic simulations.
local WeightedRandom = {}
local function finite(value: any): boolean
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function roll(randomSource: any): number
    local value
    if randomSource == nil then
        value = math.random()
    elseif type(randomSource) == "function" then
        value = randomSource()
    else
        value = randomSource:NextNumber()
    end
    assert(finite(value) and value >= 0 and value <= 1, "Random source must return a value in [0,1]")
    return math.min(value, 1 - 1e-12)
end
function WeightedRandom.Choose(entries: {any}, randomSource: any?, weightKey: string?): (any?, number?)
    local total = 0
    local weights = {}
    for index, entry in ipairs(entries) do
        local weight = entry[weightKey or "SpawnWeight"] or entry.Weight or 0
        if finite(weight) and weight > 0 then
            total += weight
            weights[index] = weight
        end
    end
    if total <= 0 or not finite(total) then return nil, nil end
    local target = roll(randomSource) * total
    for index, entry in ipairs(entries) do
        target -= weights[index] or 0
        if target < 0 then return entry, index end
    end
    return nil, nil
end
function WeightedRandom.Pick(entries: {[string]: any}, randomSource: any?, weightFunction: any?): (any?, string?)
    local ids = {}
    for id in pairs(entries) do table.insert(ids, id) end
    table.sort(ids)
    local weighted = {}
    for _, id in ipairs(ids) do
        local entry = entries[id]
        table.insert(weighted, {
            Id = id, Entry = entry,
            SpawnWeight = if weightFunction then weightFunction(entry, id) else entry.SpawnWeight,
        })
    end
    local selected = WeightedRandom.Choose(weighted, randomSource)
    if selected then return selected.Entry, selected.Id end
    return nil, nil
end
return WeightedRandom
