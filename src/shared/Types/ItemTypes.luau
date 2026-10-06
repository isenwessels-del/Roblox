--!strict
export type ItemId = string
export type UniqueId = string
export type ItemDefinition = {
    Id: ItemId, Name: string, Category: string, Rarity: string, Value: number,
    Weight: number, SpawnWeight: number, RequiredArea: number, ModelKind: string,
    Size: {X: number, Z: number}, Sellable: boolean, Tradeable: boolean, Displayable: boolean,
}
export type OwnedItem = { UniqueId: UniqueId, ItemId: ItemId, AcquiredAt: number }
export type PlacedItem = { UniqueId: UniqueId, ItemId: ItemId, AcquiredAt: number,
    X: number, Z: number, Rotation: number }
export type CollectionEntry = { Discovered: boolean, FirstFound: number, Count: number }
return {}
