--!strict
local ItemTypes = require(script.Parent.ItemTypes)
export type HouseDefinition = { Name: string, Cost: number, Value: number,
    Width: number, Depth: number, MaxFurniture: number, RequiredLevel: number }
export type HouseData = {
    Tier: number, Theme: string, SecurityLevel: number, HouseValue: number,
    Exterior: {[string]: string}, Furniture: {[string]: ItemTypes.PlacedItem},
}
export type PlotData = { Id: number, OwnerUserId: number?, Model: Model?, Origin: Vector3 }
return {}
