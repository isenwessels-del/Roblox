-- Primitive adapters exercise production source; they do not simulate Studio.
local function vector(x, y, z)
    local mt = {}
    mt.__index = function(v, key)
        if key == "Magnitude" then return math.sqrt(v.X^2 + v.Y^2 + v.Z^2) end
        if key == "Unit" then local m = math.sqrt(v.X^2 + v.Y^2 + v.Z^2); return vector(v.X/m, v.Y/m, v.Z/m) end
    end
    mt.__add = function(a, b) return vector(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
    mt.__sub = function(a, b) return vector(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
    mt.__mul = function(a, b)
        if type(a) == "number" then return vector(a*b.X, a*b.Y, a*b.Z) end
        return vector(a.X*b, a.Y*b, a.Z*b)
    end
    return setmetatable({ X=x, Y=y, Z=z }, mt)
end
local Vector3 = { new=vector, zero=vector(0, 0, 0) }
local function matrix(a,b,c,d,e,f,g,h,i) return {a,b,c,d,e,f,g,h,i} end
local function apply(r,v) return vector(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z) end
local function multiply(a,b)
    local r = {}
    for i=0,2 do for j=1,3 do r[i*3+j]=a[i*3+1]*b[j]+a[i*3+2]*b[j+3]+a[i*3+3]*b[j+6] end end
    return r
end
local cmt, cm = {}, {}
local function frame(position, r) return setmetatable({ Position=position, R=r or matrix(1,0,0,0,1,0,0,0,1) }, cmt) end
cmt.__mul = function(a,b) return frame(a.Position+apply(a.R,b.Position),multiply(a.R,b.R)) end
cmt.__index = function(v,k) if k == "Rotation" then return frame(vector(0,0,0),v.R) end return cm[k] end
function cm:PointToObjectSpace(v) local r=self.R; return apply(matrix(r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]),v-self.Position) end
function cm:PointToWorldSpace(v) return self.Position+apply(self.R,v) end
function cm:Inverse() local r=self.R; local t=matrix(r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]); return frame(apply(t,self.Position)*-1,t) end
local CFrame = {
    new=function(x,y,z) if type(x)=="table" then return frame(x) end return frame(vector(x or 0,y or 0,z or 0)) end,
    Angles=function(x,y,z)
        local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
        return frame(vector(0,0,0),multiply(multiply(matrix(1,0,0,0,cx,-sx,0,sx,cx),matrix(cy,0,sy,0,1,0,-sy,0,cy)),matrix(cz,-sz,0,sz,cz,0,0,0,1)))
    end,
    lookAt=function(position,target)
        local direction=target-position; local horizontal=math.sqrt(direction.X^2+direction.Z^2)
        return frame(position,matrix(-direction.Z/horizontal,0,-direction.X/horizontal,0,1,0,direction.X/horizontal,0,-direction.Z/horizontal))
    end,
}
local Color3 = {
    fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255,Kind="Color3"} end,
    new=function(r,g,b) return {R=r,G=g,B=b,Kind="Color3"} end,
}
local nativeTypeof = typeof
local function typeof(value) return type(value)=="table" and value.Kind or nativeTypeof(value) end
local Enum = {
    Material={SmoothPlastic="SmoothPlastic",Concrete="Concrete",ForceField="ForceField",Neon="Neon",Asphalt="Asphalt",Grass="Grass",Glass="Glass"},
    SurfaceType={Smooth="Smooth"}, Font={GothamBold="GothamBold"},
    KeyCode={E="E",ButtonX="ButtonX"}, ProximityPromptExclusivity={OnePerButton="OnePerButton"},
    RaycastFilterType={Exclude="Exclude"}, PathStatus={Success="Success"},
}
local UDim2={fromOffset=function(...)return {...}end,fromScale=function(...)return {...}end}
local UDim={new=function(...)return {...}end}
local RaycastParams={new=function()return {}end}
local function signal()
    local value={Callbacks={}}
    function value:Connect(callback)
        table.insert(self.Callbacks,callback)
        return {Disconnect=function()for i,fn in ipairs(self.Callbacks)do if fn==callback then table.remove(self.Callbacks,i);break end end end}
    end
    function value:Fire(...) local callbacks=table.clone(self.Callbacks); for _,callback in ipairs(callbacks)do callback(...)end end
    return value
end
local methods = {}
function methods:FindFirstChild(name) for _,child in ipairs(self.Children)do if not child.Destroyed and child.Name==name then return child end end end
function methods:GetDescendants()
    local all={};local function visit(value)for _,child in ipairs(value.Children)do if not child.Destroyed then table.insert(all,child);visit(child)end end end
    visit(self);return all
end
function methods:IsA(class) return self.Class==class or(class=="BasePart" and self.Class=="Part") end
function methods:SetAttribute(key,value) self.Attributes[key]=value end
function methods:GetAttribute(key) return self.Attributes[key] end
function methods:GetPivot() return self.PrimaryPart and self.PrimaryPart.CFrame or self.Pivot or CFrame.new() end
function methods:PivotTo(target)
    local inverse=self:GetPivot():Inverse()
    for _,part in ipairs(self:GetDescendants())do if part:IsA("BasePart")then part.CFrame=target*inverse*part.CFrame end end
    self.Pivot=target
end
function methods:Destroy()
    self.Destroyed=true;self.Parent=nil
    for _,child in ipairs(self.Children)do child:Destroy()end
end
local Instance={new=function(class)
    local object={Class=class,Children={},Attributes={},Properties={},Triggered=signal(),Touched=signal(),DescendantAdded=signal()}
    if class=="Part"then object.Properties.CanCollide=true;object.Properties.CanQuery=true end
    return setmetatable(object,{
        __index=function(value,key)
            if methods[key]then return methods[key]end
            if key=="Position" and value.Properties.CFrame then return value.Properties.CFrame.Position end
            return value.Properties[key]
        end,
        __newindex=function(value,key,item)
            if key=="Parent" and item then table.insert(item.Children,value)end
            value.Properties[key]=item
        end,
    })
end}
local scene=Instance.new("Workspace")
local collision={Registered={},Pairs={}}
function collision:IsCollisionGroupRegistered(name)return self.Registered[name]==true end
function collision:RegisterCollisionGroup(name)self.Registered[name]=true end
function collision:CollisionGroupSetCollidable(a,b,value)self.Pairs[a.."/"..b]=value end
local game={GetService=function(_,name)assert(name=="PhysicsService","unexpected service "..name);return collision end}
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end

-- EMBED WORLD MODULES HERE

local now,latest=1000,nil
local players={}
local ctx={Config=Config,Workspace=scene,Now=function()return now end,Clock=function()return now end,
    Request=function(...)latest={...}end,
    Players={GetPlayerFromCharacter=function(_,character)for _,player in ipairs(players)do if player.Character==character then return player end end end},
}
local world=World.new(ctx);world:Init()
check(#world.Plots==7,"seven reference-size bases")
check(#world.WildSites==18,"eighteen bounded landlord sites")
local seen={}
for id,plot in ipairs(world.Plots)do
    check(#plot.Pads==20 and plot.Capacity==10,"ten initial slots, twenty bounded pads")
    for other=1,7 do
        check(collision.Pairs["HouseBaseGate"..id.."/HouseBaseOwner"..other]==(other~=id),"owner-only gate pass")
    end
    check(collision.Pairs["HouseBaseGate"..id.."/HouseVisitors"]==true,"visitors collide")
    check(#plot.Gates==5,"complete shield walls and roof")
    world:SetLock(plot,true,42)
    for _,gate in ipairs(plot.Gates)do check(gate.CanCollide and gate.CanQuery,"locked barrier blocks physics and LOS")end
    world:SetLock(plot,false,0)
    for _,gate in ipairs(plot.Gates)do check(not gate.CanCollide and not gate.CanQuery,"unlocked barrier invisible to raycast")end
    for slot,pad in ipairs(plot.Pads)do
        local localPosition=plot.Frame:PointToObjectSpace(pad.Part.Position)
        check(math.abs(localPosition.X)+pad.Part.Size.X/2<66 and math.abs(localPosition.Z)+pad.Part.Size.Z/2<63,"pads fit floor")
        check(not pad.Prompt.Enabled,"empty rent prompt disabled")
        local key=pad.Part.Position.X.."/"..pad.Part.Position.Z
        check(not seen[key],"all base slots spatially unique");seen[key]=true
    end
end
for index,site in ipairs(world.WildSites)do
    check(site.Id=="site_"..index and site.GuardModel~=nil,"unique site and landlord")
    check(site.RequiredSpeed>=Config.Game.MoveSpeed,"gated district speed")
    check(site.GuardModel.PrimaryPart~=nil,"landlord explicit pivot")
    for _,part in ipairs(site.GuardModel:GetDescendants())do
        if part:IsA("BasePart")then check(part.Anchored and not part.CanCollide and not part.CanTouch,"safe anchored moving guard")end
    end
end
for index,site in ipairs(world.WildSites)do
    local part=site.Model:FindFirstChild("Territory")
    local extentX=(math.abs(part.CFrame.R[1])*part.Size.X+math.abs(part.CFrame.R[3])*part.Size.Z)/2
    local extentZ=(math.abs(part.CFrame.R[7])*part.Size.X+math.abs(part.CFrame.R[9])*part.Size.Z)/2
    for other=index+1,#world.WildSites do
        local neighbor=world.WildSites[other].Model:FindFirstChild("Territory")
        local nx=(math.abs(neighbor.CFrame.R[1])*neighbor.Size.X+math.abs(neighbor.CFrame.R[3])*neighbor.Size.Z)/2
        local nz=(math.abs(neighbor.CFrame.R[7])*neighbor.Size.X+math.abs(neighbor.CFrame.R[9])*neighbor.Size.Z)/2
        check(math.abs(part.Position.X-neighbor.Position.X)>=extentX+nx
            or math.abs(part.Position.Z-neighbor.Position.Z)>=extentZ+nz,"NPC territory ground plates do not overlap")
    end
end
for index=1,7 do
    local character=Instance.new("Model")
    local root=Factory.Part(character,"HumanoidRootPart",Vector3.new(2,2,1),CFrame.new(),"FFFFFF")
    local player={UserId=index,DisplayName="Player "..index,Character=character}
    players[index]=player
    local plot=world:Assign(player)
    check(plot.Id==index and world:Assign(player)==plot,"exclusive stable assignment")
    root.CFrame=CFrame.new(plot.Spawn)
    check(world:AtHome(player),"spawn within own base")
    check(not world:Inside(player,world.Plots[index%7+1]),"other base is not home")
    check(root.CollisionGroup=="HouseBaseOwner"..index,"character gets own collision group")
end
check(world:Assign({UserId=8,DisplayName="Overflow"})==nil,"full server rejects assignment")
local player=players[1]
local plot=world:GetPlot(player)
check(world:SlotPosition(plot,0)==nil and world:SlotPosition(plot,21)==nil and world:SlotPosition(plot,1.5)==nil,"bad slot indices rejected")
for index,definition in ipairs(Config.Houses)do
    local record={Id="house_"..index,DefinitionId=definition.Id,Slot=1,Size="Giant",Variant="Gold",BuildReadyAt=now}
    local model=world:RenderHouse(player,record)
    check(model and model:GetAttribute("HouseId")==record.Id and model:GetAttribute("OwnerId")==1,"canonical render identity")
    check(world:GetHouseModel(player,record.Id)==model,"server model lookup")
    check(plot.Pads[1].Uid==record.Id and plot.Pads[1].Prompt.Enabled,"occupied rent prompt enabled")
    for _,part in ipairs(model:GetDescendants())do
        if part:IsA("BasePart")then
            local relative=plot.Frame:Inverse()*part.CFrame
            local position,r,size=relative.Position,relative.R,part.Size
            local extentX=(math.abs(r[1])*size.X+math.abs(r[2])*size.Y+math.abs(r[3])*size.Z)/2
            local extentZ=(math.abs(r[7])*size.X+math.abs(r[8])*size.Y+math.abs(r[9])*size.Z)/2
            check(math.abs(position.X)+extentX<66 and math.abs(position.Z)+extentZ<63,"giant house full oriented footprint within base")
        end
    end
    model:FindFirstChild("HousePrompt"):FindFirstChild("Interact").Triggered:Fire(player)
    check(latest[2]=="Sell" and latest[3]==record.Id and latest[4]==false,"own sale opens confirmation only")
    model:FindFirstChild("HousePrompt"):FindFirstChild("Interact").Triggered:Fire(players[2])
    check(latest[2]=="Steal" and latest[3]==record.Id,"visitor routes theft centrally")
    world:UpdateIncome(player,record.Id,750)
    check(plot.Pads[1].Text.Text=="COLLECT $750","rent visible on matching pad")
    world:RemoveHouse(player,record.Id)
    check(model.Destroyed and plot.Pads[1].Uid==nil and not plot.Pads[1].Prompt.Enabled,"render cleanup and rent reset")
end
local record={Id="construction",DefinitionId=Config.Houses[1].Id,Slot=2,Size="Normal",Variant="Normal",BuildReadyAt=now+6}
local box=world:RenderHouse(player,record)
check(box:FindFirstChild("PrefabBox")~=nil,"construction displays prefab")
world:UpdateIncome(player,record.Id,321)
now+=6;world:Tick(1)
local finished=world:GetHouseModel(player,record.Id)
check(box.Destroyed and finished:FindFirstChild("Walls")~=nil,"construction completes to house")
check(finished:FindFirstChild("HousePrompt"):FindFirstChild("Interact").HoldDuration==0,"physical house prompt does not double server theft timer")
check(plot.Pads[2].Text.Text=="COLLECT $321","rebuild preserves accrued rent display")
world:UpdateSlots(player,20)
check(plot.Capacity==20,"base upgrades enable twenty slots")
world:UpdateTreadmill(player,3,true)
check(plot.TreadmillText.Text:find("TRAINING")~=nil,"training state display")
local site=world.WildSites[1]
local offer={Id="wild_test",DefinitionId=Config.Houses[1].Id,Variant="Normal",Size="Normal",Position=site.Position,Site=site,RequiredSpeed=20}
local prefab=world:CreatePrefab(offer)
check(prefab:FindFirstChild("PrefabBox")~=nil and offer.WorldPrompt.RequiresLineOfSight,"growing wild prefab prompt")
check(offer.WorldPrompt.HoldDuration==0,"wild pickup uses only authoritative server timer")
local promptPosition=prefab:GetPivot():PointToObjectSpace(offer.WorldPrompt.Parent.Position)
check(promptPosition.Z < -5.4,"wild prompt outside opaque box")
offer.WorldPrompt.Triggered:Fire(player)
check(latest[2]=="WildSteal" and latest[3]==offer.Id,"wild theft centralized")
offer.Size="Giant";world:UpdateWild(offer)
check(prefab.Destroyed and offer.WorldSize=="Giant","growth rebuild cleans previous prefab")
offer.Busy=player;world:UpdateWild(offer)
check(not offer.WorldPrompt.Enabled,"reserved wild crate prompt disabled")
local carried=world:CarryModel(player,record)
check(carried:GetAttribute("HouseUID")==record.Id,"carry model canonical UID")
for _,part in ipairs(carried:GetDescendants())do
    if part:IsA("BasePart")then check(not part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and part.Massless,"carry cannot fling/query block")end
end
world:ClearCarry(player);check(carried.Destroyed and world.Carry[player]==nil,"carry cleanup")
world:RemovePrefab(offer);check(offer.Model==nil and world.SiteOffers[offer.Id]==nil,"wild model cleanup")
world:Release(player)
check(world:GetPlot(player)==nil and plot.Owner==nil and not plot.Locked,"release vacant unlocked base")
check(world:Assign(player).Id==1,"vacated base reusable")
print("PASS "..checks.." current World/Factory checks with primitive Roblox adapters")
