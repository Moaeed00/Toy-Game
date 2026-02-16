local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlackoutBrainrotsModel: Model = ReplicatedStorage.Assets.SpawnEffectBrainrots:WaitForChild("BlackoutBrainrots")

local Brainrots = require(ReplicatedStorage.Configurations.BrainrotsConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)

local BrainrotSpawnService = Knit.CreateService {
    Name = "BrainrotSpawnService",
    Client = {},
}

function BrainrotSpawnService:KnitInit()
end

function BrainrotSpawnService:KnitStart()
    BrainrotSpawnService.Brainrots = {}

    self:GenerateBrainrotData()
end

function BrainrotSpawnService:GenerateBrainrotData()
    for index, brainrot in pairs(Brainrots) do
        self.Brainrots[index] = {
            Rarity = brainrot.Rarity,
            -- Image = BrainrotImages[i];
            RarityType = brainrot.RarityType,
            CashPerSecond = brainrot.CashPerSecond,
            SellPrice = brainrot.CashPerSecond * 15,
            FractionChance = self:FormatCommas("1/" .. math.max(1, math.floor(100000000 / brainrot.Rarity * 2))),
            Type = brainrot.Type,
        }
    end

    -- print("Total Brainrots: ", self.Brainrots)
end

function BrainrotSpawnService:SpawnRarityBasedBrainrot(block: Model)
    local rarity: string = block:GetAttribute("Rarity")
    print("Rarity: ", rarity)
end

function BrainrotSpawnService:BlackoutBrainrotsSpawn(block: Model)
    local blockPart: MeshPart = block:WaitForChild(block.Name)
    local spawnPoint: Part = blockPart:WaitForChild("MiniBlocksSpawnPoint")
    local blackoutBrainrotsModel = BlackoutBrainrotsModel:Clone()
    blackoutBrainrotsModel:PivotTo(CFrame.new(Vector3.new(spawnPoint.CFrame.Position.X, spawnPoint.CFrame.Position.Y + 2, spawnPoint.CFrame.Position.Z)))
    blackoutBrainrotsModel.Parent = blockPart
end

function BrainrotSpawnService:BlackoutBrainrotsSpawnEffect(block: Model)
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

    self:SpawnRarityBasedBrainrot(block)
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