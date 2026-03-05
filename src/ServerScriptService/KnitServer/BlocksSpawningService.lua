local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local BlocksConfig = require(ReplicatedStorage.Configuration.Blocks.BlocksConfig)
local FieldBase: Part = workspace:WaitForChild("Field"):WaitForChild("Base")
local BlocksFolder: Folder = workspace:WaitForChild("Blocks")
local BlockModels = ReplicatedStorage.Assets.Blocks
local BlocksSpawnArea: Part = workspace:WaitForChild("Field"):WaitForChild("BlocksSpawnArea")
local NormalBlocksSpawnArea: Part = BlocksSpawnArea:WaitForChild("NormalBlocksSpawnArea")
local SpecialBlocksSpawnArea: Part = BlocksSpawnArea:WaitForChild("SpecialBlocksSpawnArea")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BlocksSpawningService = Knit.CreateService {
    Name = "BlocksSpawningService",
    Client = {},
}

function BlocksSpawningService:KnitInit()
end

function BlocksSpawningService:KnitStart()
    BlocksSpawningService.BlocksDamageService = Knit.GetService("BlocksDamageService")
    BlocksSpawningService.BrainrotSpawnService = Knit.GetService("BrainrotSpawnService")

    BlocksSpawningService.SpawnedPositions = {}
    BlocksSpawningService.SPECIAL_BLOCKS_MIN_RATIO = 20 -- 20%
    BlocksSpawningService.SPECIAL_BLOCKS_MAX_RATIO = 25 -- 25%
    BlocksSpawningService.MIN_SPAWN_DISTANCE = 10 -- Minimum distance between blocks

    if not PhysicsService:IsCollisionGroupRegistered("Blocks") then
        PhysicsService:RegisterCollisionGroup("Blocks")
    end
    PhysicsService:CollisionGroupSetCollidable("MiniBlocks", "Blocks", false)

    self:SpawnBlocks(150)
end

function BlocksSpawningService:SpawnBlocks(amount: number)
    local specialBlocksCount = math.ceil(amount * math.random(self.SPECIAL_BLOCKS_MIN_RATIO, self.SPECIAL_BLOCKS_MAX_RATIO) / 100)
    local normalBlocksCount = amount - specialBlocksCount

    print("Normal Blocks Count:", normalBlocksCount)
    print("Special Blocks Count:", specialBlocksCount)

    for index = 1, normalBlocksCount do
        local randomPosition = self:GetValidSpawnPosition("Normal")
        if randomPosition then
            self:SpawnBlock(index, randomPosition, "Normal")
            table.insert(self.SpawnedPositions, randomPosition)
        end
    end

    for index = 1, specialBlocksCount do
        local randomPosition = self:GetValidSpawnPosition("Special")
        if randomPosition then
            self:SpawnBlock(index, randomPosition, "Special")
            table.insert(self.SpawnedPositions, randomPosition)
        end
    end
end

function BlocksSpawningService:SpawnBlock(index: number, position: Vector3, blockType: string)
    local blockConfig = self:GetRandomBlockConfig(blockType)
    local blockModel: Model = BlockModels[blockType]:FindFirstChild(blockConfig.Name)

    if not blockModel then
        return
    end

    local block: Model = blockModel:Clone()
    if blockType == "Special" then
        block.Parent = BlocksFolder.Special
    else
        block.Parent = BlocksFolder.Normal
    end
    local finalY = self:GetGroundPositionToPlace(block)
    local finalPosition = Vector3.new(position.X, finalY, position.Z)
    block:PivotTo(CFrame.fromOrientation(0, 0, 0) + finalPosition)
    self:SetBlockData(index, block, blockConfig)
end

function BlocksSpawningService:GetRandomBlockConfig(blockType: string)
    local blocksConfigTable = BlocksConfig[blockType]

    local totalWeight = 0
    for _, blockData in ipairs(blocksConfigTable) do
        totalWeight += blockData.RarityWeight or 0
    end

    local roll = math.random() * totalWeight
    local current = 0

    for _, blockData in ipairs(blocksConfigTable) do
        current += blockData.RarityWeight or 0
        if roll <= current then
            return blockData
        end
    end
end

function BlocksSpawningService:GetGroundPositionToPlace(block: Model): number
    local blockHeight = block:GetExtentsSize().Y
    local groundY = FieldBase.Position.Y + (FieldBase.Size.Y / 2)
    local finalY = groundY + (blockHeight / 2)

    return finalY
end

function BlocksSpawningService:GetValidSpawnPosition(blockType: string): Vector3
    local maxAttempts = 20  -- Prevent infinite loop
    local attempts = 0

    while attempts < maxAttempts do
        attempts += 1
        local randomPosition = self:GetRandomPointInSpawnArea(blockType)
        local isValidPosition = true
        for _, existingPosition in ipairs(self.SpawnedPositions) do
            local distance = (randomPosition - existingPosition).Magnitude
            if distance < self.MIN_SPAWN_DISTANCE then
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

function BlocksSpawningService:GetRandomPointInSpawnArea(blockType: string): Vector3
    if blockType == "Special" then
        local size = SpecialBlocksSpawnArea.Size
        local offset = Vector3.new((math.random() - 0.5) * size.X, 0, (math.random() - 0.5) * size.Z)
        return (SpecialBlocksSpawnArea.CFrame * CFrame.new(offset)).Position
    else
        local size = NormalBlocksSpawnArea.Size
        local offset = Vector3.new((math.random() - 0.5) * size.X, 0, (math.random() - 0.5) * size.Z)
        return (NormalBlocksSpawnArea.CFrame * CFrame.new(offset)).Position
    end
end

function BlocksSpawningService:SetBlockData(index: number, block: Model, blockConfig)
    block:WaitForChild(blockConfig.Name).CollisionGroup = "Blocks"

    local blockInfoFrame: Frame = block:WaitForChild(blockConfig.Name):WaitForChild("BillboardGui"):WaitForChild("Frame")

    local blockName: TextLabel = blockInfoFrame:WaitForChild("BlockName")
    blockName.Text = string.gsub(blockConfig.Name, "_", " ")

    local progressText: TextLabel = blockInfoFrame:WaitForChild("HitProgressBar"):WaitForChild("ProgressText")
    progressText.Text = blockConfig.HitPower .. " / " .. blockConfig.HitPower

    block:SetAttribute("Index", index)
    block:SetAttribute("Rarity", blockConfig.Rarity)
    block:SetAttribute("HitPower", blockConfig.HitPower)
    block:SetAttribute("Color", blockConfig.Color)
    self:ToggleBlockInfoFrame(blockInfoFrame, false)

    self:ConnectBlockHitTouch(blockInfoFrame, block:WaitForChild(blockConfig.Name))
end

function BlocksSpawningService:ConnectBlockHitTouch(blockInfoFrame: Frame, block: Part)
    block.Parent:SetAttribute("Hit", false)
    block.Parent:SetAttribute("LastHitTime", 0)

    block.Touched:Connect(function(otherPart: MeshPart)
        if block.Parent:GetAttribute("Hit") then
            return
        end

        if CollectionService:HasTag(otherPart, "Football") then
            block.Parent:SetAttribute("Hit", true)
            block.Parent:SetAttribute("LastHitTime", workspace:GetServerTimeNow())
            self:ToggleBlockInfoFrame(blockInfoFrame, true)
            local footballHitPower = otherPart:GetAttribute("HitPower")
            local blockIndex = block.Parent:GetAttribute("Index")
            self.BlocksDamageService:DealDamage(footballHitPower, blockIndex, block.Parent.Parent.Name)
        end
    end)

    task.spawn(function()
        self:StartInactivityChecker(block.Parent, blockInfoFrame)
    end)
end

function BlocksSpawningService:StartInactivityChecker(block: Model, blockInfoFrame: Frame)
    local INACTIVITY_TIMEOUT = 10

    while block and block.Parent do
        task.wait(0.5)
        local lastHitTime = block:GetAttribute("LastHitTime") or 0
        local timeSinceLastHit = workspace:GetServerTimeNow() - lastHitTime

        if blockInfoFrame.Visible and timeSinceLastHit >= INACTIVITY_TIMEOUT and lastHitTime > 0 then
            self:ToggleBlockInfoFrame(blockInfoFrame, false)
            self.BlocksDamageService:ResetBlockHitPower(block)
        end
    end
end

function BlocksSpawningService:ToggleBlockInfoFrame(blockInfoFrame: Frame, toggle: boolean)
    blockInfoFrame.Visible = toggle
end

return BlocksSpawningService