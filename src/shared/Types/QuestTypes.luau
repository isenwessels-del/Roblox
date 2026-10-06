--!strict
export type QuestReward = { Cash: number, XP: number, ItemId: string?, Theme: string? }
export type QuestDefinition = { Id: string, Name: string, Type: string,
    Target: number, Reward: QuestReward, Difficulty: string, Rarity: string? }
export type QuestData = { Daily: {string}, Weekly: {string}, Day: number, Week: number,
    Progress: {[string]: number}, Claimed: {[string]: boolean} }
return {}
