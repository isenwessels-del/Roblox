-- Behavioral checks run against live shared modules assembled by shared_runner.py.
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks += 1
end
check(TableUtils.Count(Config.Items) >= 50, "At least50 items")
local rarities = {}
for id, item in pairs(Config.Items) do
    check(item.Id == id and Validation.Id(id), "Canonical item id")
    check(Config.Rarities[item.Rarity] ~= nil, "Rarity exists")
    check(item.Value > 0 and item.Weight > 0 and item.SpawnWeight > 0, "Valid economy")
    check(item.Size.X > 0 and item.Size.X <= 8 and item.Size.Z > 0 and item.Size.Z <= 8, "Bounded footprint")
    check(Config.Game.Areas[item.RequiredArea] ~= nil, "Area exists")
    rarities[item.Rarity] = true
end
check(TableUtils.Count(rarities) == 7, "All seven rarities")
check(#Config.Houses==10 and #Config.Backpacks==7 and #Config.Security==10 and #Config.Tools==10, "Progression content")
for _,reward in ipairs(Config.Economy.DailyRewards) do
    check(not reward.ItemId or Config.Items[reward.ItemId] ~= nil, "Reward item exists")
    check(not reward.Theme or Config.Game.Themes[reward.Theme] ~= nil, "Reward theme exists")
end
local default=ProfileSchema.New(1234)
check(ProfileSchema.Validate(default), "Valid default")
check(default.Cash==500 and default.CreatedAt==1234 and default.OwnedThemes.Default, "Correct defaults")
local migrated,err=ProfileSchema.Migrate({Version=1,Cash=800},1234)
check(migrated~=nil and migrated.Version==2 and migrated.Cash==800, err or "Version1 migration")
check(ProfileSchema.Migrate({Version=3})==nil,"Future schema rejects")
check(ProfileSchema.Migrate(nil)==nil,"Nil existing profile rejects")
check(ProfileSchema.Migrate({Cash=-1})==nil,"Negative cash rejects")
check(ProfileSchema.Migrate({Cash=math.huge})==nil,"Infinite cash rejects")
check(ProfileSchema.Migrate({House="invalid"})==nil,"Malformed house rejects")
local duplicate=ProfileSchema.New(1234)
duplicate.Inventory.a={UniqueId="a",ItemId="PlasticChair",AcquiredAt=0}
duplicate.House.Furniture.a={UniqueId="a",ItemId="PlasticChair",AcquiredAt=0,X=0,Z=0,Rotation=0}
check(ProfileSchema.Migrate(duplicate)==nil,"Duplicate UID rejects")
local archive=ProfileSchema.New(1234)
archive.Inventory.missing={UniqueId="missing",ItemId="RemovedChair",AcquiredAt=1000}
local archived=ProfileSchema.Migrate(archive)
check(archived~=nil and archived.Inventory.missing==nil and archived.ArchivedItems.missing.Entry.ItemId=="RemovedChair", "Removed content archived")
check(archive.Inventory.missing~=nil,"Migration never mutates source")
check(ProfileSchema.Migrate(archived)~=nil,"Archive migration idempotent")
local legacy=ProfileSchema.New(1234)
legacy.Inventory={{UniqueId="b",ItemId="GamingChair",AcquiredAt=500}}
legacy.House.Furniture={{UniqueId="c",ItemId="PlasticChair",Position={X=3,Z=6},Rotation={Y=90}}}
local canonical=ProfileSchema.Migrate(legacy)
check(canonical~=nil and canonical.Inventory.b.ItemId=="GamingChair" and canonical.House.Furniture.c.Z==6,"Legacy array normalization")
check(Validation.Placement(0,0,90,{X=3,Z=6},30,24),"Valid placement")
check(not Validation.Placement(100,0,0,{X=3,Z=3},30,24),"Bounds reject")
check(not Validation.Placement(0/0,0,0,{X=3,Z=3},30,24),"NaN rejects")
check(not Validation.Placement(0,0,45,{X=3,Z=3},30,24),"Arbitrary rotation rejects")
check(not Validation.Placement(1,0,0,{X=3,Z=3},30,24),"Offgrid rejects")
check(Validation.Overlaps({X=0,Z=0,Rotation=0},{X=0,Z=0,Rotation=0},{X=3,Z=3},{X=3,Z=3}),"Overlap detection")
check(not Validation.Overlaps({X=0,Z=0,Rotation=0},{X=3,Z=0,Rotation=0},{X=3,Z=3},{X=3,Z=3}),"Touching edges valid")
local selection=WeightedRandom.Choose({{SpawnWeight=0},{SpawnWeight=2,Name="A"},{SpawnWeight=3,Name="B"}},function()return 0 end)
check(selection.Name=="A","Random lower endpoint")
selection=WeightedRandom.Choose({{SpawnWeight=2,Name="A"},{SpawnWeight=3,Name="B"}},function()return 1 end)
check(selection.Name=="B","Random upper endpoint")
check(WeightedRandom.Choose({{SpawnWeight=0}})==nil,"Zero weights handled")
check(FormatNumber.Currency(1250)=="$1.2K", "Currency format")
check(FormatNumber.Integer(1234567)=="1,234,567", "Grouped format")
local progressed=ProfileSchema.New(1234)
progressed.Level=12
progressed.XP=35
local reloaded=ProfileSchema.Migrate(progressed)
check(reloaded.Level==12 and reloaded.XP==35,"Per-level XP reload preservation")
progressed.Quests.Progress["Daily:EscapeOnce"]="broken"
check(ProfileSchema.Migrate(progressed)==nil,"Malformed quest progress rejects")
print("Shared content/schema/utilities: "..checks.." checks passed")
