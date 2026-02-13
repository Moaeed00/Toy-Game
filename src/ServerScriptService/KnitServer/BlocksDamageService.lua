local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

    BlocksDamageService.CurrentHitBlockIndex = nil
end

function BlocksDamageService:DealDamage(footballHitPower: number, blockIndex: number)
    if self.CurrentHitBlockIndex ~= blockIndex then
        self.CurrentHitBlockIndex = blockIndex
        print("Now hitting block with index: " .. tostring(blockIndex))
    end

    local hitBlock = self:FindHitBlockByIndex(blockIndex)
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
    task.spawn(function()
        self:PlayDamageVFX(hitBlock)
    end)

    if updatedHitPower <= 0 then
        self:DestroyBlock(hitBlock)
    end
end

function BlocksDamageService:UpdateProgressUI(block: Model, totalHitPower: number, currentHitPower: number)
    local hitProgress: Frame = block:WaitForChild(block.Name):WaitForChild("BillboardGui"):WaitForChild("Frame"):WaitForChild("HitProgressBar")
    local hitProgressBar: Frame = hitProgress:WaitForChild("ProgressBar")
    local hitProgressText: TextLabel = hitProgress:WaitForChild("ProgressText")

    self.GUIService:HandleProgressBar(hitProgressBar, hitProgressText, totalHitPower, currentHitPower)
end

function BlocksDamageService:PlayDamageVFX(block: Model)
    local scaleDown = 0.75
    local scaleUp = 1.0
    local scaleValue = Instance.new("NumberValue")
    scaleValue.Value = 1

    task.spawn(function()
        self:SpawnMiniBlocksEffect(block)
    end)

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
    local minSpawnSizeMultiplier = 0.2
    local maxSpawnSizeMultiplier = 0.3

    local blockPart = block:WaitForChild(block.Name)
    local blockColor = blockPart.Color
    local numBlocks = math.random(SpawnCount[1], SpawnCount[2])

    for i = 1, numBlocks do
        task.spawn(function()
            local miniBlock = Instance.new("Part")
            miniBlock.Shape = Enum.PartType.Block
            miniBlock.Color = blockColor
            miniBlock.Material = blockPart.Material
            miniBlock.Transparency = 0.5
            miniBlock.CastShadow = false
            miniBlock.CanCollide = false
            miniBlock.Anchored = false

            -- Random size using multipliers
            local sizeMultiplier = math.random() * (maxSpawnSizeMultiplier - minSpawnSizeMultiplier) + minSpawnSizeMultiplier
            miniBlock.Size = blockPart.Size * sizeMultiplier

            miniBlock.Position = spawnPoint.Position
            miniBlock.Parent = workspace

            -- Create BodyVelocity for the pop-out effect
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(3000, 5000, 3000)

            -- Random direction (opposite directions on the ground - X and Z plane)
            local angle = (i / numBlocks) * math.pi * 2
            local horizontalSpeed = math.random(10, 20)
            local upwardSpeed = math.random(40, 50)

            bodyVelocity.Velocity = Vector3.new(math.cos(angle) * horizontalSpeed, upwardSpeed, math.sin(angle) * horizontalSpeed)
            bodyVelocity.Parent = miniBlock

            -- Remove BodyVelocity after a short time to let physics take over
            task.delay(0.1, function()
                bodyVelocity:Destroy()
            end)

            -- Wait for block to hit the ground (check if velocity is near zero)
            local startTime = workspace:GetServerTimeNow()
            repeat
                task.wait(0.3)
            until miniBlock.AssemblyLinearVelocity.Magnitude < 1 or workspace:GetServerTimeNow() - startTime > 3

            -- Anchor it when it lands
            miniBlock.CanCollide = true

            local waitTime = math.random(500, 600) / 100
            task.wait(waitTime)

            local scaleValue = Instance.new("NumberValue")
            scaleValue.Value = 1
            local originalSize = miniBlock.Size
            local connection = scaleValue.Changed:Connect(function(value)
                miniBlock.Size = originalSize * value
            end)

            local scaleDownTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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

    self.BlockSpawningService:SpawnBlocks(1)
end

function BlocksDamageService:FindHitBlockByIndex(blockIndex: number)
    for _, block: Model in ipairs(BlocksFolder:GetChildren()) do
        if block:GetAttribute("Index") == blockIndex then
            return block
        end
    end

    return nil
end

function BlocksDamageService:ResetBlockHitPower(block: Model)
    local hitPower = block:GetAttribute("HitPower")
    block:SetAttribute("TotalHitPower", hitPower)
end

return BlocksDamageService