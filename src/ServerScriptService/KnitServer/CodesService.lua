local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local CodesData = require(Configuration:WaitForChild("CodesConfiguration"))

local CodesService = Knit.CreateService({
	Name = "CodesService",
	Client = {},
})

function CodesService:KnitStart()
	CodesService.BaseService = Knit.GetService("BaseService")
	CodesService.DataHandlerService = Knit.GetService("DataHandlerService")
end

function CodesService:GetClaimedCodesForPlayer(player)
	local playerData = self.DataHandler:GetPlayerData(player)

	if playerData and typeof(playerData.Codes) == "table" then
		return playerData.Codes
	end

	return {}
end

function CodesService.Client:RedeemCode(player: Player, code: string)
	if typeof(code) ~= "string" or code == "" then
		return false, "Invalid Code"
	end

	local codeInfo = CodesData[code]
	if not codeInfo then
		return false, "Code not found!"
	end

	local claimedCodes = self.Server:GetClaimedCodesForPlayer(player)

	if table.find(claimedCodes, code) then
		return false, "Already Redeemed"
	end

	local brainrotName = "Six Seven"
	local brainrotRarity = "Secret"
	local mutation = "Normal"

	self.BaseService:GiveTool(player, brainrotRarity, brainrotName, mutation)

	table.insert(claimedCodes, code)
	-- DataHandler:UpdateCodes(player, claimedCodes)

	return true, "Reward Claimed!"
end

return CodesService
