--!strict
local FormatNumber = {}
local units = { {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"} }
function FormatNumber.Compact(value: number): string
    if value ~= value or math.abs(value) == math.huge then return "0" end
    local magnitude = math.abs(value)
    for _, unit in ipairs(units) do
        if magnitude >= unit[1] then
            local result = string.format("%.1f", value / unit[1])
            return string.gsub(result, "%.0$", "") .. unit[2]
        end
    end
    return tostring(math.floor(value))
end
function FormatNumber.Integer(value: number): string
    local raw = tostring(math.floor(value))
    local sign = if string.sub(raw, 1, 1) == "-" then "-" else ""
    if sign ~= "" then raw = string.sub(raw, 2) end
    local reversed = string.reverse(raw)
    local grouped = string.gsub(reversed, "(%d%d%d)", "%1,")
    return sign .. string.gsub(string.reverse(grouped), "^,", "")
end
function FormatNumber.Currency(value: number): string return "$" .. FormatNumber.Compact(value) end
FormatNumber.Cash = FormatNumber.Currency
return setmetatable(FormatNumber, { __call = function(_, value: number) return FormatNumber.Compact(value) end })
