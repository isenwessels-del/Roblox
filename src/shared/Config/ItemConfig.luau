--!strict
-- Footprints and model kinds feed both generated models and placement validation.
-- Values are final sale prices, not values supplied by a client.
local items = {}
local function item(id: string, name: string, category: string, rarity: string,
    value: number, weight: number, area: number, model: string, x: number, z: number, spawnWeight: number)
    local tags = {}
    if string.find(id, "Golden", 1, true) then table.insert(tags, "Golden") end
    if string.find(id, "Alien", 1, true) or id == "UFO" then table.insert(tags, "Alien") end
    items[id] = {
        Id = id, Name = name, Category = category, Rarity = rarity,
        Value = value, Weight = weight, InventorySize = weight,
        SpawnWeight = spawnWeight, RequiredArea = area,
        Size = { X = x, Z = z }, ModelKind = model, ModelName = id,
        Sellable = true, Tradeable = true, Displayable = true, Tags = tags,
        Golden = string.find(id, "Golden", 1, true) ~= nil,
        Alien = string.find(id, "Alien", 1, true) ~= nil or id == "UFO",
    }
end

item("PlasticChair", "Plastic Chair", "Furniture", "Common", 25, 1, 1, "Chair", 3, 3, 1000)
item("OldTV", "Old TV", "Electronics", "Common", 60, 2, 1, "Screen", 3, 3, 1000)
item("BasicTable", "Basic Table", "Furniture", "Common", 75, 2, 1, "Table", 6, 3, 1000)
item("DeskLamp", "Desk Lamp", "Furniture", "Common", 35, 1, 1, "Plant", 3, 3, 1000)
item("Mattress", "Suspicious Mattress", "Furniture", "Common", 90, 3, 1, "Bed", 6, 6, 1000)
item("Microwave", "Yesterday's Microwave", "Appliance", "Common", 80, 2, 1, "Appliance", 3, 3, 1000)
item("SmallPlant", "Small Plant", "Furniture", "Common", 40, 1, 1, "Plant", 3, 3, 1000)
item("WoodenChair", "Wooden Chair", "Furniture", "Common", 45, 1, 1, "Chair", 3, 3, 1000)
item("CheapSofa", "Discount Sofa", "Furniture", "Common", 150, 3, 1, "Chair", 6, 3, 1000)
item("AlarmClock", "Definitely Not An Alarm", "Electronics", "Common", 30, 1, 1, "Appliance", 3, 3, 1000)
item("RubberDuck", "Rubber Duck", "Art", "Common", 55, 1, 1, "Statue", 3, 3, 1000)
item("GiantSpoon", "Unreasonably Large Spoon", "Art", "Common", 120, 2, 1, "Statue", 3, 6, 1000)
item("ModernTV", "Modern TV", "Electronics", "Uncommon", 350, 3, 1, "Screen", 6, 3, 450)
item("OfficeChair", "Office Chair", "Furniture", "Uncommon", 275, 2, 1, "Chair", 3, 3, 450)
item("Computer", "Office Computer", "Electronics", "Uncommon", 450, 3, 1, "Screen", 3, 3, 450)
item("Bookshelf", "Bookshelf", "Furniture", "Uncommon", 300, 3, 1, "Table", 6, 3, 450)
item("CoffeeMachine", "Emergency Coffee Machine", "Appliance", "Uncommon", 325, 2, 1, "Appliance", 3, 3, 450)
item("GamingConsole", "Gaming Console", "Electronics", "Uncommon", 500, 2, 2, "Appliance", 3, 3, 450)
item("LargeBed", "Large Bed", "Furniture", "Uncommon", 600, 4, 2, "Bed", 6, 8, 450)
item("Speaker", "Party Speaker", "Electronics", "Uncommon", 375, 2, 2, "Appliance", 3, 3, 450)
item("BananaStatue", "Banana Of Importance", "Art", "Uncommon", 800, 3, 2, "Statue", 3, 6, 450)
item("InflatableDinosaur", "Inflatable Dinosaur", "Art", "Uncommon", 900, 4, 2, "Statue", 6, 6, 450)
item("GamingPC", "Gaming PC", "Electronics", "Rare", 2500, 5, 1, "Screen", 3, 3, 180)
item("GamingChair", "Gaming Chair", "Furniture", "Rare", 1200, 4, 1, "Chair", 3, 3, 180)
item("ArcadeMachine", "Arcade Machine", "Electronics", "Rare", 3500, 6, 2, "Appliance", 3, 3, 180)
item("LargeAquarium", "Large Aquarium", "Furniture", "Rare", 3000, 6, 2, "Table", 6, 3, 180)
item("DesignerSofa", "Designer Sofa", "Furniture", "Rare", 2800, 5, 2, "Chair", 6, 3, 180)
item("LuxuryFridge", "Luxury Fridge", "Appliance", "Rare", 4000, 6, 2, "Appliance", 3, 3, 180)
item("RarePainting", "Portrait Of A Duck", "Art", "Rare", 2200, 3, 2, "Screen", 3, 3, 180)
item("GiantToilet", "Giant Toilet", "Furniture", "Rare", 4500, 6, 2, "Chair", 6, 6, 180)
item("TinyCar", "Very Tiny Car", "Vehicle", "Rare", 4200, 5, 2, "Vehicle", 6, 3, 180)
item("GiantChicken", "Giant Chicken", "Art", "Rare", 3800, 5, 2, "Statue", 6, 6, 180)
item("RGBGamingSetup", "RGB Gaming Setup", "Electronics", "Epic", 12000, 8, 2, "Table", 6, 3, 60)
item("GoldenLamp", "Golden Lamp", "Furniture", "Epic", 8500, 4, 3, "Plant", 3, 3, 60)
item("LuxuryBed", "Luxury Bed", "Furniture", "Epic", 16000, 9, 3, "Bed", 6, 8, 60)
item("DiamondSpeaker", "Diamond Speaker", "Electronics", "Epic", 10500, 6, 3, "Appliance", 3, 3, 60)
item("RareStatue", "Extremely Confident Statue", "Art", "Epic", 18000, 8, 3, "Statue", 3, 6, 60)
item("GoldenToaster", "Golden Toaster", "Appliance", "Epic", 7000, 4, 3, "Appliance", 3, 3, 60)
item("MegaTV", "500-Inch TV", "Electronics", "Epic", 20000, 10, 3, "Screen", 8, 3, 60)
item("SingingToilet", "Singing Toilet", "Furniture", "Epic", 15000, 8, 3, "Chair", 3, 6, 60)
item("DiamondMicrowave", "Diamond Microwave", "Appliance", "Epic", 19000, 7, 3, "Appliance", 3, 3, 60)
item("NuclearCouch", "Nuclear Couch", "Furniture", "Epic", 22000, 10, 3, "Chair", 8, 3, 60)
item("GoldenThrone", "Golden Throne", "Furniture", "Legendary", 50000, 12, 3, "Chair", 3, 3, 12)
item("GoldenPiano", "Golden Piano", "Furniture", "Legendary", 85000, 15, 4, "Table", 6, 6, 12)
item("DiamondBathtub", "Diamond Bathtub", "Furniture", "Legendary", 100000, 15, 4, "Bed", 6, 3, 12)
item("LuxuryCarDisplay", "Luxury Car Display", "Vehicle", "Legendary", 150000, 18, 4, "Vehicle", 8, 6, 12)
item("GiantAquarium", "Giant Aquarium", "Furniture", "Legendary", 125000, 16, 4, "Table", 8, 3, 12)
item("GoldenRubberDuck", "Golden Rubber Duck", "Art", "Legendary", 70000, 10, 4, "Statue", 6, 6, 12)
item("DiscoFridge", "Disco Fridge", "Appliance", "Legendary", 95000, 12, 4, "Appliance", 3, 3, 12)
item("DragonStatue", "Dragon Statue", "Art", "Mythic", 500000, 22, 4, "Statue", 6, 6, 2)
item("UFO", "UFO", "Vehicle", "Mythic", 1000000, 25, 5, "Vehicle", 8, 8, 2)
item("GoldenDinosaur", "Giant Golden Dinosaur", "Art", "Mythic", 750000, 24, 5, "Statue", 8, 6, 2)
item("AlienComputer", "Alien Computer", "Electronics", "Mythic", 600000, 18, 4, "Screen", 3, 3, 2)
item("AlienFridge", "Alien Fridge", "Appliance", "Mythic", 900000, 20, 5, "Appliance", 3, 3, 2)
item("GalaxyBed", "Galaxy Bed", "Furniture", "Mythic", 1250000, 25, 5, "Bed", 6, 8, 2)
item("CloudNineSofa", "Cloud Nine Sofa", "Furniture", "Mythic", 1100000, 22, 5, "Chair", 8, 3, 2)
item("MysteryBox", "Mystery Box", "Art", "Secret", 5000000, 30, 5, "Appliance", 3, 3, 0.3)
item("UnknownStatue", "??? Statue", "Art", "Secret", 10000000, 35, 6, "Statue", 6, 6, 0.3)
item("GlitchedTV", "Glitched TV", "Electronics", "Secret", 7500000, 25, 5, "Screen", 6, 3, 0.3)
item("InvisibleFurniture", "Invisible-ish Furniture", "Furniture", "Secret", 6000000, 25, 6, "Table", 6, 3, 0.3)
item("SecretGoldenToilet", "Secret Golden Toilet", "Furniture", "Secret", 15000000, 35, 6, "Chair", 6, 6, 0.3)
item("BlackHoleLamp", "Black Hole Lamp", "Furniture", "Secret", 12000000, 30, 6, "Plant", 3, 3, 0.3)
item("QuantumChicken", "Quantum Chicken", "Art", "Secret", 20000000, 40, 6, "Statue", 6, 6, 0.3)

return items
