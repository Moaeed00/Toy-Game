local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotsData = require(ReplicatedStorage.Configuration.Brainrots.BrainrotsConfig)
local DataStoreHandler = require(script.Parent.DataHandlerService)
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
        local function hook(container)
            container.ChildAdded:Connect(function()
                self:SyncPlayer(player)
            end)

            container.ChildRemoved:Connect(function()
                self:SyncPlayer(player)
            end)
        end

        hook(player:WaitForChild("Backpack"))
        player.CharacterAdded:Connect(function(character)
            hook(character)
            self:SyncPlayer(player)
        end)

        self:SyncPlayer(player)
    end)
end

function MerchantService:BuildBackpackSnapshot(player: Player)
    local snapshot = {}

    local function scan(container)
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local data = BrainrotsData[tool.Name]
                if data then
                    snapshot[tool.Name] = (snapshot[tool.Name] or 0) + 1
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

function MerchantService.Client:Sell(player: Player, itemName: string)
	local data = BrainrotsData[itemName]
	if not data then
        return
    end

    local toolToRemove: Tool
    local backpack = player.Backpack
    for _, tool: Tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name == itemName then
            toolToRemove = tool
        end
    end

    if not toolToRemove then
        return
    end
    toolToRemove:Destroy()

	local reward = data.SellPrice
    DataStoreHandler:SetCoins(player, reward)
    self.Server:SyncPlayer(player)
    return reward
end

function MerchantService.Client:SellAll(player: Player)
	local totalUpdatedCoins = 0
    local toolsToRemove = {}
    local backpack = player.Backpack
	for _, tool: Tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local data = BrainrotsData[tool.Name]
            if data then
                totalUpdatedCoins += data.SellPrice
                table.insert(toolsToRemove, tool)
            end
        end
	end

    for _, tool: Tool in ipairs(toolsToRemove) do
        tool:Destroy()
    end

	DataStoreHandler:SetCoins(player, totalUpdatedCoins)
    self.Server:SyncPlayer(player)
    return totalUpdatedCoins
end

return MerchantService