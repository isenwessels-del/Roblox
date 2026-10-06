local function vector(x,y,z)
 local mt={}
 mt.__index=function(v,k) if k=='Magnitude' then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end end
 mt.__add=function(a,b)return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
 mt.__sub=function(a,b)return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
 mt.__mul=function(a,b)if type(a)=='number'then return vector(a*b.X,a*b.Y,a*b.Z)else return vector(a.X*b,a.Y*b,a.Z*b)end end
 return setmetatable({X=x,Y=y,Z=z},mt)
end
local Vector3={new=vector,zero=vector(0,0,0)}
local function matrix(a,b,c,d,e,f,g,h,i)return {a,b,c,d,e,f,g,h,i}end
local function apply(r,v)return vector(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z)end
local function multiply(a,b)local r={} for i=0,2 do for j=1,3 do r[i*3+j]=a[i*3+1]*b[j]+a[i*3+2]*b[j+3]+a[i*3+3]*b[j+6]end end return r end
local cmt={}
local function frame(position,r)return setmetatable({Position=position,R=r or matrix(1,0,0,0,1,0,0,0,1)},cmt)end
cmt.__mul=function(a,b)return frame(a.Position+apply(a.R,b.Position),multiply(a.R,b.R))end
cmt.__index={PointToObjectSpace=function(self,v)local r=self.R return apply(matrix(r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]),v-self.Position)end}
local CFrame={new=function(x,y,z)if type(x)=='table'then return frame(x)else return frame(vector(x or 0,y or 0,z or 0))end end,Angles=function(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 return frame(vector(0,0,0),multiply(multiply(matrix(1,0,0,0,cx,-sx,0,sx,cx),matrix(cy,0,sy,0,1,0,-sy,0,cy)),matrix(cz,-sz,0,sz,cz,0,0,0,1)))end}
local Color3={fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end,new=function(r,g,b)return {R=r,G=g,B=b}end,fromHex=function(hex)return {R=tonumber(string.sub(hex,1,2),16)/255,G=tonumber(string.sub(hex,3,4),16)/255,B=tonumber(string.sub(hex,5,6),16)/255}end}
local Enum=setmetatable({}, {__index=function(t,k)local e=setmetatable({}, {__index=function(_,n)return k..'.'..n end})rawset(t,k,e)return e end})
local UDim2={fromOffset=function(...)return {...}end,fromScale=function(...)return {...}end}
local Vector2={new=function(...)return {...}end}
local methods={}
function methods:FindFirstChild(name)for _,o in ipairs(self.Children)do if not o.Destroyed and o.Name==name then return o end end return nil end
function methods:GetDescendants()local all={} local function visit(o)for _,child in ipairs(o.Children)do if not child.Destroyed then table.insert(all,child)visit(child)end end end visit(self)return all end
function methods:IsA(class)return self.Class==class or(class=='BasePart' and(self.Class=='Part' or self.Class=='SpawnLocation'))end
function methods:SetAttribute(k,v)self.Attributes[k]=v end
function methods:GetAttribute(k)return self.Attributes[k]end
function methods:Destroy()self.Destroyed=true self.Parent=nil for _,o in ipairs(self.Children)do o:Destroy()end end
local Instance={new=function(class)
 local obj={Class=class,Children={},Attributes={},Properties={},Triggered={}}
 function obj.Triggered:Connect(fn)self.Callback=fn return {Disconnect=function()end}end
 return setmetatable(obj,{__index=function(o,k)if methods[k]then return methods[k]end if k=='Position'and o.Properties.CFrame then return o.Properties.CFrame.Position end return o.Properties[k]end,
 __newindex=function(o,k,v)if k=='Parent' and v then table.insert(v.Children,o)end o.Properties[k]=v end})end}
local workspace=Instance.new('Workspace')
local game={GetService=function()return {}end}
local checks=0
local function check(ok,message)checks+=1 assert(ok,message)end

-- EMBED WORLD MODULES HERE

local latest
local ctx={Config={Game=Game,Houses=Houses,Items=Items,Rarities=Rarities,Security=Security},Request=function(...)latest={...}end}
local world=World.new(ctx)world:Init()
check(#world.Plots==8,'eight plots')
local count,slots=0,0 for _,house in pairs(world.NPCs)do count+=1 slots+=#house.SpawnPoints check(world:GetNPCAt(house.Origin+Vector3.new(0,3,0))==house,'NPC bounds resolve')check(world:GetNPCAt(house.EntryPosition)==nil,'entrance outside shell')check(house.Model:FindFirstChild('SecurityPanel')~=nil,'NPC security panel')end
check(count==18 and slots==108,'bounded 18NPC/108loot')
for _,house in pairs(world.NPCs)do local found=false for _,point in ipairs(world.PoliceSpawnPositions)do local delta=point-house.Origin local distance=math.sqrt(delta.X^2+delta.Z^2) if distance>=50 and distance<=160 then found=true break end end check(found,'safe officer spawn near '..house.Id) end
local players={}
for i=1,8 do local player={UserId=i,DisplayName='Player'..i}players[i]=player check(world:Assign(player).Id==i,'plots exclusive')end
check(world:Assign({UserId=9,DisplayName='Overflow'})==nil,'overflow denied')
check(not world:IsInHome(players[1], world:GetPlot(players[2]).HomePad.Position), 'another player homepad is unsafe')
local player=players[1]
for tier=1,10 do local profile={House={Tier=tier,Theme='Ocean',SecurityLevel=tier,Furniture={}}}world:RenderHome(player,profile)local plot=world:GetPlot(player)check(world:IsInHome(player,plot.HomePad.Position),'homepad always safe')check(plot.Model:FindFirstChild('Home'):FindFirstChild('Floor').Size.X==Houses[tier].Width,'tier floor dimensions')end
world:RenderHome(player,{House={Tier=1,Theme='Default',SecurityLevel=1,Furniture={uid={ItemId='PlasticChair',X=3,Z=3,Rotation=90}}}})
local placed=world:GetPlot(player).Model:FindFirstChild('Home'):FindFirstChild('Furniture'):FindFirstChild('uid')
check(placed and placed:GetAttribute('OwnerId')==1,'placed UID and owner')
for _,child in ipairs(placed.PrimaryPart:FindFirstChild('InteractionAttachment').Children)do if child.Class=='ProximityPrompt'then child.Triggered.Callback(player)end end
check(latest[1]==player and latest[2]=='Pickup'and latest[3]=='uid'and latest[4]==1,'pickup centralized router')
for id,item in pairs(Items)do
 local furniture=Factory.Furniture(item,Rarities[item.Rarity],workspace,CFrame.new())
 check(furniture.PrimaryPart and #furniture:GetDescendants()>3,'model '..id)
 check(furniture.PrimaryPart:FindFirstChild('InteractionAttachment')~=nil,'prompt attachment '..id)
 for _,part in ipairs(furniture:GetDescendants())do
  if part:IsA('BasePart')then
   local r,size,pos=part.CFrame.R,part.Size,part.Position
   local x=math.abs(pos.X)+(math.abs(r[1])*size.X+math.abs(r[2])*size.Y+math.abs(r[3])*size.Z)/2
   local z=math.abs(pos.Z)+(math.abs(r[7])*size.X+math.abs(r[8])*size.Y+math.abs(r[9])*size.Z)/2
   check(x<=item.Size.X/2+0.15 and z<=item.Size.Z/2+0.15,'declared placement footprint '..id..'/'..part.Name..' '..x..','..z)
  end
 end
end
local house=world:GetNPC('NPC_1_1')
local rec={UniqueId='testloot',ItemId='PlasticChair',HouseId=house.Id,Position=house.SpawnPoints[1].Position}
local loot=world:RenderLoot(rec)check(loot:GetAttribute('HouseId')==house.Id,'loot target house')
world:RenderLoot(rec)check(loot.Destroyed,'replacing loot cleans oldmodel')world:RemoveLoot(rec)check(world.LootModels.testloot==nil,'loot removal')
world:Release(player)check(world:GetPlot(player)==nil,'release plot')check(world:Assign({UserId=9,DisplayName='Ninth'}).Id==1,'reuse vacant plot')
world:Shutdown()check(workspace:FindFirstChild('StealAHouse')==nil,'shutdown cleanup')
print('PASS '..checks..' actual World/Factory checks with mocked Roblox primitives')
