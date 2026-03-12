local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BrainrotsData = require(ReplicatedStorage.Configuration.Brainrots.EntitiesConfiguration)
local BaseServer = require(ServerScriptService.KnitServer.BaseService)
local AttributesConfiguration = require(ReplicatedStorage.Configuration.AttributesConfiguration)
local getPlayerCharacter = require(ReplicatedStorage.Shared.Utils.getPlayerCharacter)
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)
local Knit = require(ReplicatedStorage.Packages.Knit)

local MerchantService = Knit.CreateService {
    Name = "MerchantService",
    Client = {
        InventoryUpdateEvent = Knit.CreateSignal(),
    },
}

function MerchantService:KnitInit()
end

function MerchantService:KnitStart()
    Players.PlayerAdded:Connect(function(player: Player)
        local backpack = player:WaitForChild("Backpack")

        backpack.ChildAdded:Connect(function()
            self:SyncPlayer(player)
        end)
        backpack.ChildRemoved:Connect(function()
            self:SyncPlayer(player)
        end)
        player.CharacterAdded:Connect(function()
            self:SyncPlayer(player)
        end)

        self:SyncPlayer(player)
    end)
end

function MerchantService:BuildBackpackSnapshot(player: Player)
    local snapshot = {}

    local function scan(container)
        for _, tool: Tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local data = BrainrotsData.Processed[tool.Name]
                if data then
                    local id = tool:GetAttribute("Id")
                    snapshot[tool.Name] = {
                        ID = id,
                        Amount = (snapshot[tool.Name] or 0) + 1,
                    }
                end
            end
        end
    end

    scan(player.Backpack)
    if player.Character then
        scan(player.Character)
    end

    return snapshot
end

function MerchantService:SyncPlayer(player: Player)
	local snapshot = self:BuildBackpackSnapshot(player)
	self.Client.InventoryUpdateEvent:Fire(player, snapshot)
end

function MerchantService.Client:Sell(player: Player, id: string)
    local playerBase, playerProfile = BaseServer:GetPlayerBase(player)
	if not playerBase then
        return
    end

	local toolModel = playerBase:GetToolModelById(id)
	if not toolModel then
        return
    end

    local biomeName = toolModel:GetAttribute(AttributesConfiguration.BIOME)
	local entityName = toolModel:GetAttribute(AttributesConfiguration.ENTITY_NAME)
	local _, entityData = getBiomeByEntity(entityName)

	local price = math.round(entityData.MoneyPerSec * BrainrotsData.Original.SELL_FACTOR)

	toolModel:Destroy()
	playerBase:ReleaseTool(id)
	playerProfile:IncrementValue("Money", price)
    self.Server:SyncPlayer(player)
    return price
end

function MerchantService.Client:SellAll(player: Player)
    local playerBase, playerProfile = BaseServer:GetPlayerBase(player)
	if not playerBase then
        return
    end
	local character = getPlayerCharacter(player)
	if not character then
        return
    end

	local backpack = playerBase:GetBackpack()
	local total = 0

	for id, tool in backpack do
		local toolModel = playerBase:GetToolModelById(id)
		if not toolModel then
            continue
        end

		local biomeName = tool[1]
		local entityName = tool[2]

		local _, entityData = getBiomeByEntity(entityName)
		local price = math.round(entityData.MoneyPerSec * BrainrotsData.Original.SELL_FACTOR)

		total += price
		toolModel:Destroy()
		playerBase:ReleaseTool(id)
	end

	local toolInCharacter = character:FindFirstChildOfClass("Tool")
	if toolInCharacter then
		toolInCharacter:Destroy()
	end

	playerProfile:IncrementValue("Money", total)
    self.Server:SyncPlayer(player)
    return total
end

return MerchantService