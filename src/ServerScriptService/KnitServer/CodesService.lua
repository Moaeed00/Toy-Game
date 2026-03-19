local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local CodesData = require(Configuration:WaitForChild("CodesConfiguration"))

local DataHandler = require(ServerScriptService.KnitServer:WaitForChild("DataHandlerService"))

local CodesService = Knit.CreateService({
	Name = "CodesService",
	Client = {},
})

local function GetClaimedCodesForPlayer(player)
	local playerData = DataHandler:GetPlayerData(player)

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
		return false, "Code not found"
	end

	local claimedCodes = GetClaimedCodesForPlayer(player)

	if table.find(claimedCodes, code) then
		return false, "Already Redeemed"
	end

	-- rewards
	for rewardType, value in pairs(codeInfo.rewards) do
		if rewardType == "coins" then
			DataHandler:UpdateMoney(player, value)
		end
	end

	table.insert(claimedCodes, code)
	-- DataHandler:UpdateCodes(player, claimedCodes)

	return true, "Reward Claimed"
end

return CodesService