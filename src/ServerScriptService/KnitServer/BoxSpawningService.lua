local CollectionService = game:GetService("CollectionService")
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
    BoxSpawningService.BoxDamageService = Knit.GetService("BoxDamageService")

    self:SpawnBoxes(150)
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

function BoxSpawningService:SpawnBox(index: number, position: Vector3)
    local boxConfig = self:GetRandomBoxConfig()
    local boxModel: Model = BoxesModels:FindFirstChild(boxConfig.Name)

    if not boxModel then
        print(boxConfig.Name .. " Model not found!")
        return
    end

    local box: Model = boxModel:Clone()
    box.Parent = BoxesFolder
    box.Name = box.Name .. "_" .. tostring(index)
    box:PivotTo(CFrame.new(position))
    self:SetBoxData(index, box, boxConfig)

    return box
end

function BoxSpawningService:SpawnBoxes(amount: number)
    for index = 1, amount do
        local randomPosition = self:GetRandomPointInSpawnArea()
        self:SpawnBox(index, randomPosition)
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

function BoxSpawningService:SetBoxData(index: number, box: Model, boxConfig)
    local boxInfoFrame: Frame = box:WaitForChild(boxConfig.Name):WaitForChild("BillboardGui"):WaitForChild("Frame")

    local boxName: TextLabel = boxInfoFrame:WaitForChild("BoxName")
    boxName.Text = string.gsub(boxConfig.Name, "_", " ")

    local progressText: TextLabel = boxInfoFrame:WaitForChild("HitProgressBar"):WaitForChild("ProgressText")
    progressText.Text = boxConfig.HitPower .. " / " .. boxConfig.HitPower

    box:SetAttribute("Index", index)
    box:SetAttribute("Rarity", boxConfig.Rarity)
    box:SetAttribute("HitPower", boxConfig.HitPower)
    box:SetAttribute("Color", boxConfig.Color)
    self:ToggleBoxInfoFrame(boxInfoFrame, false)

    self:ConnectBoxHitTouch(boxInfoFrame, box:WaitForChild(boxConfig.Name))
end

function BoxSpawningService:ConnectBoxHitTouch(boxInfoFrame: Frame, box: Part)
    box.Parent:SetAttribute("Hit", false)

    box.Touched:Connect(function(otherPart: MeshPart)
        if box.Parent:GetAttribute("Hit") then
            return
        end

        if CollectionService:HasTag(otherPart, "Football") then
            box.Parent:SetAttribute("Hit", true)
            self:ToggleBoxInfoFrame(boxInfoFrame, true)
            local footballHitPower = otherPart:GetAttribute("HitPower")
            local boxIndex = box.Parent:GetAttribute("Index")

            self.BoxDamageService:DealDamage(box, footballHitPower, boxIndex)

            task.wait(2)
            box.Parent:SetAttribute("Hit", false)
            task.wait(8)
            self:ToggleBoxInfoFrame(boxInfoFrame, false)
        end
    end)
end

function BoxSpawningService:ToggleBoxInfoFrame(boxInfoFrame: Frame, toggle: boolean)
    boxInfoFrame.Visible = toggle
end

return BoxSpawningService