-- Only engine boundaries are adapted; actual service implementations are bundled by core_runner.py.
local time = 0
local epoch = 20000 * 86400
local os = { clock = function() return time end, time = function() return epoch + math.floor(time) end }
local vectors = {}
function vectors.__index(t, key)
    if key == "Magnitude" then return math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z) end
    return vectors[key]
end
function vectors.__add(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},vectors) end
function vectors.__sub(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},vectors) end
local Vector3 = {new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectors) end}
local RaycastParams = {new=function() return {} end}
local Enum = {RaycastFilterType={Exclude="Exclude"}}
local Random = {new=function() return {NextNumber=function(_,a,b) return a + (b-a)*0.01 end} end}
local task, jobs = {}, {}
function task.spawn(fn)
    local thread = coroutine.create(fn)
    table.insert(jobs,thread)
    local ok,err = coroutine.resume(thread)
    assert(ok,err)
end
function task.wait() coroutine.yield() end
local function advance(seconds)
    for _=1,math.floor(seconds*10) do
        time += 0.1
        for _,thread in ipairs(jobs) do
            if coroutine.status(thread)~="dead" then
                local ok,err=coroutine.resume(thread)
                assert(ok,err)
            end
        end
    end
end
local warn = function() end
