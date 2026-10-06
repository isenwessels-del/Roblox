--!strict
local TableUtils = {}
function TableUtils.Clone(value: any, seen: any?): any
    if type(value) ~= "table" then return value end
    local visited = seen or {}
    if visited[value] then return visited[value] end
    local copy = {}
    visited[value] = copy
    for key, child in pairs(value) do copy[TableUtils.Clone(key, visited)] = TableUtils.Clone(child, visited) end
    return copy
end
function TableUtils.Reconcile(value: any, defaults: any): any
    for key, default in pairs(defaults) do
        if value[key] == nil then value[key] = TableUtils.Clone(default)
        elseif type(default) == "table" and type(value[key]) == "table" then
            TableUtils.Reconcile(value[key], default)
        end
    end
    return value
end
function TableUtils.Count(value: any): number
    local count = 0
    for _ in pairs(value) do count += 1 end
    return count
end
return TableUtils
