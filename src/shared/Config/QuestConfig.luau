--!strict
return {
    StealFiveItems = { Id = "StealFiveItems", Name = "Pocket Change", Type = "StealItems", Target = 5, Reward = { Cash = 500, XP = 50 }, Difficulty = "Easy" },
    EscapeOnce = { Id = "EscapeOnce", Name = "Home Sweet Home", Type = "CompleteRobbery", Target = 1, Reward = { Cash = 500, XP = 75 }, Difficulty = "Easy" },
    SellThreeItems = { Id = "SellThreeItems", Name = "Furniture Flipper", Type = "SellItems", Target = 3, Reward = { Cash = 750, XP = 60 }, Difficulty = "Easy" },
    FindRare = { Id = "FindRare", Name = "Blue Treasure", Type = "FindRarity", Rarity = "Rare", Target = 1, Reward = { Cash = 1500, XP = 120 }, Difficulty = "Medium" },
    EscapeThreeTimes = { Id = "EscapeThreeTimes", Name = "Getaway Expert", Type = "CompleteRobbery", Target = 3, Reward = { Cash = 2000, XP = 150 }, Difficulty = "Medium" },
    EarnFiveThousand = { Id = "EarnFiveThousand", Name = "Growing Fortune", Type = "EarnCash", Target = 5000, Reward = { Cash = 1500, XP = 120 }, Difficulty = "Medium" },
    StealTwentyItems = { Id = "StealTwentyItems", Name = "Moving Day", Type = "StealItems", Target = 20, Reward = { Cash = 5000, XP = 250 }, Difficulty = "Hard" },
    FindEpic = { Id = "FindEpic", Name = "Purple Payday", Type = "FindRarity", Rarity = "Epic", Target = 1, Reward = { Cash = 5000, XP = 250 }, Difficulty = "Hard" },
    EscapeFiveTimes = { Id = "EscapeFiveTimes", Name = "Uncatchable", Type = "CompleteRobbery", Target = 5, Reward = { Cash = 7500, XP = 300 }, Difficulty = "Hard" },
    WeeklyCollector = { Id = "WeeklyCollector", Name = "Weekly Haul", Type = "StealItems", Target = 100, Reward = { Cash = 20000, XP = 1000 }, Difficulty = "Weekly" },
    WeeklyEscapes = { Id = "WeeklyEscapes", Name = "Weekly Getaways", Type = "CompleteRobbery", Target = 20, Reward = { Cash = 25000, XP = 1000 }, Difficulty = "Weekly" },
}
