--!strict
-- GiftingController.lua
-- Client-side gifting prompt controller

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GiftingConfig = require(
	ReplicatedStorage.Configuration.GiftingConfig
)

local localPlayer = Players.LocalPlayer

local GiftingController = Knit.CreateController({
	Name = "GiftingController",
})

local GiftingService

--------------------------------------------------
-- prompt storage
--------------------------------------------------

local prompts : {[Player] : ProximityPrompt} = {}

local isHoldingBrainrot = false

--------------------------------------------------
-- destroy prompt
--------------------------------------------------

local function destroyPrompt(target : Player)

	local prompt = prompts[target]

	if prompt then
		prompt:Destroy()
		prompts[target] = nil
	end

end

--------------------------------------------------
-- destroy all prompts
--------------------------------------------------

local function destroyAllPrompts()

	for player, prompt in pairs(prompts) do
		if prompt then
			prompt:Destroy()
		end
	end

	table.clear(prompts)

end

--------------------------------------------------
-- create prompt
--------------------------------------------------

local function createPrompt(target : Player)

	if target == localPlayer then
		return
	end

	if not isHoldingBrainrot then
		return
	end

	local char = target.Character
	if not char then
		return
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")

	if not hrp then
		return
	end

	destroyPrompt(target)

	local prompt = Instance.new("ProximityPrompt")

	prompt.Name = "GiftBrainrotPrompt_Local"
	prompt.ActionText = GiftingConfig.GIFT_PROMPT_ACTION_TEXT
	prompt.ObjectText = target.Name
	prompt.KeyboardKeyCode = GiftingConfig.GIFT_PROMPT_KEYCODE
	prompt.HoldDuration = GiftingConfig.GIFT_PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = GiftingConfig.GIFT_PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = GiftingConfig.GIFT_PROMPT_REQUIRES_LOS
	prompt.Enabled = true

	prompt.Parent = hrp

	prompts[target] = prompt

	prompt.Triggered:Connect(function(player)

		if player ~= localPlayer then
			return
		end

		if not isHoldingBrainrot then
			return
		end

		GiftingService:RequestGiftToPlayer(target)

	end)

end

--------------------------------------------------
-- rebuild prompts
--------------------------------------------------

local function rebuildPrompts()

	destroyAllPrompts()

	if not isHoldingBrainrot then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do

		if player ~= localPlayer then
			createPrompt(player)
		end

	end

end

--------------------------------------------------
-- track players
--------------------------------------------------

local function setupPlayer(player : Player)

	if player == localPlayer then
		return
	end

	if player.Character then
		createPrompt(player)
	end

	player.CharacterAdded:Connect(function()

		task.wait(0.2)

		createPrompt(player)

	end)

end

--------------------------------------------------
-- brainrot equip tracking
--------------------------------------------------

local function updateBrainrotState()

	local equipped = (localPlayer:GetAttribute("IsBrainrotEquipped") == true)

	if equipped == isHoldingBrainrot then
		return
	end

	isHoldingBrainrot = equipped

	rebuildPrompts()

end

--------------------------------------------------
-- UI (existing logic preserved)
--------------------------------------------------

function GiftingController:_connectSignals()

	GiftingService.ShowGiftUI:Connect(function(gifter)

		local gui = localPlayer.PlayerGui.Gifting.GiftingUIFrame
		gui.Visible = true
		gui.GifterNameText.Text = gifter.Name

	end)

	GiftingService.HideGiftUI:Connect(function()

		local gui = localPlayer.PlayerGui.Gifting.GiftingUIFrame
		gui.Visible = false

	end)

	GiftingService.ShowWaitingUI:Connect(function(receiver)

		local gui = localPlayer.PlayerGui.Gifting.GiftingUIAnswerFrame
		gui.Visible = true
		gui.GifterNameText.Text = receiver.Name

	end)

	GiftingService.HideWaitingUI:Connect(function()

		local gui = localPlayer.PlayerGui.Gifting.GiftingUIAnswerFrame
		gui.Visible = false

	end)

	GiftingService.GiftRejected:Connect(function(receiverName)

		local gui = localPlayer.PlayerGui.Gifting.GiftingUIAnswerFrame

		gui.WaitingForAnswer.Text = receiverName .. " rejected your gift"

		task.delay(GiftingConfig.REJECTION_MESSAGE_DURATION, function()

			if gui then
				gui.Visible = false
			end

		end)

	end)

	GiftingService.GiftAccepted:Connect(function(receiverName)

		local gui = localPlayer.PlayerGui.Gifting.GiftingUIAnswerFrame

		gui.WaitingForAnswer.Text = "Your gift was accepted by:"
		gui.GifterNameText.Text = receiverName
		gui.Visible = true

		task.delay(2, function()

			if gui then
				gui.Visible = false
			end

		end)

		-- destroy prompts since brainrot was given away
		destroyAllPrompts()
		isHoldingBrainrot = false

	end)

end

function GiftingController:_connectButtons()

	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local giftingScreenGui = playerGui:WaitForChild("Gifting")

	local giftingUIFrame = giftingScreenGui:WaitForChild("GiftingUIFrame")

	local acceptButton =
		giftingUIFrame
		:WaitForChild("AcceptButtonFrame")
		:WaitForChild("AcceptButton")

	local rejectButton =
		giftingUIFrame
		:WaitForChild("RejectTextButtonFrame")
		:WaitForChild("RejectTextButton")

	------------------------------------------------
	-- ACCEPT
	------------------------------------------------

	acceptButton.MouseButton1Click:Connect(function()

		GiftingService:RespondToGift(true)

	end)

	------------------------------------------------
	-- REJECT
	------------------------------------------------

	rejectButton.MouseButton1Click:Connect(function()

		GiftingService:RespondToGift(false)

		local gui = localPlayer.PlayerGui.Gifting.GiftingUIFrame
		gui.Visible = false

	end)

end

--------------------------------------------------
-- knit lifecycle
--------------------------------------------------

function GiftingController:KnitInit()

	GiftingService = Knit.GetService("GiftingService")

end

function GiftingController:KnitStart()

	------------------------------------------------
	-- track players
	------------------------------------------------

	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	Players.PlayerAdded:Connect(setupPlayer)

	Players.PlayerRemoving:Connect(function(player)
		destroyPrompt(player)
	end)

	------------------------------------------------
	-- brainrot equip tracking
	------------------------------------------------

	localPlayer:GetAttributeChangedSignal(
		"IsBrainrotEquipped"
	):Connect(updateBrainrotState)

	updateBrainrotState()

	------------------------------------------------
	-- ui signals
	------------------------------------------------

	self:_connectSignals()
	self:_connectButtons()

end

return GiftingController