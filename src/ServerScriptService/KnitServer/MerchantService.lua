local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BrainrotsData = require(ReplicatedStorage.Configuration.Brainrots.EntitiesConfiguration)
local BaseServer = require(ServerScriptService.KnitServer.BaseService)
local AttributesConfiguration = require(ReplicatedStorage.Configuration.AttributesConfiguration)
local getPlayerCharacter = require(ReplicatedStorage.Shared.Utils.getPlayerCharacter)
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)
local DataHandlerService = require(ServerScriptService.KnitServer.DataHandlerService)
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
        local playerBase = self:WaitForPlayerBase(player)
        if not playerBase then
            return
        end

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

    local backpack = player:FindFirstChild("Backpack")
    if not backpack then
        return snapshot
    end

    local toolsToScan = backpack:GetChildren()

    local character = player.Character
    if character then
        local equipped = character:FindFirstChildOfClass("Tool")
        if equipped then
            table.insert(toolsToScan, equipped)
        end
    end

    for _, tool in ipairs(toolsToScan) do
        if not tool:IsA("Tool") then
            continue
        end

        local entityName = tool:GetAttribute(AttributesConfiguration.ENTITY_NAME)
        local mutationName = tool:GetAttribute(AttributesConfiguration.MUTATION)
        local id = tool:GetAttribute(AttributesConfiguration.ID)

        if not entityName then
            continue
        end

        local data = BrainrotsData.Processed[entityName]
        if not data then
            continue
        end

        if not snapshot[entityName] then
            snapshot[entityName] = {
                ID = id,
                Amount = 0,
                Variant = mutationName,
            }
        end
        snapshot[entityName].Amount += 1
    end

    return snapshot
end

function MerchantService:SyncPlayer(player: Player)
	local snapshot = self:BuildBackpackSnapshot(player)
	self.Client.InventoryUpdateEvent:Fire(player, snapshot)
end

function MerchantService.Client:Sell(player: Player, id: string)
    local playerBase, _playerProfile = BaseServer:GetPlayerBase(player)
	if not playerBase then
        return
    end

	local toolModel = playerBase:GetToolModelById(id)
	if not toolModel then
        return
    end

    local _biomeName = toolModel:GetAttribute(AttributesConfiguration.BIOME)
	local entityName = toolModel:GetAttribute(AttributesConfiguration.ENTITY_NAME)
	local _, entityData = getBiomeByEntity(entityName)

	local price = math.round(entityData.MoneyPerSec * (BrainrotsData.Original.SELL_FACTOR * 100))

	toolModel:Destroy()
	playerBase:ReleaseTool(id)
	DataHandlerService:UpdateMoney(player, price)
    self.Server:SyncPlayer(player)
    return price
end

function MerchantService.Client:SellAll(player: Player)
    local playerBase, _playerProfile = BaseServer:GetPlayerBase(player)
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

		local _biomeName = tool[1]
		local entityName = tool[2]

		local _, entityData = getBiomeByEntity(entityName)
        if not entityData then
            return
        end
		local price = math.round(entityData.MoneyPerSec * (BrainrotsData.Original.SELL_FACTOR * 100))

		total += price
		toolModel:Destroy()
		playerBase:ReleaseTool(id)
	end

	local toolInCharacter = character:FindFirstChildOfClass("Tool")
	if toolInCharacter then
		toolInCharacter:Destroy()
	end

	DataHandlerService:UpdateMoney(player, total)
    self.Server:SyncPlayer(player)
    return total
end

function MerchantService:WaitForPlayerBase(player: Player, timeout: number?)
    local elapsed = 0
    local interval = 0.1
    timeout = timeout or 5

    while elapsed < timeout do
        local playerBase = BaseServer:GetPlayerBase(player)
        if playerBase then
            return playerBase
        end
        task.wait(interval)
        elapsed += interval
    end

    warn("[MerchantService] Timed out waiting for playerBase:", player.Name)
    return nil
end

return MerchantService