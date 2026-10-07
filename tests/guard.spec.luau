local guardChecks=0
local function guardCheck(ok,message)guardChecks+=1;assert(ok,message)end
local caught=0
local guardNow=0
local guardSite=world.WildSites[1]
local guardRoot=player.Character:FindFirstChild("HumanoidRootPart")
local carriers={}
local blocked=false
scene.Raycast=function()if blocked then return {Instance={}}end return nil end
local guardContext={World=world,Workspace=scene,Config=Config,PathfindingService=false,
    Now=function()return guardNow end,Spawn=function(fn)fn()end,
    AntiExploit={Character=function(_,target)if not target.Dead then return target.Character:FindFirstChild("HumanoidRootPart")end end},
    Steal={Carriers=carriers,Cancel=function(_,target)carriers[target]=nil;caught+=1 end},
}
local guards=Guard.new(guardContext)
local function carry()
    local state={Player=player,Wild=true,Phase="Carry",CarriedAt=guardNow,Offer={Site=guardSite}}
    carriers[player]=state
    guardRoot.CFrame=CFrame.new(guardSite.GuardOrigin+Vector3.new(20,2,0))
    return state
end
local state=carry()
guards:Tick(0.1)
guardCheck((guards.Units[guardSite].Position-guardSite.GuardOrigin).Magnitude<0.01,"no pursuit during carry grace")
guardNow=6;guards:Tick(0.1)
guardCheck((guards.Units[guardSite].Position-guardSite.GuardOrigin).Magnitude>0.5,"wild carrier triggers chase after six seconds")
guardCheck((guards.Units[guardSite].Position-guardSite.GuardOrigin).Magnitude<=1.1,"speed bounded")
local prior=guards.Units[guardSite].Position
guardRoot.CFrame=CFrame.new(guardSite.GuardOrigin+Vector3.new(80,2,0))
guards:Tick(0.1)
guardCheck((guards.Units[guardSite].Position-guardSite.GuardOrigin).Magnitude<(prior-guardSite.GuardOrigin).Magnitude,"leaving territory returns guard")
guardRoot.CFrame=CFrame.new(guardSite.GuardOrigin+Vector3.new(20,2,0))
state.Wild=false;guards:Tick(0.1)
guardCheck(guards.Units[guardSite].State==nil,"player house theft never triggers landlord")
state.Wild=true;state.Phase="Hold";guards:Tick(0.1)
guardCheck(guards.Units[guardSite].State==nil,"hold phase gets no chase")
state.Phase="Carry";guardNow=100;guards:Tick(0.1)
guardCheck(guards.Units[guardSite].State==nil,"timed-out carrier no chase")
state.CarriedAt=guardNow-6
guardRoot.CFrame=CFrame.new(guardSite.GuardOrigin+Vector3.new(2,2,0))
blocked=true;guards:Tick(0.1)
guardCheck(caught==0,"wall prevents catch and fallback movement")
blocked=false;guards:Tick(0.1)
guardCheck(caught==1 and carriers[player]==nil,"server catch cancels provisional theft")
state=carry();state.CarriedAt=guardNow-6
guardRoot.CFrame=CFrame.new(world:GetPlot(player).Spawn)
guards:Tick(0.1)
guardCheck(guards.Units[guardSite].State==nil,"own base safe from landlord")
state=carry();state.CarriedAt=guardNow-6;player.Dead=true;guards:Tick(0.1)
guardCheck(guards.Units[guardSite].State==nil,"dead character not chased")
player.Dead=false
guards:Tick(-1);guards:Tick(0/0)
guardCheck(caught==1,"invalid dt produces no catch")
-- Cache a real source path call, with engine path generation replaced.
local pathCalls=0
local queued={}
guardContext.Spawn=function(fn)table.insert(queued,fn)end
guardContext.PathfindingService={CreatePath=function()
    return {Status=Enum.PathStatus.Success,ComputeAsync=function()pathCalls+=1 end,
        GetWaypoints=function()return {{Position=guardSite.GuardOrigin},{Position=guardRoot.Position}}end}
end}
local cached=Guard.new(guardContext)
state=carry();state.CarriedAt=guardNow-6
cached:Tick(0.1)
guardCheck(#queued==1,"path computes asynchronously")
queued[1]();table.clear(queued)
cached:Tick(0.1);guardNow+=1;cached:Tick(0.1)
guardCheck(pathCalls==1 and #queued==0,"path reuse bounded below refresh interval")
guardRoot.CFrame=CFrame.new(guardSite.GuardOrigin+Vector3.new(40,2,0));guardNow+=1
cached:Tick(0.1)
guardCheck(#queued==1,"moving target refreshes path after interval")
carriers[player]=nil;cached:Tick(0.1)
queued[1]()
guardCheck(cached.Units[guardSite].State==nil and cached.Units[guardSite].Path==nil,"stale yielding path ignored after cancellation")
cached:Shutdown();local shutdownPosition=guardSite.GuardModel:GetPivot().Position
guardCheck((shutdownPosition-guardSite.GuardOrigin).Magnitude<0.01,"shutdown restores guard origin")
guards:Shutdown();world:Shutdown()
guardCheck(scene:FindFirstChild("HouseNeighborhood")==nil and next(world.Assigned)==nil,"world shutdown removes generated models and assignments")
print("PASS "..guardChecks.." current GuardService checks with deterministic engine boundaries")
