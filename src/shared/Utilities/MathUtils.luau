--!strict
local MathUtils = {}
function MathUtils.Snap(value: number, grid: number): number return math.round(value / grid) * grid end
function MathUtils.LevelFromXP(xp: number, perLevel: number): number return 1 + math.floor(math.max(0, xp) / perLevel) end
function MathUtils.RotatedSize(size: any, rotation: number): (number, number)
    if rotation % 180 == 0 then return size.X, size.Z end
    return size.Z, size.X
end
return MathUtils
