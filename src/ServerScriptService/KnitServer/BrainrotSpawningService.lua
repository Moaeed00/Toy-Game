local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlackoutBrainrotsModel: Model = ReplicatedStorage.Assets.SpawnEffectBrainrots:WaitForChild("BlackoutBrainrots")
local BrainrotModels = ReplicatedStorage.Assets:WaitForChild("Brainrots")
local BrainrotsFolder: Folder = workspace:WaitForChild("Brainrots")
local BlockSpawnRarities = require(ReplicatedStorage.Configurations.Blocks.BlockSpawnRarities)
local BrainrotVariantsConfig = require(ReplicatedStorage.Configurations.Brainrots.BrainrotsVariantConfig)
local BrainrotsConfig = require(ReplicatedStorage.Configurations.Brainrots.BrainrotsConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)

local BrainrotSpawnService = Knit.CreateService {
    Name = "BrainrotSpawnService",
    Client = {},
}
local BASE_VARIANT_FOLDER = "Normal"

function BrainrotSpawnService:KnitInit()
end

function BrainrotSpawnService:KnitStart()
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
        OG        = 0.003,
    }

    self:GenerateBrainrotData()
    self:GenerateBrainrotRarityPools()
    self:CacheAllBlockPools()
end

function BrainrotSpawnService:GenerateBrainrotData()
    for index, brainrot in pairs(BrainrotsConfig) do
        self.BrainrotsData[index] = {
            Rarity = brainrot.Rarity,
            -- Image = BrainrotImages[i];
            RarityType = brainrot.RarityType,
            CashPerSecond = brainrot.CashPerSecond,
            SellPrice = brainrot.CashPerSecond * 15,
            FractionChance = self:FormatCommas("1/" .. math.max(1, math.floor(100000000 / brainrot.Rarity * 2))),
            Type = brainrot.Type,
        }
    end
end

function BrainrotSpawnService:GenerateBrainrotRarityPools()
    for brainrotName, data in pairs(self.BrainrotsData) do
        if data.Rarity > 0 then
            local rarity = data.RarityType
            if not self.BrainrotRaritiesPool[rarity] then
                self.BrainrotRaritiesPool[rarity] = {
                    brainrots = {},
                    totalWeight = 0,
                }
            end
            table.insert(self.BrainrotRaritiesPool[rarity].brainrots, {
                name = brainrotName,
                weight = data.Rarity,
            })
            self.BrainrotRaritiesPool[rarity].totalWeight += data.Rarity
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

-- Merge the given rarity pools into a single weighted pool, applying RarityWeightScale
-- so rarities with lower weight are not completely overshadowed by Common's massive Rarity numbers
function BrainrotSpawnService:GenerateCombinedRarityPool(allowedRarities: { any })
    local combined = { brainrots = {}, totalWeight = 0 }
    for _, rarity in ipairs(allowedRarities) do
        local pool = self.BrainrotRaritiesPool[rarity]
        if not pool then
            continue
        end

        local scale = self.RarityWeightScale[rarity]
        for _, brainrot in ipairs(pool.brainrots) do
            local scaledWeight = math.max(1, math.floor(brainrot.weight * scale))
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

function BrainrotSpawnService:AssignCumulativeWeights(brainrots: { any })
    local cumulative = 0
    for _, brainrot in ipairs(brainrots) do
        cumulative += brainrot.weight
        brainrot.cumulativeWeight = cumulative
    end
end

function BrainrotSpawnService:PickBrainrot(pool)
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
    local spawnPoint: Part = blockPart:FindFirstChild("MiniBlocksSpawnPoint")
    if not spawnPoint then
        warn("[BrainrotSpawnService] Block missing MiniBlocksSpawnPoint")
        return
    end

    local selectedBrainrotToSpawn: Model
    if brainrotVariant == BASE_VARIANT_FOLDER then
        selectedBrainrotToSpawn = BrainrotModels:WaitForChild(brainrotVariant):WaitForChild(brainrotName)
    else
        selectedBrainrotToSpawn = BrainrotModels:WaitForChild(brainrotVariant.Prefix:gsub("%s+$", "")):WaitForChild(brainrotVariant.Prefix .. brainrotName)
    end
    local spawnedBrainrot: Model = selectedBrainrotToSpawn:Clone()

    local spawnOffset = spawnedBrainrot:GetAttribute("Offset") or 2.25
    local finalCFrame = CFrame.new(blockPart.Position + Vector3.new(0, spawnOffset, 0)) * CFrame.Angles(math.rad(90), 0, math.rad(-90))
    spawnedBrainrot:PivotTo(finalCFrame)

    spawnedBrainrot.Parent = BrainrotsFolder
    local spawnedBrainrotPart: MeshPart = spawnedBrainrot:FindFirstChildOfClass("MeshPart")
    spawnedBrainrotPart.Transparency = 1

    -- start brainrot idle animation
    local spawnedBrainrotIdleAnimation: Animation = spawnedBrainrot:WaitForChild("Anims"):WaitForChild("Idle")
    local spawnedBrainrotAnimator: Animator = spawnedBrainrot:FindFirstChildOfClass("AnimationController"):FindFirstChildOfClass("Animator")
    local animationTrack: AnimationTrack = spawnedBrainrotAnimator:LoadAnimation(spawnedBrainrotIdleAnimation)
    animationTrack.Looped = true
    animationTrack:AdjustSpeed(1)
    animationTrack:Play()

    spawnedBrainrot:SetAttribute("Name", brainrotName)
    spawnedBrainrot:SetAttribute("RarityType", brainrotData.RarityType)
    spawnedBrainrot:SetAttribute("CashPerSecond", brainrotData.CashPerSecond)
    spawnedBrainrot:SetAttribute("SellPrice", brainrotData.SellPrice)
    spawnedBrainrot:SetAttribute("FractionChance", brainrotData.FractionChance)
    spawnedBrainrot:SetAttribute("Type", brainrotData.Type)

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

    spawnedBrainrot:FindFirstChildOfClass("MeshPart").Transparency = 0
end

function BrainrotSpawnService:FormatCommas(arg: string)
    local prefix, numbers = arg:match("^(.-)(%d+)$")
    if not numbers then
        return
    end
    numbers = numbers:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return prefix .. numbers
end

return BrainrotSpawnService