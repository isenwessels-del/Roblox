local checks=0
local function check(condition,message) checks+=1;assert(condition,message) end
local function player(id)
    local root={Position=Vector3.new(0,3,0),CFrame={}}
    local humanoid={Health=100,WalkSpeed=20}
    local result={UserId=id,DisplayName="Player"..id,Root=root,Humanoid=humanoid}
    result.Character={FindFirstChild=function(_,name) return if name=="HumanoidRootPart" then root else nil end,
        FindFirstChildOfClass=function() return humanoid end}
    return result
end
local alice,bob=player(1),player(2)
local profiles={[alice]=ProfileSchema.New(os.time()),[bob]=ProfileSchema.New(os.time())}
local writable,closed,wall=true,false,false
local guid=0
local notifications={}
local ctx={Config=Config,Schema=ProfileSchema,Clock=os.time,Closing=false}
ctx.HttpService={GenerateGUID=function() guid+=1;return "uid-"..guid end}
ctx.Data={Get=function(_,p) return profiles[p] end,IsWritable=function(_,p) return profiles[p]~=nil and writable end}
ctx.Players={GetPlayers=function() return {alice,bob} end}
ctx.Workspace={Raycast=function() return if wall then {Instance={IsDescendantOf=function() return false end}} else nil end}
ctx.Notify=function(_,text) table.insert(notifications,text) end
ctx.Publish=function() end
ctx.Analytics={Emit=function() end}
ctx.Remotes={UI={RareItemFound={FireClient=function() end},AlarmTriggered={FireClient=function() end},Announcement={FireAllClients=function() end},Notification={FireClient=function() end}}}
local plots={[alice]={Id=1,Origin=Vector3.new(0,0,0),HomePad={Position=Vector3.new(0,0,-32)}},
    [bob]={Id=2,Origin=Vector3.new(70,0,0),HomePad={Position=Vector3.new(70,0,-32)}}}
local house={Id="NPC_1_1",Area=1,Difficulty=1,Origin=Vector3.new(100,0,0),EntryPosition=Vector3.new(100,0,-25),SpawnPoints={}}
ctx.World={ShopPosition=Vector3.new(0,0,90),NPCs={[house.Id]=house},
 GetPlot=function(_,p) return plots[p] end,GetNPC=function(_,id) return if id==house.Id then house else nil end,
 GetNPCAt=function(_,pos) return if math.abs(pos.X-100)<30 and math.abs(pos.Z)<25 then house else nil end,
 IsInHome=function(_,p,pos) return (pos-plots[p].Origin).Magnitude<40 end,
 RenderHome=function() end,RenderLoot=function() return {Destroy=function() end} end,RemoveLoot=function() end}
ctx.Police={Remove=function() end}
ctx.Events={Multiplier=function() return 1 end,IsActive=function() return false end,GetActive=function() return nil end}
ctx.AntiExploit=AntiExploitService.new(ctx)
ctx.Economy=EconomyService.new(ctx)
ctx.Inventory=InventoryService.new(ctx)
ctx.House=HouseService.new(ctx)
ctx.Heat=HeatService.new(ctx)
ctx.Security=SecurityService.new(ctx)
ctx.Quest=QuestService.new(ctx)
ctx.Items=ItemService.new(ctx)
ctx.Robbery=RobberyService.new(ctx)
ctx.AntiExploit:Register(alice);ctx.AntiExploit:Register(bob)
ctx.Quest:InitPlayer(alice);ctx.Quest:InitPlayer(bob)
local function move(p,x,z)
    ctx.AntiExploit:AllowTeleport(p)
    p.Root.Position=Vector3.new(x,3,z or 0)
end
local function loot(id,itemId)
 local point={Id=id,Position=Vector3.new(100,0,0),MinRarity=1,MaxRarity=3,Categories={"Furniture"}}
 local original=ctx.Items.Select
 ctx.Items.Select=function() return itemId end
 ctx.Items:Spawn(house,point)
 ctx.Items.Select=original
 for _,r in pairs(ctx.Items.Records) do if r.SpawnId==id then return r end end
 error("loot not spawned")
end
-- Join/setup storage and pure money mutations.
check(profiles[alice].Cash==500,"configured starting currency")
check(ctx.Inventory:Capacity(alice)==5,"starter backpack capacity")
check(not ctx.Economy:AddCash(alice,-1,"Fake"),"negative cash grant rejected")
check(not ctx.Economy:AddCash(alice,0/0,"Fake"),"NaN cash grant rejected")
check(not ctx.Economy:RemoveCash(alice,501,"Fake"),"overspending rejected")
check(profiles[alice].Cash==500,"rejections cannot change balance")
-- Only a legitimate entrance can start one active robbery.
check(not ctx.Robbery:Enter(alice,house.Id),"remote entrance rejected")
move(alice,100,-25)
check(ctx.Robbery:Enter(alice,house.Id),"nearby accessible NPC entrance accepted")
check(not ctx.Robbery:Enter(alice,house.Id),"incompatible concurrent robbery rejected")
check(profiles[alice].TutorialStep==2,"enter tutorial progresses")
local first=loot("first","PlasticChair")
move(alice,100,0)
wall=true
check(not ctx.Robbery:Steal(alice,first.UniqueId),"wall blocks theft")
wall=false
check(ctx.Robbery:Steal(alice,first.UniqueId),"eligible theft begins")
move(bob,100,-25);check(ctx.Robbery:Enter(bob,house.Id),"second player's independent robbery accepted")
move(bob,100,0)
check(not ctx.Robbery:Steal(bob,first.UniqueId),"two thieves cannot reserve one object")
advance(2)
check(ctx.Robbery:Get(alice).ItemsStolen==1,"timed theft completed")
check(ctx.Items:Get(first.UniqueId)==nil,"source loot consumed exactly once")
check(profiles[alice].Inventory[first.UniqueId]==nil,"provisional loot not stored before escape")
check(not ctx.Robbery:Steal(alice,first.UniqueId),"consumed loot cannot replay")
check(ctx.Inventory:CarryWeight(alice)==Config.Items.PlasticChair.Weight,"carry tracks actual item weight")
check(profiles[alice].TutorialStep==3,"steal tutorial progresses")
check(not ctx.Robbery:Escape(alice),"escape away from own home rejected")
move(alice,0,-32)
check(ctx.Robbery:Escape(alice),"home-pad escape secures carry")
check(profiles[alice].Inventory[first.UniqueId]~=nil,"escaped item moves to stored inventory")
check(ctx.Robbery:Get(alice)==nil and ctx.Inventory:CarryWeight(alice)==0,"successful robbery runtime clears")
check(profiles[alice].Statistics.SuccessfulRobberies==1,"success counted once")
check(profiles[alice].Collection.PlasticChair.Count==1,"secured discovery recorded")
check(not ctx.Robbery:Escape(alice),"escape cannot award twice")
-- Placement is an atomic UID movement with grid bounds/collision checks.
move(alice,0,0)
check(not ctx.House:Place(alice,first.UniqueId,0/0,0,0),"NaN placement rejected")
check(not ctx.House:Place(alice,first.UniqueId,1000,0,0),"outside placement rejected")
check(not ctx.House:Place(alice,first.UniqueId,0,0,45),"arbitrary rotation rejected")
check(not ctx.House:Place(bob,first.UniqueId,0,0,0),"other player's placement rejected")
check(ctx.House:Place(alice,first.UniqueId,0,0,90),"valid placement accepted")
check(profiles[alice].Inventory[first.UniqueId]==nil and profiles[alice].House.Furniture[first.UniqueId]~=nil,"only one container owns placed UID")
check(profiles[alice].TutorialStep==5,"placement tutorial progresses")
check(ctx.House:Value(alice)>Config.Houses[1].Value,"display increases server house value")
local second=ctx.Inventory:AddStoredItem(alice,"PlasticChair","Test")
check(not ctx.House:Place(alice,second.UniqueId,0,0,0),"overlapping furniture rejected")
check(not ctx.House:Place(alice,second.UniqueId,0,-9,0),"doorway blocked placement rejected")
check(ctx.House:Pickup(alice,first.UniqueId),"placed item can return to storage")
check(profiles[alice].Inventory[first.UniqueId]~=nil and profiles[alice].House.Furniture[first.UniqueId]==nil,"pickup keeps unique ownership")
check(not ctx.House:Pickup(alice,first.UniqueId),"pickup cannot replay")
-- Shop sales retain confirmation/ownership/proximity even through raw remote calls.
check(not ctx.Economy:Sell(alice,first.UniqueId,true),"sale away from shop rejected")
move(alice,0,90)
local cashBefore=profiles[alice].Cash
check(ctx.Economy:Sell(alice,first.UniqueId,true),"stored sale at shop accepted")
check(profiles[alice].Cash==cashBefore+Config.Items.PlasticChair.Value,"only catalog sale value credited")
check(not ctx.Economy:Sell(alice,first.UniqueId,true),"sale replay rejected")
local rare=ctx.Inventory:AddStoredItem(alice,"GamingChair","Test")
check(not ctx.Economy:Sell(alice,rare.UniqueId,false),"rare sale requires explicit confirmation")
check(ctx.Economy:Sell(alice,rare.UniqueId,true),"confirmed rare sale succeeds")
local readonly=ctx.Inventory:AddStoredItem(alice,"PlasticChair","Test")
writable=false
check(not ctx.Economy:Sell(alice,readonly.UniqueId,true),"frozen profile cannot transact")
check(ctx.Inventory:AddStoredItem(alice,"PlasticChair","Test")==nil,"frozen profile cannot receive items")
writable=true
-- Upgrade, themes and statistics all survive schema validation.
profiles[alice].Cash=100000
profiles[alice].Level=10
check(ctx.Inventory:Upgrade(alice,"Backpack"),"backpack upgrade uses cash and configured next tier")
check(profiles[alice].Backpack.Level==2 and profiles[alice].Statistics.BackpackUpgrades==1,"backpack level and statistics update")
check(not ctx.Inventory:Upgrade(alice,"Fake"),"unknown upgrade rejected")
move(alice,0,0)
check(ctx.House:Upgrade(alice,false),"house upgrade succeeds at home")
check(profiles[alice].House.Tier==2 and profiles[alice].Statistics.HouseUpgrades==1,"tier and upgrade count update")
check(ctx.House:Upgrade(alice,true),"security upgrade succeeds")
check(ctx.House:Customize(alice,"Ocean"),"cosmetic purchased server side")
local themeCash=profiles[alice].Cash
check(ctx.House:Customize(alice,"Ocean") and profiles[alice].Cash==themeCash,"owned theme not charged twice")
check(not ctx.House:Customize(alice,"Fake"),"unknown theme rejected")
check(ProfileSchema.Validate(profiles[alice]),"mutated profile remains persistently serializable/valid")
-- Alarm and policing lose common bags but preserve secured/rare progress.
ctx.Robbery:Fail(bob,"Test cancellation")
move(alice,100,-25);check(ctx.Robbery:Enter(alice,house.Id),"new robbery can start after escape")
local uncommon=loot("low","PlasticChair")
move(alice,100,0);check(ctx.Robbery:Steal(alice,uncommon.UniqueId),"second theft begins")
advance(2)
local rareLoot=loot("rare","GamingChair")
check(ctx.Robbery:Steal(alice,rareLoot.UniqueId),"rare loot theft begins")
advance(2)
ctx.Robbery:Fail(alice,"Caught")
check(profiles[alice].Inventory[rareLoot.UniqueId]~=nil,"rare unsecured loot protected on catch")
check(profiles[alice].Inventory[uncommon.UniqueId]==nil,"common unsecured loot lost on catch")
check(ctx.Robbery:Get(alice)==nil,"failed robbery clears runtime")
check(profiles[alice].Statistics.FailedRobberies==1,"failure counted once")
-- Death and walking out cancel in-flight theft before consuming the shared source.
move(alice,100,-25);ctx.Robbery:Enter(alice,house.Id)
local pending=loot("cancel","PlasticChair")
move(alice,100,0);ctx.Robbery:Steal(alice,pending.UniqueId)
alice.Humanoid.Health=0
advance(2)
check(ctx.Items:Get(pending.UniqueId)~=nil and not pending.Busy,"death cancels source reservation")
alice.Humanoid.Health=100
ctx.Robbery:Fail(alice,"Reset")
-- An old coroutine may wake after the same player starts a new reservation.
move(alice,100,-25);ctx.Robbery:Enter(alice,house.Id)
move(alice,100,0)
check(ctx.Robbery:Steal(alice,pending.UniqueId),"first race attempt begins")
ctx.Robbery:Fail(alice,"Cancel old attempt")
move(alice,100,-25);ctx.Robbery:Enter(alice,house.Id)
move(alice,100,0)
check(ctx.Robbery:Steal(alice,pending.UniqueId),"new attempt reserves same source")
local reservation=pending.Busy
advance(0.2)
check(pending.Busy==reservation,"stale coroutine cannot clear newer reservation")
move(bob,100,-25);ctx.Robbery:Enter(bob,house.Id)
move(bob,100,0)
check(not ctx.Robbery:Steal(bob,pending.UniqueId),"third thief rejected while new reservation stays live")
advance(2)
check(ctx.Robbery:Get(alice).ItemsStolen==1,"new reservation completes once")
ctx.Robbery:Fail(alice,"Test reset")
ctx.Robbery:Fail(bob,"Test reset")
-- Repeated requests cannot consume arbitrary server CPU or mutate nonexistent owned data.
local router=setmetatable({Context=ctx},{__index=NetworkService})
ctx.AntiExploit:AllowTeleport(alice)
advance(3)
local allowed=0
for _=1,40 do if ctx.AntiExploit:Rate(alice,"Place") then allowed+=1 end end
check(allowed<=5,"per-action remote burst bounded")
advance(5)
local before=profiles[alice].Cash
router:Request(alice,"Sell",{},true)
router:Request(alice,"Place","fake",0,0,0)
router:Request(alice,"Setting","Music","notboolean")
check(profiles[alice].Cash==before and profiles[alice].Settings.Music==true,"malformed remotes cannot mutate profile")
router:Request(alice,"Setting","Music",false)
check(profiles[alice].Settings.Music==false,"valid persisted setting accepted")
-- Server-approved spawns have grace; later impossible movement blocks interactions.
ctx.AntiExploit:AllowTeleport(alice)
move(alice,0,0)
ctx.AntiExploit:ValidateMovement(alice)
advance(5)
alice.Root.Position=Vector3.new(500,3,0)
check(not ctx.AntiExploit:ValidateMovement(alice),"impossible post-grace movement blocked")
check(not ctx.AntiExploit:Near(alice,alice.Root.Position,12),"suspicious movement cannot unlock proximity reward")
advance(3)
move(alice,0,0)
ctx.AntiExploit:ValidateMovement(alice)
alice.Root.Position=Vector3.new(15,3,0)
check(ctx.AntiExploit:ValidateMovement(alice),"single latency burst accepted")
alice.Root.Position=Vector3.new(30,3,0)
check(not ctx.AntiExploit:ValidateMovement(alice),"repeated short hops cannot refresh tolerance")
advance(3)
move(alice,0,0)
ctx.AntiExploit:ValidateMovement(alice)
local sprintOK=true
for step=1,10 do
    advance(0.5)
    alice.Root.Position=Vector3.new(step*13,3,0)
    if not ctx.AntiExploit:ValidateMovement(alice) then sprintOK=false end
end
check(sprintOK,"ordinary server-authorized26stud sprint remains valid")
advance(2)
alice.Root.Position=alice.Root.Position+Vector3.new(52,0,0)
check(ctx.AntiExploit:ValidateMovement(alice),"legitimate travel during delayed server sample remains valid")
check(ProfileSchema.Validate(profiles[alice]),"final profile stays valid")
-- Stored gifts cannot consume the capacity already promised to stolen loot.
advance(3)
profiles[alice].Inventory={}
profiles[alice].House.Furniture={}
for index=1,198 do
    local uid="fill-"..index
    profiles[alice].Inventory[uid]={UniqueId=uid,ItemId="PlasticChair",AcquiredAt=os.time()}
end
move(alice,100,-25);ctx.Robbery:Enter(alice,house.Id)
local bagItem=loot("reserved-capacity","PlasticChair")
move(alice,100,0);ctx.Robbery:Steal(alice,bagItem.UniqueId)
advance(2)
check(ctx.Inventory:ReservedCount(alice)==1,"carried item reserves home storage")
local finalItem=loot("last-slot","PlasticChair")
check(ctx.Robbery:Steal(alice,finalItem.UniqueId),"pending theft may target last available capacity")
check(ctx.Inventory:AddStoredItem(alice,"PlasticChair","Gift")~=nil,"only one remaining unreserved storage slot accepts gift")
check(not ctx.Inventory:CanStore(alice,"GamingChair"),"gift cannot displace existing robbery reservation")
advance(2)
check(ctx.Items:Get(finalItem.UniqueId)~=nil,"final theft rechecks changed home storage capacity")
move(alice,0,-32)
check(ctx.Robbery:Escape(alice),"reserved carry still secures into exactly full storage")
check(ctx.Inventory:Count(alice)==200,"no over-cap or lost reserved item after gift race")
print("PASS: "..checks.." real core-service integration checks (mock engine boundaries)")
