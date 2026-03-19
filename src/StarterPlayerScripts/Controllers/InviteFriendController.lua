-- [Services]    ----
local PlayerService: Players = game:GetService("Players")
local SocialService: SocialService = game:GetService("SocialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

-- [UI References]		----
local player: Player = PlayerService.LocalPlayer

local canInvite

local InviteFriendController = Knit.CreateController({ Name = "InviteFriendController" })

-- Function to check whether the player can send an invite
local function canSendGameInvite(sendingPlayer)
	local success, canSend = pcall(function()
		return SocialService:CanSendGameInviteAsync(sendingPlayer)
	end)
	return success and canSend
end

function InviteFriendController:SetEnabled()
	if canInvite then
		SocialService:PromptGameInvite(player)
	end
end

function InviteFriendController:KnitInit() end

function InviteFriendController:KnitStart()
	canInvite = canSendGameInvite(player)
end

return InviteFriendController
