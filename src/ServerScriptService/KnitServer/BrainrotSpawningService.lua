local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local BlackoutBrainrotsModel: Model = ReplicatedStorage.Assets.SpawnEffectBrainrots:WaitForChild("BlackoutBrainrots")
local BrainrotModels = ReplicatedStorage.Assets:WaitForChild("Entities")
local BrainrotsFolder: Folder = workspace:WaitForChild("Brainrots")
local TextGradientsFolder: Folder = ReplicatedStorage.Assets.Gradients
local BrainrotGUITemplate: Folder = ReplicatedStorage.Assets.BrainrotInfoGUI
local BlockSpawnRarities = require(ReplicatedStorage.Configuration.Blocks.BlockSpawnRarities)
local BrainrotVariantsConfig = require(ReplicatedStorage.Configuration.Brainrots.BrainrotsVariantConfig)
local BrainrotsData = require(ReplicatedStorage.Configuration.Brainrots.EntitiesConfiguration)
local BrainrotNamesSFXs = ReplicatedStorage.Assets.BrainrotNamesSFX
local Knit = require(ReplicatedStorage.Packages.Knit)

local Sounds = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Sounds")
local SuspenseSFX: Sound = Sounds:FindFirstChild("Spin")
local RevealSFX: Sound = Sounds:FindFirstChild("Reveal")
local CheerSFX: Sound = RevealSFX and RevealSFX:FindFirstChild("Cheering")

local BrainrotSpawnService = Knit.CreateService {
    Name = "BrainrotSpawnService",
    Client = {
        OnBrainrotSpawnEvent = Knit.CreateSignal(),
    },
}

local BASE_VARIANT_FOLDER = "Normal"
local FORCED_VARIANTS = {
    ["Gold"]    = "Gold",
    ["Diamond"] = "Diamond",
    ["Lava"]    = "Lava",
}

function BrainrotSpawnService:KnitInit()
end

function BrainrotSpawnService:KnitStart()
    BrainrotSpawnService.BlocksSpawningService = Knit.GetService("BlocksSpawningService")

    BrainrotSpawnService.BrainrotsData = {}
    BrainrotSpawnService.BrainrotRaritiesPool = {} -- BrainrotRaritiesPool["Common"] = { brainrots={}, totalWeight=0 }
    BrainrotSpawnService.CachedBlockPools = {}
    BrainrotSpawnService.RarityWeightScale = {
        Common    = 1.0,
        Uncommon  = 3.0,
        Rare      = 10.0,
        Epic      = 40.0,
        Legendary = 150.0,
        Mythic    = 500.0,
        Secret    = 2000.0,
        God       = 8000.0,
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
                name   = brainrotName,
                weight = data.CashPerSecond,
            })
            self.BrainrotRaritiesPool[rarity].totalWeight += data.CashPerSecond
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

function BrainrotSpawnService:GenerateCombinedRarityPool(allowedRarities: {})
    local combined = { brainrots = {}, totalWeight = 0 }
    local BASE_WEIGHT = 1_000_000

    for _, rarity in ipairs(allowedRarities) do
        local pool = self.BrainrotRaritiesPool[rarity]
        if not pool or pool.totalWeight == 0 then
            continue
        end

        local rarityScale = self.RarityWeightScale[rarity] or 1.0

        for _, brainrot in ipairs(pool.brainrots) do
            local normalizedWeight = (brainrot.weight / pool.totalWeight) * BASE_WEIGHT
            local scaledWeight = math.max(1, math.floor(normalizedWeight * rarityScale))

            table.insert(combined.brainrots, {
                name   = brainrot.name,
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
    local variants = BrainrotVariantsConfig.VARIANTS
    local totalWeight = 0
    for _, variant in ipairs(variants) do
        totalWeight += variant.Chance
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, variant in ipairs(variants) do
        cumulative += variant.Chance
        if roll <= cumulative then
            return variant.Prefix
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

    local brainrotVariant = FORCED_VARIANTS[blockRarity] or self:PickBrainrotVariant()
    if not brainrotVariant then
        return
    end

    local variantFolder = BrainrotModels:FindFirstChild(brainrotVariant)
    if not variantFolder or not variantFolder:FindFirstChild(brainrotName) then
        brainrotVariant = BASE_VARIANT_FOLDER
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

    local animController = spawnedBrainrot:FindFirstChildOfClass("AnimationController")
    local spawnedBrainrotAnimator = animController and animController:FindFirstChildOfClass("Animator")
    if spawnedBrainrotAnimator and brainrotData.IdleAnimationID then
        local spawnedBrainrotIdleAnimation = Instance.new("Animation")
        spawnedBrainrotIdleAnimation.Parent = spawnedBrainrotAnimator
        spawnedBrainrotIdleAnimation.AnimationId = "rbxassetid://" .. brainrotData.IdleAnimationID
        local animationTrack = spawnedBrainrotAnimator:LoadAnimation(spawnedBrainrotIdleAnimation)
        animationTrack.Looped = true
        animationTrack:AdjustSpeed(1)
        animationTrack:Play()
    else
        warn("[BrainrotSpawnService] No Animator found for '" .. brainrotName .. "', spawning without animation")
    end

    CollectionService:AddTag(spawnedBrainrot, "Brainrot")
    spawnedBrainrot:SetAttribute("Name", brainrotName)
    spawnedBrainrot:SetAttribute("RarityType", brainrotData.RarityType)
    spawnedBrainrot:SetAttribute("CashPerSecond", self:FormatCommas(tostring(brainrotData.CashPerSecond)))
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

function BrainrotSpawnService:BlackoutBrainrotsSpawnEffect(player: Player, block: Model)
    local spawnedBrainrot: Model = self:SpawnRarityBasedBrainrot(block)
    if not spawnedBrainrot then
        warn("[BrainrotSpawnService] Failed to spawn brainrot for block:", block.Name)
        return
    end
    local spawnedBrainrotPart: MeshPart = spawnedBrainrot:FindFirstChildOfClass("MeshPart")

    local BlackoutParts = block:WaitForChild(block.Name):WaitForChild("BlackoutBrainrots"):GetChildren()
    if #BlackoutParts == 0 then
        return
    end

    task.delay(1, function()
        self.Client.OnBrainrotSpawnEvent:Fire(player)
    end)

    if not SuspenseSFX then
        return
    end
    local suspenseSound = SuspenseSFX:Clone()
    suspenseSound.Parent = block
    suspenseSound.Looped = false
    suspenseSound.Volume = 0.25

    local currentPreview
    for i = 1, #BlackoutParts do
        if currentPreview then
            currentPreview.Transparency = 1
        end

        BlackoutParts[i].Transparency = 0
        currentPreview = BlackoutParts[i]

        suspenseSound:Play()
        task.wait(0.06)
    end

    suspenseSound:Stop()
    suspenseSound:Destroy()

    if currentPreview then
        currentPreview.Transparency = 1
    end

    if RevealSFX and CheerSFX then
        local revealSound = RevealSFX:Clone()
        local cheerSound = CheerSFX:Clone()
        revealSound.Parent = player
        cheerSound.Parent = player
        revealSound.Looped = false
        cheerSound.Looped = false
        revealSound.Volume = 0.7
        cheerSound.Volume = 0.2
        revealSound:Play()
		cheerSound:Play()
		self:PlayBrainrotNameSFX(spawnedBrainrot)

        local revealDuration = revealSound.TimeLength
        local fadeTime = 0.25

        task.delay(revealDuration - fadeTime, function()
            local fadeInfo = TweenInfo.new(fadeTime, Enum.EasingStyle.Linear)
            local revealTween = TweenService:Create(revealSound, fadeInfo, {Volume = 0})
            local cheerTween = TweenService:Create(cheerSound, fadeInfo, {Volume = 0})
            revealTween:Play()
            cheerTween:Play()
            revealTween.Completed:Wait()
            revealSound:Stop()
            cheerSound:Stop()

            revealSound:Destroy()
            cheerSound:Destroy()
        end)
    end

    spawnedBrainrotPart.Transparency = 0
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
    brainrotCashText.Text = "$" .. brainrotCash .. "/s"
    brainrotRarityText.Text = brainrotRarity
    brainrotVariantText.Text = brainrotVariant
    brainrotTimerText.Text = brainrotTimer

    brainrotInfoGUI.Enabled = false
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

function BrainrotSpawnService:PlayBrainrotNameSFX(brainrot: Model)
	local brainrotName = brainrot:GetAttribute("Name")
	local brainrotNameSFX: Sound = BrainrotNamesSFXs:FindFirstChild(brainrotName)
	if not brainrotNameSFX then
		return
	end

	brainrotNameSFX = brainrotNameSFX:Clone()
	brainrotNameSFX.Parent = brainrot
	brainrotNameSFX.Looped = false
	brainrotNameSFX.Volume = 0.8
	brainrotNameSFX:Play()

	Debris:AddItem(brainrotNameSFX, brainrotNameSFX.TimeLength + 0.1)
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