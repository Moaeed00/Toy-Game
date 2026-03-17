local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local LikesService = Knit.CreateService({
	Name = "LikesService",
	Client = {
		OnLikesUpdated = Knit.CreateSignal(),
		OnPromptHide = Knit.CreateSignal(),
	},
})

function LikesService:KnitStart() end

function LikesService:BroadcastLikeUpdate(ownerUserId: number, newCount: number)
	self.Client.OnLikesUpdated:FireAll(ownerUserId, newCount)
end

return LikesService
