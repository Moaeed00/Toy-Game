-- ServerScriptService/KnitServer/Services/PointsPartRewardService (ModuleScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local PointsPartRewardService = Knit.CreateService({
	Name = "PointsPartRewardService",
	Client = {},
})

local DataHandlerService
local touchCooldownByUserId: { [number]: number } = {}
local COOLDOWN = 0.6

local function getPlayerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

local function hookPointsPart(part: BasePart)
	if not part:IsA("BasePart") then return end
	if part.Name ~= "PointsPart" then return end

	part.Touched:Connect(function(hit)
		local plr = getPlayerFromHit(hit)
		if not plr then return end

		local now = os.clock()
		local last = touchCooldownByUserId[plr.UserId] or 0
		if (now - last) < COOLDOWN then return end
		touchCooldownByUserId[plr.UserId] = now

		-- Reward can be set via Attribute "Reward" on PointsPart (optional)
		local amount = part:GetAttribute("Reward")
		if typeof(amount) ~= "number" then
			amount = 1
		end

		DataHandlerService:UpdatePoints(plr, amount)
	end)
end

function PointsPartRewardService:KnitInit()
	DataHandlerService = Knit.GetService("DataHandlerService")
end

function PointsPartRewardService:KnitStart()
	-- hook existing
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name == "PointsPart" then
			hookPointsPart(inst)
		end
	end

	-- hook future
	workspace.DescendantAdded:Connect(function(inst)
		if inst:IsA("BasePart") and inst.Name == "PointsPart" then
			hookPointsPart(inst)
		end
	end)
end

return PointsPartRewardService
