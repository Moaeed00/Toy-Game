local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)

local LikesService

local LikesController = Knit.CreateController({
	Name = "LikesController",
})

function LikesController:KnitInit()
	LikesService = Knit.GetService("LikesService")
end

function LikesController:KnitStart()
	self._basesFolder = workspace:WaitForChild("Bases")
	self:DisablePrompt() -- Diabsles it for the player's own base
	LikesService.OnLikesUpdated:Connect(function(targetUserId: number, newLikeCount: number)
		self:UpdateLikeDisplay(targetUserId, newLikeCount)
	end)
	LikesService.OnPromptHide:Connect(function(ownerUserId)
		print("Prompt hidden for owner:", ownerUserId)
		self:HidePrompt(ownerUserId)
	end)
end

function LikesController:DisablePrompt()
	local ownBase = self._basesFolder:WaitForChild(tostring(player.UserId), 10)
	if ownBase then
		local prompt = ownBase:WaitForChild("Sign")
			and ownBase.Sign:WaitForChild("Surface")
			and ownBase.Sign.Surface:WaitForChild("LikePrompt")
		if prompt then
			prompt.Enabled = false
		end
	end
end

function LikesController:UpdateLikeDisplay(targetUserId: number, newLikeCount: number)
	local baseModel = self._basesFolder:FindFirstChild(tostring(targetUserId))
	if not baseModel then
		return
	end

	local sign = baseModel:FindFirstChild("Sign")
	if not sign then
		return
	end

	local surface = sign:FindFirstChild("Surface")
	if not surface then
		return
	end

	local surfaceGui = surface:FindFirstChild("SurfaceGui")
	if not surfaceGui then
		return
	end

	local likeDisplay = surfaceGui:FindFirstChild("Frame")
		and surfaceGui.Frame:FindFirstChild("Likes")
		and surfaceGui.Frame.Likes:FindFirstChild("LikeDisplay")

	if likeDisplay then
		likeDisplay.Text = tostring(newLikeCount)
	end
end

function LikesController:HidePrompt(ownerUserId: number)
	local baseModel = self._basesFolder:FindFirstChild(tostring(ownerUserId))
	if not baseModel then
		return
	end

	local prompt = baseModel:FindFirstChild("Sign")
		and baseModel.Sign:FindFirstChild("Surface")
		and baseModel.Sign.Surface:FindFirstChild("LikePrompt")

	if prompt then
		prompt.Enabled = false
	end
end

return LikesController
