local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")

local BlocksFolder: Folder = workspace:WaitForChild("Blocks")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BlocksDamageService = Knit.CreateService {
    Name = "BlocksDamageService",
    Client = {},
}

function BlocksDamageService:KnitInit()
end

function BlocksDamageService:KnitStart()
    BlocksDamageService.GUIService = Knit.GetService("GUIService")
    BlocksDamageService.BlocksSpawningService = Knit.GetService("BlocksSpawningService")

    if not PhysicsService:IsCollisionGroupRegistered("MiniBlocks") then
        PhysicsService:RegisterCollisionGroup("MiniBlocks")
    end
    PhysicsService:CollisionGroupSetCollidable("MiniBlocks", "MiniBlocks", false)

    BlocksDamageService.CurrentHitBlockIndex = nil
end

function BlocksDamageService:DealDamage(footballHitPower: number, blockIndex: number, blockType: string)
    if self.CurrentHitBlockIndex ~= blockIndex then
        self.CurrentHitBlockIndex = blockIndex
        print("Now hitting block with index: " .. tostring(blockIndex))
    end

    local hitBlock = self:FindHitBlockByIndex(blockIndex, blockType)
    if not hitBlock then
        return
    end

    if not hitBlock:GetAttribute("TotalHitPower") then
        local hitPower = hitBlock:GetAttribute("HitPower")
        hitBlock:SetAttribute("TotalHitPower", hitPower)
    end
    local totalHitPower = hitBlock:GetAttribute("TotalHitPower")
    local currentHitPower = hitBlock:GetAttribute("HitPower")
    local updatedHitPower: number = math.max(0, currentHitPower - footballHitPower)
    hitBlock:SetAttribute("HitPower", updatedHitPower)
    self:UpdateProgressUI(hitBlock, totalHitPower, updatedHitPower)

    hitBlock:SetAttribute("Hit", false)

    if updatedHitPower <= 0 then
        self:DestroyBlock(hitBlock)
    end
end

function BlocksDamageService:UpdateProgressUI(block: Model, totalHitPower: number, currentHitPower: number)
    local hitProgress: Frame = block:WaitForChild(block.Name):WaitForChild("BillboardGui"):WaitForChild("Frame"):WaitForChild("HitProgressBar")
    local hitProgressBar: Frame = hitProgress:WaitForChild("ProgressBar")
    local hitProgressText: TextLabel = hitProgress:WaitForChild("ProgressText")

    self:SpawnMiniBlocksEffect(block)
    task.spawn(function()
        self:PlayDamageVFX(block)
    end)
    self.GUIService:HandleProgressBar(hitProgressBar, hitProgressText, totalHitPower, currentHitPower)
end

function BlocksDamageService:PlayDamageVFX(block: Model)
    local scaleUp = block:GetScale()
    local scaleDown = scaleUp * 0.8
    local scaleValue = Instance.new("NumberValue")
    scaleValue.Value = 1

    local connection = scaleValue.Changed:Connect(function(value)
        block:ScaleTo(value)
    end)

    local scaleDownTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    local scaleDownTween = TweenService:Create(scaleValue, scaleDownTweenInfo, { Value = scaleDown })
    scaleDownTween:Play()
    scaleDownTween.Completed:Wait()

    local scaleUpTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local scaleUpTween = TweenService:Create(scaleValue, scaleUpTweenInfo, { Value = scaleUp })
    scaleUpTween:Play()
    scaleUpTween.Completed:Wait()

    connection:Disconnect()
    scaleValue:Destroy()
end

function BlocksDamageService:SpawnMiniBlocksEffect(block: Model)
    local spawnPoint: Part = block:WaitForChild(block.Name):WaitForChild("MiniBlocksSpawnPoint")
    local SpawnCount = { 2, 3 }
    local minSpawnSizeMultiplier = 0.25
    local maxSpawnSizeMultiplier = 0.3

    local blockPart: MeshPart = block:WaitForChild(block.Name)
    local blockColor = Color3.fromHex(block:GetAttribute("Color"))
    local numBlocks = math.random(SpawnCount[1], SpawnCount[2])

    for i = 1, numBlocks do
        task.spawn(function()
            local miniBlock = Instance.new("Part")
            miniBlock.Shape = Enum.PartType.Block
            miniBlock.Color = blockColor
            miniBlock.Material = blockPart.Material
            miniBlock.Transparency = 0.4
            miniBlock.CastShadow = false
            miniBlock.CanCollide = true
            miniBlock.Anchored = false
            miniBlock.CollisionGroup = "MiniBlocks"

            -- Random size using multipliers
            local sizeMultiplier = math.random() * (maxSpawnSizeMultiplier - minSpawnSizeMultiplier) + minSpawnSizeMultiplier
            miniBlock.Size = blockPart.Size * sizeMultiplier
            miniBlock.Position = spawnPoint.Position
            miniBlock.Parent = workspace

            -- Create BodyVelocity for the pop-out effect
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(4000, 5000, 4000)

            -- Random direction (opposite directions on the ground - X and Z plane)
            local angle = (i / numBlocks) * math.pi * 2
            local horizontalSpeed = math.random(10, 20)
            local upwardSpeed = math.random(15, 30)
            bodyVelocity.Velocity = Vector3.new(math.cos(angle) * horizontalSpeed, upwardSpeed, math.sin(angle) * horizontalSpeed)
            bodyVelocity.Parent = miniBlock

            -- Remove BodyVelocity after a short time to let physics take over
            task.delay(0.15, function()
                bodyVelocity:Destroy()
            end)

            -- Wait for block to hit the ground (check if velocity is near zero)
            local startTime = workspace:GetServerTimeNow()
            repeat
                task.wait(0.1)
            until miniBlock.AssemblyLinearVelocity.Magnitude < 1 or workspace:GetServerTimeNow() - startTime > 3
            -- Anchor it when it lands
            miniBlock.Anchored = true

            task.wait(0.25)

            local scaleValue = Instance.new("NumberValue")
            scaleValue.Value = 1
            local originalSize = miniBlock.Size
            local connection = scaleValue.Changed:Connect(function(value)
                miniBlock.Size = originalSize * value
            end)

            local scaleDownTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            local scaleDownTween = TweenService:Create(scaleValue, scaleDownTweenInfo, { Value = 0 })
            scaleDownTween:Play()
            scaleDownTween.Completed:Wait()

            connection:Disconnect()
            scaleValue:Destroy()
            miniBlock:Destroy()
        end)
    end
end

function BlocksDamageService:DestroyBlock(block: Model)
    print("Block destroyed: " .. block.Name)
    self.CurrentHitBlockIndex = nil
    block:Destroy()

    self.BlocksSpawningService:SpawnBlocks(1)
end

function BlocksDamageService:FindHitBlockByIndex(blockIndex: number, blockType: string)
    for _, block: Model in ipairs(BlocksFolder:WaitForChild(blockType):GetChildren()) do
        if block:GetAttribute("Index") == blockIndex then
            return block
        end
    end

    return nil
end

function BlocksDamageService:ResetBlockHitPower(block: Model)
    local totalHitPower = block:GetAttribute("TotalHitPower")
    block:SetAttribute("HitPower", totalHitPower)

    local hitProgress: Frame = block:WaitForChild(block.Name):WaitForChild("BillboardGui"):WaitForChild("Frame"):WaitForChild("HitProgressBar")
    local hitProgressBar: Frame = hitProgress:WaitForChild("ProgressBar")
    local hitProgressText: TextLabel = hitProgress:WaitForChild("ProgressText")
    self.GUIService:HandleProgressBar(hitProgressBar, hitProgressText, totalHitPower, totalHitPower)
end

return BlocksDamageService