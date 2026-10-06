-- Tests run the current PoliceService source with deterministic engine boundaries.
-- Visibility, navigation and rig creation are adapted here; Studio validates
-- Roblox raycasting, physical rigs and pathfinding. Gameplay capture, limits,
-- cleanup and synchronous callbacks are executed by the real service.
local function vec(x,y,z)
    return setmetatable({ X=x, Y=y, Z=z }, {
        __index = function(v,k) if k == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end end,
        __add=function(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end,
        __sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end,
    })
end
local Vector3={new=vec,zero=vec(0,0,0)}
local Players={List={}}
function Players:GetPlayers()return self.List end
local game={GetService=function(_,name) if name=="Players" then return Players else return {} end end}
local Color3={fromRGB=function(...) return {...} end}
local Instance={new=function()return {Destroy=function(self)self.Destroyed=true end}end}
local Police=(function()
-- EMBED POLICE SERVICE SOURCE HERE
end)()
local checks=0
local function check(condition,message)checks+=1;assert(condition,message)end
local function scenario(heat,active,home,alive,visible)
    local suspectRoot={Position=vec(0,0,0),IsA=function()return true end}
    local suspectHumanoid={Health=alive and 100 or 0}
    local player={Parent=Players,UserId=1,Character={
        FindFirstChild=function()return suspectRoot end,
        FindFirstChildOfClass=function()return suspectHumanoid end,
    }}
    Players.List={player}
    local state={Active=active}
    local caught=0
    local ctx={
        Config={Game={MaximumPolice=16,PoliceCatchRadius=5}},
        Heat={Get=function()return heat end},
        Robbery={Get=function()return state end,Fail=function(_,who,reason)
            check(who==player and reason=="Caught by police","capture calls server robbery failure")
            caught+=1;state.Active=false
        end},
        World={IsInHome=function()return home end},
    }
    local service=Police.new(ctx)
    service._visible=function()return visible end
    service._navigate=function()end
    local function add(distance)
        local model={Parent=true,SetAttribute=function()end,Destroy=function(self)self.Parent=nil end}
        local unit={Player=player,Model=model,Root={Parent=true,Position=vec(distance,0,0)},
            Humanoid={Health=100},Label={},State="Investigating",Home=vec(60,0,0),
            LastSeen=vec(0,0,0),LastSeenAt=0,Born=0,PathGeneration=0,Removed=false}
        table.insert(service.Units,unit)
        return unit
    end
    service._spawn=function(self,who) add(60);self.LastSpawn[who]=self.Elapsed end
    return service,player,add,function()return caught end
end
local service,player,add,caught=scenario(59,true,false,true,true)
add(2);service:Tick(1);check(caught()==0,"low heat cannot capture")
service,player,add,caught=scenario(80,true,false,true,false)
add(2);service:Tick(1);check(caught()==0,"police cannot capture through walls")
service,player,add,caught=scenario(80,true,true,true,true)
add(2);service:Tick(1);check(caught()==0 and service.Units[1].State=="Returning","home is safe")
service,player,add,caught=scenario(80,false,false,true,true)
add(2);service:Tick(1);check(caught()==0,"inactive robbery cannot capture")
service,player,add,caught=scenario(80,true,false,false,true)
add(2);service:Tick(1);check(caught()==0 and #service.Units==0,"dead targets clean up")
service,player,add,caught=scenario(80,true,false,true,true)
add(2);add(3);add(4);service:Tick(1);check(caught()==1,"one catch settles once with multiple officers")
service,player,add,caught=scenario(39,true,false,true,true)
service:Tick(1);check(#service.Units==0,"heat under forty does not spawn")
service,player,add,caught=scenario(100,true,false,true,false)
for _=1,28 do service:Tick(1) end
check(#service.Units==3,"three officers maximum per player")
service:Remove(player);check(#service.Units==0 and service.LastSpawn[player]==nil,"player removal releases units and references")
service:Shutdown();service:Tick(1);check(#service.Units==0 and service.Folder.Destroyed,"shutdown is permanent")
service,player,add,caught=scenario(80,true,false,true,true)
local secondPlayer={Parent=Players,UserId=2,Character=player.Character}
Players.List={player,secondPlayer}
local stateByPlayer={[player]={Active=true},[secondPlayer]={Active=true}}
local profile={Statistics={PoliceCatches=0}}
service.Ctx.Data={IsWritable=function()return true end,Get=function()return profile end}
service.Ctx.Robbery.Get=function(_,who)return stateByPlayer[who]end
service.Ctx.Robbery.Fail=function(_,who)
    check(profile.Statistics.PoliceCatches==1,"capture statistic increments before synchronous failure cleanup")
    stateByPlayer[who].Active=false
    service:Remove(who)
end
local moved={}
service._navigate=function(_,unit)moved[unit]=(moved[unit] or 0)+1 end
local first=add(2)
local otherA=add(60);otherA.Player=secondPlayer
local last=add(3)
local otherB=add(70);otherB.Player=secondPlayer
service:Tick(1)
check(first.Removed and last.Removed,"failure callback can synchronously remove all suspect officers")
check(moved[otherA]==1 and moved[otherB]==1,"other suspects tick exactly once despite shifted indices")
check(#service.Units==2,"other suspects survive callback cleanup")
check(profile.Statistics.PoliceCatches==1,"simultaneous officers increment capture statistic once")
check(service.Metrics.Ticks==1 and service.Metrics.Captures==1,"tick and capture metrics count actual decisions")
check(service.Metrics.Despawned==2 and service.Metrics.Live==2,"cleanup metrics track surviving officers")
local map={Parent={}}
service.Ctx.World.Map=map
service:Tick(1)
check(service.Folder.Parent==map,"police folder attaches to world after late initialization")
service,player,add,caught=scenario(80,true,false,true,true)
local readOnlyProfile={Statistics={PoliceCatches=7}}
service.Ctx.Data={IsWritable=function()return false end,Get=function()return readOnlyProfile end}
add(2);service:Tick(1)
check(readOnlyProfile.Statistics.PoliceCatches==7,"capture does not mutate read-only profile")
service,player,add,caught=scenario(40,true,false,true,false)
service.Ctx.Events={IsActive=function(_,id)return id=="PoliceRaid"end}
for _=1,21 do service:Tick(1) end
check(#service.Units==2,"police raid increases investigating officer count")
service,player,add,caught=scenario(100,true,false,true,false)
service.Ctx.Events={IsActive=function(_,id)return id=="PoliceRaid"end}
for _=1,28 do service:Tick(1) end
check(#service.Units==3,"police raid still caps officers per player")
service,player,add,caught=scenario(39,true,false,true,false)
service.Ctx.Events={IsActive=function(_,id)return id=="PoliceRaid"end}
service:Tick(1)
check(#service.Units==0,"police raid retains minimum heat requirement")
print("Police gameplay safety checks passed: "..checks)
