local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlackoutBrainrotsModel: Model = ReplicatedStorage.Assets.SpawnEffectBrainrots:WaitForChild("BlackoutBrainrots")

local Knit = require(ReplicatedStorage.Packages.Knit)

local BrainrotSpawnService = Knit.CreateService {
    Name = "BrainrotSpawnService",
    Client = {},
}

function BrainrotSpawnService:KnitInit()
end

function BrainrotSpawnService:KnitStart()
end

function BrainrotSpawnService:BlackoutBrainrotsSpawn(block: Model)
    local blockPart: MeshPart = block:WaitForChild(block.Name)
    local spawnPoint: Part = blockPart:WaitForChild("MiniBlocksSpawnPoint")
    local blackoutBrainrotsModel = BlackoutBrainrotsModel:Clone()
    blackoutBrainrotsModel:PivotTo(CFrame.new(spawnPoint.CFrame.Position))
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

function BrainrotSpawnService:SpawnRarityBasedBrainrot(block: Model)
    local rarity: string = block:GetAttribute("Rarity")
    print("Rarity: ", rarity)
end

return BrainrotSpawnService