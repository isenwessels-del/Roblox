--!strict
local Validation = {}
function Validation.Finite(value: any): boolean
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
function Validation.Integer(value: any, minimum: number?, maximum: number?): boolean
    return Validation.Finite(value) and value % 1 == 0
        and (minimum == nil or value >= minimum) and (maximum == nil or value <= maximum)
end
function Validation.Id(value: any, maxLength: number?): boolean
    return type(value) == "string" and #value > 0 and #value <= (maxLength or 128)
        and string.match(value, "^[%w_%-:]+$") ~= nil
end
function Validation.String(value: any, maxLength: number): boolean
    return type(value) == "string" and #value <= maxLength
end
function Validation.Placement(x: any, z: any, rotation: any, size: any,
    width: number, depth: number, gridSize: number?): (boolean, string?)
    if not Validation.Finite(x) or not Validation.Finite(z)
        or not Validation.Integer(rotation, 0, 270) or rotation % 90 ~= 0 then
        return false, "Placement must use finite coordinates and 90-degree rotations."
    end
    local grid = gridSize or 3
    if grid <= 0 or not Validation.Finite(grid) then return false, "Invalid grid." end
    if math.abs(x / grid - math.round(x / grid)) > 1e-5
        or math.abs(z / grid - math.round(z / grid)) > 1e-5 then
        return false, "Place on the furniture grid."
    end
    local sx, sz = size.X, size.Z
    if rotation % 180 ~= 0 then sx, sz = sz, sx end
    if math.abs(x) + sx / 2 > width / 2 - 1 or math.abs(z) + sz / 2 > depth / 2 - 1 then
        return false, "Furniture must fit inside the house."
    end
    return true, nil
end
function Validation.Overlaps(a: any, b: any, aSize: any, bSize: any): boolean
    local ax, az = aSize.X, aSize.Z
    local bx, bz = bSize.X, bSize.Z
    if a.Rotation % 180 ~= 0 then ax, az = az, ax end
    if b.Rotation % 180 ~= 0 then bx, bz = bz, bx end
    return math.abs(a.X - b.X) < (ax + bx) / 2 - 0.05
        and math.abs(a.Z - b.Z) < (az + bz) / 2 - 0.05
end
Validation.IsFinite = Validation.Finite
Validation.IsId = Validation.Id
return Validation
