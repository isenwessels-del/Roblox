--!strict
local ItemTypes = require(script.Parent.ItemTypes)
local HouseTypes = require(script.Parent.HouseTypes)
local QuestTypes = require(script.Parent.QuestTypes)
export type PlayerData = {
    Version: number, Cash: number, Gems: number, XP: number, Level: number,
    House: HouseTypes.HouseData,
    Inventory: {[string]: ItemTypes.OwnedItem},
    ArchivedItems: {[string]: {Entry: ItemTypes.OwnedItem, Location: string, Reason: string}},
    Collection: {[string]: ItemTypes.CollectionEntry}, OwnedThemes: {[string]: boolean},
    Backpack: {Level: number}, Tools: {LockpickLevel: number}, Vehicles: {[string]: any},
    Quests: QuestTypes.QuestData, Achievements: {[string]: boolean | {Claimed: boolean, Unlocked: boolean, Progress: number?}}, Statistics: {[string]: number},
    Settings: {Music: boolean, SFX: boolean, Notifications: boolean, ReducedEffects: boolean,
        CameraShake: boolean, UIScale: number},
    DailyReward: {CurrentDay: number, LastClaim: number}, Playtime: number,
    FirstJoin: boolean, TutorialStep: number, CreatedAt: number,
}
export type RobberyState = { Active: boolean, TargetHouse: string?, StartTime: number,
    Heat: number, ItemsStolen: number, Loot: {[string]: ItemTypes.OwnedItem} }
return {}
