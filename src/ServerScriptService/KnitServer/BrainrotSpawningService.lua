local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local BlackoutBrainrotsModel: Model = ReplicatedStorage.Assets.SpawnEffectBrainrots:WaitForChild("BlackoutBrainrots")
local BrainrotModels = ReplicatedStorage.Assets:WaitForChild("Entities")
local BrainrotsFolder: Folder = workspace:WaitForChild("Brainrots")
local TextGradientsFolder: Folder = ReplicatedStorage.Assets.Gradients
local BrainrotGUITemplate: Folder = ReplicatedStorage.Assets.BrainrotInfoGUI
local Camera = workspace.CurrentCamera
local SparkleParticlesAttachment: Attachment = ReplicatedStorage.Assets.CamParticles.Sparkles:WaitForChild("Attachment")
local BlockSpawnRarities = require(ReplicatedStorage.Configuration.Blocks.BlockSpawnRarities)
local BrainrotVariantsConfig = require(ReplicatedStorage.Configuration.Brainrots.BrainrotsVariantConfig)
local BrainrotsData = require(ReplicatedStorage.Configuration.Brainrots.EntitiesConfiguration)
local Knit = require(ReplicatedStorage.Packages.Knit)

local BrainrotSpawnService = Knit.CreateService {
    Name = "BrainrotSpawnService",
    Client = {},
}
local BASE_VARIANT_FOLDER = "Normal"

function BrainrotSpawnService:KnitInit()
end

function BrainrotSpawnService:KnitStart()
    BrainrotSpawnService.BlocksSpawningService = Knit.GetService("BlocksSpawningService")

    BrainrotSpawnService.BrainrotsData = {}
    BrainrotSpawnService.BrainrotRaritiesPool = {} -- BrainrotRaritiesPool["Common"] = { brainrots={}, totalWeight=0 }
    BrainrotSpawnService.CachedBlockPools = {}
    BrainrotSpawnService.RarityWeightScale = {
        Common    = 1.0,
        Uncommon  = 0.8,
        Rare      = 0.5,
        Epic      = 0.3,
        Legendary = 0.15,
        Mythic    = 0.08,
        Secret    = 0.03,
        God       = 0.01,
    }

    self.BrainrotsData = BrainrotsData.Processed
    self:GenerateBrainrotRarityPools()
    self:CacheAllBlockPools()
end

function BrainrotSpawnService:GenerateBrainrotRarityPools()
    for brainrotName, data in pairs(self.BrainrotsData) do
        if data.RarityWeight > 0 then
            local rarity = data.RarityType
            if not self.BrainrotRaritiesPool[rarity] then
                self.BrainrotRaritiesPool[rarity] = {
                    brainrots = {},
                    totalWeight = 0,
                }
            end
            table.insert(self.BrainrotRaritiesPool[rarity].brainrots, {
                name = brainrotName,
                weight = data.RarityWeight,
            })
            self.BrainrotRaritiesPool[rarity].totalWeight += data.RarityWeight
        end
    end

    for _, pool in pairs(self.BrainrotRaritiesPool) do
        table.sort(pool.brainrots, function(a, b)
            return a.weight > b.weight
        end)
        self:AssignCumulativeWeights(pool.brainrots)
    end
end

function BrainrotSpawnService:CacheAllBlockPools()
    for blockRarity, allowedRarities in pairs(BlockSpawnRarities) do
        self.CachedBlockPools[blockRarity] = self:GenerateCombinedRarityPool(allowedRarities)
    end
end

-- Merge the given rarity pools into a single weighted pool, applying RarityWeight
-- so rarities with lower weight are not completely overshadowed by Common's massive Rarity numbers
function BrainrotSpawnService:GenerateCombinedRarityPool(allowedRarities: {})
    local combined = { brainrots = {}, totalWeight = 0 }
    for _, rarity in ipairs(allowedRarities) do
        local pool = self.BrainrotRaritiesPool[rarity]
        if not pool then
            continue
        end

        local rarityWeight = self.RarityWeightScale[rarity]
        for _, brainrot in ipairs(pool.brainrots) do
            local scaledWeight = math.max(1, math.floor(brainrot.weight * rarityWeight))
            table.insert(combined.brainrots, {
                name = brainrot.name,
                weight = scaledWeight,
            })
            combined.totalWeight += scaledWeight
        end
    end

    table.sort(combined.brainrots, function(a, b)
        return a.weight > b.weight
    end)
    self:AssignCumulativeWeights(combined.brainrots)

    return combined
end

function BrainrotSpawnService:AssignCumulativeWeights(brainrots: {})
    local cumulative = 0
    for _, brainrot in ipairs(brainrots) do
        cumulative += brainrot.weight
        brainrot.cumulativeWeight = cumulative
    end
end

function BrainrotSpawnService:PickBrainrot(pool: {})
    if not pool or pool.totalWeight == 0 then
        warn("[BrainrotSpawnService] PickBrainrot called with empty pool")
        return nil
    end

    local roll = math.random(1, pool.totalWeight)
    for _, brainrot in ipairs(pool.brainrots) do
        if roll <= brainrot.cumulativeWeight then
            return brainrot.name
        end
    end
end

function BrainrotSpawnService:PickBrainrotVariant()
    for i = #BrainrotVariantsConfig.VARIANTS, 1, -1 do
        local variant = BrainrotVariantsConfig.VARIANTS[i]
        if math.random() <= variant.Chance then
            return {
                Prefix = variant.Prefix,
                Color = variant.Color,
            }
        end
    end

    return BASE_VARIANT_FOLDER
end

function BrainrotSpawnService:SpawnRarityBasedBrainrot(block: Model)
    local blockRarity: string = block:GetAttribute("Rarity")
    if not blockRarity then
        warn("[BrainrotSpawnService] Block '" .. block.Name .. "' has no Rarity attribute")
        return
    end

    local blockPool = self.CachedBlockPools[blockRarity]
    if not blockPool then
        warn("[BrainrotSpawnService] No cached pool for block rarity: " .. blockRarity)
        return
    end

    local brainrotName = self:PickBrainrot(blockPool)
    if not brainrotName then
        return
    end

    local brainrotData = self.BrainrotsData[brainrotName]

    local brainrotVariant = self:PickBrainrotVariant()
    if not brainrotVariant then
        return
    end

    local blockPart: MeshPart = block:FindFirstChild(block.Name)
    if not blockPart then
        return
    end

    local selectedBrainrotToSpawn: Model = BrainrotModels:WaitForChild(brainrotVariant):WaitForChild(brainrotName)
    local spawnedBrainrot: Model = selectedBrainrotToSpawn:Clone()
    spawnedBrainrot.Parent = BrainrotsFolder

    local spawnPoint: Part = blockPart:WaitForChild("MiniBlocksSpawnPoint")
    local finalCFrame = CFrame.new(Vector3.new(spawnPoint.CFrame.Position.X, spawnPoint.CFrame.Position.Y + 0.5, spawnPoint.CFrame.Position.Z)) * CFrame.Angles(0, math.rad(180), 0)
    spawnedBrainrot:PivotTo(finalCFrame)

    local spawnedBrainrotPart: MeshPart = spawnedBrainrot:FindFirstChildOfClass("MeshPart")
    spawnedBrainrotPart.Transparency = 1

    -- start brainrot idle animation
    local spawnedBrainrotAnimator: Animator = spawnedBrainrot:FindFirstChildOfClass("AnimationController"):FindFirstChildOfClass("Animator")
    local spawnedBrainrotIdleAnimation: Animation = Instance.new("Animation")
    spawnedBrainrotIdleAnimation.Parent = spawnedBrainrotAnimator
    spawnedBrainrotIdleAnimation.AnimationId = "rbxassetid://" .. brainrotData.IdleAnimationID
    local animationTrack: AnimationTrack = spawnedBrainrotAnimator:LoadAnimation(spawnedBrainrotIdleAnimation)
    animationTrack.Looped = true
    animationTrack:AdjustSpeed(1)
    animationTrack:Play()

    CollectionService:AddTag(spawnedBrainrot, "Brainrot")
    spawnedBrainrot:SetAttribute("Name", brainrotName)
    spawnedBrainrot:SetAttribute("RarityType", brainrotData.RarityType)
    spawnedBrainrot:SetAttribute("CashPerSecond", brainrotData.CashPerSecond)
    spawnedBrainrot:SetAttribute("SellPrice", brainrotData.SellPrice)
    spawnedBrainrot:SetAttribute("FractionChance", brainrotData.FractionChance)
    spawnedBrainrot:SetAttribute("Timer", brainrotData.Timer)
    spawnedBrainrot:SetAttribute("Variant", brainrotVariant)

    self:SetupInfoGUI(spawnedBrainrot)

    print(string.format(
        "[BrainrotSpawnService] Spawned '%s' (%s) from %s block | %s CPS | Chance %s",
        brainrotName,
        brainrotData.RarityType,
        blockRarity,
        brainrotData.CashPerSecond,
        brainrotData.FractionChance
    ))

    return spawnedBrainrot
end

function BrainrotSpawnService:BlackoutBrainrotsSpawn(block: Model)
    local blockPart: MeshPart = block:WaitForChild(block.Name)
    local spawnPoint: Part = blockPart:WaitForChild("MiniBlocksSpawnPoint")
    local blackoutBrainrotsModel = BlackoutBrainrotsModel:Clone()
    blackoutBrainrotsModel:PivotTo(CFrame.new(Vector3.new(spawnPoint.CFrame.Position.X, spawnPoint.CFrame.Position.Y + 2, spawnPoint.CFrame.Position.Z)))
    blackoutBrainrotsModel.Parent = blockPart
end

function BrainrotSpawnService:BlackoutBrainrotsSpawnEffect(block: Model)
    local spawnedBrainrot: Model = self:SpawnRarityBasedBrainrot(block)
    local spawnedBrainrotPart: MeshPart = spawnedBrainrot:FindFirstChildOfClass("MeshPart")

    local BlackoutParts = block:WaitForChild(block.Name):WaitForChild("BlackoutBrainrots"):GetChildren()
    if #BlackoutParts == 0 then
        return
    end

    local currentPreview
    for i = 1, #BlackoutParts do
        if currentPreview then
            currentPreview.Transparency = 1
        end

        BlackoutParts[i].Transparency = 0
        currentPreview = BlackoutParts[i]
        task.wait(0.05)
    end
    if currentPreview then
        currentPreview.Transparency = 1
    end

    spawnedBrainrotPart.Transparency = 0
    self:PlayScreenSparkles()
    spawnedBrainrotPart:WaitForChild("InfoGUI").Enabled = true
    self:StartBrainrotTimer(spawnedBrainrot)
end

function BrainrotSpawnService:SetupInfoGUI(brainrot: Model)
    local brainrotInfoGUITemplate: BillboardGui = BrainrotGUITemplate:WaitForChild("InfoGUI")
    local brainrotInfoGUI: BillboardGui = brainrotInfoGUITemplate:Clone()
    brainrotInfoGUI.Parent = brainrot:FindFirstChildOfClass("MeshPart")
    brainrotInfoGUI.StudsOffset = Vector3.new(0, 1, 0)
    local brainrotInfoGUIFrame: Frame = brainrotInfoGUI:WaitForChild("Frame")

    local brainrotName = brainrot:GetAttribute("Name")
    local brainrotCash = brainrot:GetAttribute("CashPerSecond")
    local brainrotRarity = brainrot:GetAttribute("RarityType")
    local brainrotVariant = brainrot:GetAttribute("Variant")
    local brainrotTimer = brainrot:GetAttribute("Timer")

    local brainrotNameText: TextLabel = brainrotInfoGUIFrame:WaitForChild("BrainrotName")
    local brainrotCashText: TextLabel = brainrotInfoGUIFrame:WaitForChild("BrainrotCash")
    local brainrotRarityText: TextLabel = brainrotInfoGUIFrame:WaitForChild("BrainrotRarity")
    local brainrotVariantText: TextLabel = brainrotInfoGUIFrame:WaitForChild("BrainrotVariant")
    local brainrotTimerText: TextLabel = brainrotInfoGUIFrame:WaitForChild("Countdown"):WaitForChild("Timer")
    local RarityTextGradient: UIGradient = TextGradientsFolder:WaitForChild(brainrotRarity)
    RarityTextGradient = RarityTextGradient:Clone()
    RarityTextGradient.Parent = brainrotRarityText

    brainrotNameText.Text = brainrotName
    brainrotCashText.Text = brainrotCash .. "/s"
    brainrotRarityText.Text = brainrotRarity
    brainrotVariantText.Text = brainrotVariant
    brainrotTimerText.Text = brainrotTimer

    brainrotInfoGUI.Enabled = false
end

function BrainrotSpawnService:PlayScreenSparkles()
    local Attachment = Instance.new("Attachment")
    Attachment.Parent = Camera

    for _, Particle: ParticleEmitter in ipairs(SparkleParticlesAttachment:GetChildren()) do
        local Clone = Particle:Clone()
        Clone.Parent = Attachment
        Clone:Emit(math.random(2, 5))
    end
end

function BrainrotSpawnService:StartBrainrotTimer(brainrot: Model)
    local timerValue = tonumber(brainrot:GetAttribute("Timer"))
    if not timerValue then
        return
    end

    local brainrotPart: MeshPart = brainrot:FindFirstChildOfClass("MeshPart")
    if not brainrotPart then
        return
    end

    local infoGUI: BillboardGui = brainrotPart:FindFirstChild("InfoGUI")
    if not infoGUI then
        return
    end
    local timerLabel: TextLabel = infoGUI.Frame.Countdown.Timer

    task.spawn(function()
        local timeLeft = timerValue

        while timeLeft > 0 do
            if brainrot:GetAttribute("Timer") == 0 then
                return
            end
            if brainrot:GetAttribute("TimerPaused") then
                return
            end

            timeLeft = math.max(0, timeLeft - 0.1)

            -- keep 1 decimal precision, incase 24.6 -> 25.0
            timeLeft = math.floor(timeLeft * 10 + 0.5) / 10
            timerLabel.Text = string.format("%.1f", timeLeft) .. "s"

            task.wait(0.1)
        end

        brainrot:Destroy()
        self.BlocksSpawningService:SpawnBlocks(1)
    end)
end

function BrainrotSpawnService:StopBrainrotTimer(brainrot: Model)
    brainrot:SetAttribute("Timer", 0)
end

return BrainrotSpawnService