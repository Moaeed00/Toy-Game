local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoxesConfig = require(ReplicatedStorage.Configurations.BoxesConfig)
local BoxesModels = ReplicatedStorage.Assets.Blocks
local BoxesFolder: Folder = workspace:WaitForChild("Boxes")
local BoxSpawnArea: Part = workspace:WaitForChild("Field"):WaitForChild("BoxSpawnArea")
local FieldBase: Part = workspace:WaitForChild("Field"):WaitForChild("Base")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BoxSpawningService = Knit.CreateService { Name = "BoxSpawningService" }

function BoxSpawningService:KnitInit()
    self.SpawnedPositions = {}
    self.MinSpawnDistance = 10  -- Minimum distance between boxes
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

function BoxSpawningService:SpawnBoxes(amount: number)
    for index = 1, amount do
        local randomPosition = self:GetValidSpawnPosition()
        if randomPosition then
            self:SpawnBox(index, randomPosition)
            table.insert(self.SpawnedPositions, randomPosition)
        else
            warn("Could not find valid spawn position for box " .. index)
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

    local boxHeight = box:GetExtentsSize().Y
    local groundY = FieldBase.Position.Y + (FieldBase.Size.Y / 2)
    local finalY = groundY + (boxHeight / 2)
    local finalPosition = Vector3.new(position.X, finalY, position.Z)
    box:PivotTo(CFrame.fromOrientation(0, 0, 0) + finalPosition)

    self:SetBoxData(index, box, boxConfig)

    return box
end

function BoxSpawningService:GetValidSpawnPosition(): Vector3
    local maxAttempts = 20  -- Prevent infinite loop
    local attempts = 0

    while attempts < maxAttempts do
        attempts += 1
        local randomPosition = self:GetRandomPointInSpawnArea()
        local isValidPosition = true
        for _, existingPosition in ipairs(self.SpawnedPositions) do
            local distance = (randomPosition - existingPosition).Magnitude
            if distance < self.MinSpawnDistance then
                isValidPosition = false
                break
            end
        end

        if isValidPosition then
            return randomPosition
        end
    end

    return nil
end

function BoxSpawningService:GetRandomPointInSpawnArea(): Vector3
    local size = BoxSpawnArea.Size
    local offset = Vector3.new((math.random() - 0.5) * size.X, 0, (math.random() - 0.5) * size.Z)

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
    box.Parent:SetAttribute("LastHitTime", 0)

    box.Touched:Connect(function(otherPart: MeshPart)
        if box.Parent:GetAttribute("Hit") then
            return
        end

        if CollectionService:HasTag(otherPart, "Football") then
            box.Parent:SetAttribute("Hit", true)
            box.Parent:SetAttribute("LastHitTime", tick())
            self:ToggleBoxInfoFrame(boxInfoFrame, true)
            local footballHitPower = otherPart:GetAttribute("HitPower")
            local boxIndex = box.Parent:GetAttribute("Index")

            self.BoxDamageService:DealDamage(footballHitPower, boxIndex)

            task.wait(1)
            box.Parent:SetAttribute("Hit", false)
        end
    end)

    task.spawn(function()
        self:StartInactivityChecker(box.Parent, boxInfoFrame)
    end)
end

function BoxSpawningService:StartInactivityChecker(box: Model, boxInfoFrame: Frame)
    local INACTIVITY_TIMEOUT = 10

    while box and box.Parent do
        task.wait(0.5)
        local lastHitTime = box:GetAttribute("LastHitTime") or 0
        local timeSinceLastHit = tick() - lastHitTime

        if boxInfoFrame.Visible and timeSinceLastHit >= INACTIVITY_TIMEOUT and lastHitTime > 0 then
            self:ToggleBoxInfoFrame(boxInfoFrame, false)
            self.BoxDamageService:ResetBoxHitPower(box)
        end
    end
end

function BoxSpawningService:ToggleBoxInfoFrame(boxInfoFrame: Frame, toggle: boolean)
    boxInfoFrame.Visible = toggle
end

return BoxSpawningService