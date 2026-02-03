local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoxesConfig = require(ReplicatedStorage.Configurations.BoxesConfig)
local BoxesModels = ReplicatedStorage.Assets.Blocks
local BoxesFolder: Folder = workspace:WaitForChild("Boxes")
local BoxSpawnArea: Part = workspace:WaitForChild("Field"):WaitForChild("BoxSpawnArea")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BoxSpawningService = Knit.CreateService { Name = "BoxSpawningService" }

function BoxSpawningService:KnitInit()
end

function BoxSpawningService:KnitStart()
    self:SpawnBoxes(200)
end

function BoxSpawningService:GetRandomBoxConfig()
    local totalWeight = 0
    for _, boxData in ipairs(BoxesConfig) do
        totalWeight += boxData.RarityWeight or 0
    end

    local roll = math.random() * totalWeight
    local current = 0

    for _, boxData in ipairs(BoxesConfig) do
        current += boxData.RarityWeight or 0
        if roll <= current then
            return boxData
        end
    end
end

function BoxSpawningService:SpawnBox(position: Vector3)
    local boxConfig = self:GetRandomBoxConfig()
    local boxModel: Model = BoxesModels:FindFirstChild(boxConfig.Name)

    if not boxModel then
        print(boxConfig.Name .. " Model not found!")
        return
    end

    local box: Model = boxModel:Clone()
    box.Parent = BoxesFolder
    box:PivotTo(CFrame.new(position))
    box:SetAttribute("Rarity", boxConfig.Rarity)
    box:SetAttribute("HitPower", boxConfig.HitPower)
    box:SetAttribute("Color", boxConfig.Color)

    return box
end

function BoxSpawningService:SpawnBoxes(amount: number)
    for i = 1, amount do
        local randomPosition = self:GetRandomPointInSpawnArea()
        self:SpawnBox(randomPosition)
    end
end

function BoxSpawningService:GetRandomPointInSpawnArea(): Vector3
    local size = BoxSpawnArea.Size

    local offset = Vector3.new(
        (math.random() - 0.5) * size.X,
        (math.random() - 0.5) * size.Y,
        (math.random() - 0.5) * size.Z
    )

    return (BoxSpawnArea.CFrame * CFrame.new(offset)).Position
end

return BoxSpawningService