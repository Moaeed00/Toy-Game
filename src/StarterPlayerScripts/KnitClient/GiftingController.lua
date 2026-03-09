--!strict
--// File: src/StarterPlayerScripts/KnitClient/Controllers/GiftingController.lua
--// GiftingController.lua
--// 
--// FINAL VERSION - Client creates LOCAL ProximityPrompts
--// 
--// KEY INSIGHT: ProximityPrompts created on CLIENT are ONLY visible to THAT client
--// So we create prompts on other players' HRPs, and they're only visible to us
--// 
--// LOGIC:
--// 1. When LOCAL player equips brainrot -> create prompts on ALL other players
--// 2. When LOCAL player unequips brainrot -> destroy ALL prompts
--// 3. Prompts are NEVER visible to anyone else because they're client-side

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")
local RunService: RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GiftingConfig = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("GiftingConfig"))

local GiftingController = Knit.CreateController({
	Name = "GiftingController",
})

--// Local player reference
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui

--// UI References
local giftingScreenGui: ScreenGui
local giftingUIFrame: Frame
local giftingUIAnswerFrame: Frame

--// GiftingUIFrame elements (shown to RECEIVER)
local acceptOrRejectText: TextLabel
local gifterNameTextReceiver: TextLabel
local acceptButton: TextButton
local rejectButton: TextButton

--// GiftingUIAnswerFrame elements (shown to GIFTER)
local waitingForAnswerText: TextLabel
local gifterNameTextGifter: TextLabel

--// Current gifter (for receiver)
local currentGifter: Player? = nil

--// Prompt storage: [Player] = ProximityPrompt (CLIENT-SIDE ONLY)
local promptsOnPlayers: { [Player]: ProximityPrompt } = {}

--// Character tracking connections
local characterConnections: { [Player]: RBXScriptConnection } = {}

--// Service reference
local GiftingService = nil

--// Is local player currently holding brainrot?
local isLocalHoldingBrainrot: boolean = false

--// ------------------------------
--// Debug print helper
--// ------------------------------
local function dprint(...: any)
	if GiftingConfig.DEBUG_PRINTS then
		print("[GiftingController]", ...)
	end
end

--// ------------------------------
--// Destroy prompt on a specific player
--// ------------------------------
local function destroyPromptOnPlayer(targetPlayer: Player)
	local prompt = promptsOnPlayers[targetPlayer]
	if prompt then
		dprint("Destroying prompt on:", targetPlayer.Name)
		prompt:Destroy()
		promptsOnPlayers[targetPlayer] = nil
	end
end

--// ------------------------------
--// Destroy ALL prompts
--// ------------------------------
local function destroyAllPrompts()
	dprint("destroyAllPrompts() - destroying", #promptsOnPlayers, "prompts")
	
	for targetPlayer, prompt in pairs(promptsOnPlayers) do
		if prompt then
			prompt:Destroy()
		end
	end
	
	promptsOnPlayers = {}
end

--// ------------------------------
--// Create prompt on a specific player (CLIENT-SIDE)
--// ------------------------------
local function createPromptOnPlayer(targetPlayer: Player)
	--// Never create on self
	if targetPlayer == localPlayer then
		return
	end
	
	--// Only create if we're holding brainrot
	if not isLocalHoldingBrainrot then
		return
	end
	
	--// Destroy existing prompt first
	destroyPromptOnPlayer(targetPlayer)
	
	local character = targetPlayer.Character
	if not character then
		dprint("createPromptOnPlayer() - no character for:", targetPlayer.Name)
		return
	end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		dprint("createPromptOnPlayer() - no HRP for:", targetPlayer.Name)
		return
	end
	
	--// Create prompt (CLIENT-SIDE - only visible to this client!)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = GiftingConfig.GIFT_PROMPT_NAME .. "_Local"
	prompt.ActionText = GiftingConfig.GIFT_PROMPT_ACTION_TEXT
	prompt.ObjectText = GiftingConfig.GIFT_PROMPT_OBJECT_TEXT
	prompt.KeyboardKeyCode = GiftingConfig.GIFT_PROMPT_KEYCODE
	prompt.MaxActivationDistance = GiftingConfig.GIFT_PROMPT_MAX_DISTANCE
	prompt.HoldDuration = GiftingConfig.GIFT_PROMPT_HOLD_DURATION
	prompt.RequiresLineOfSight = GiftingConfig.GIFT_PROMPT_REQUIRES_LOS
	prompt.Enabled = true
	prompt.Parent = hrp
	
	promptsOnPlayers[targetPlayer] = prompt
	
	dprint("Created LOCAL prompt on:", targetPlayer.Name)
	
	--// Connect triggered event
	prompt.Triggered:Connect(function(playerWhoTriggered: Player)
		dprint("Prompt triggered by:", playerWhoTriggered.Name, "on:", targetPlayer.Name)
		
		--// Only respond if local player triggered it
		if playerWhoTriggered ~= localPlayer then
			return
		end
		
		--// Double-check we still have brainrot
		if not isLocalHoldingBrainrot then
			dprint("Trigger ignored - no longer holding brainrot")
			return
		end
		
		--// Send gift request to server
		--// localPlayer = GIFTER, targetPlayer = RECEIVER
		dprint("Sending RequestGiftToPlayer to server")
		dprint("  GIFTER:", localPlayer.Name)
		dprint("  RECEIVER:", targetPlayer.Name)
		
		GiftingService:RequestGiftToPlayer(targetPlayer)
	end)
end

--// ------------------------------
--// Create prompts on ALL other players
--// ------------------------------
local function createAllPrompts()
	dprint("createAllPrompts() - creating prompts on all other players")
	
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= localPlayer then
			createPromptOnPlayer(otherPlayer)
		end
	end
end

--// ------------------------------
--// Update prompts based on brainrot state
--// ------------------------------
local function updatePromptsForBrainrotState()
	--// [CRITICAL] Always check the CURRENT attribute value
	local currentlyHolding = (localPlayer:GetAttribute("IsBrainrotEquipped") == true)
	local wasHolding = isLocalHoldingBrainrot
	
	dprint("updatePromptsForBrainrotState()")
	dprint("  wasHolding:", wasHolding)
	dprint("  currentlyHolding:", currentlyHolding)
	dprint("  IsBrainrotEquipped attr:", localPlayer:GetAttribute("IsBrainrotEquipped"))
	
	--// Update our tracking variable
	isLocalHoldingBrainrot = currentlyHolding
	
	if currentlyHolding and not wasHolding then
		--// Just started holding brainrot -> create all prompts
		dprint("Started holding brainrot -> creating prompts")
		createAllPrompts()
	elseif not currentlyHolding and wasHolding then
		--// Just stopped holding brainrot -> destroy all prompts
		dprint("Stopped holding brainrot -> destroying prompts")
		destroyAllPrompts()
	elseif currentlyHolding and wasHolding then
		--// Still holding -> make sure prompts exist
		dprint("Still holding brainrot -> ensuring prompts exist")
		createAllPrompts()
	else
		--// Not holding and wasn't holding -> make sure no prompts
		dprint("Not holding brainrot -> ensuring no prompts")
		destroyAllPrompts()
	end
end

--// ------------------------------
--// Setup tracking for a player
--// ------------------------------
local function setupPlayerTracking(targetPlayer: Player)
	if targetPlayer == localPlayer then
		return
	end
	
	dprint("setupPlayerTracking() for:", targetPlayer.Name)
	
	--// Create prompt if we're holding brainrot and they have a character
	if isLocalHoldingBrainrot and targetPlayer.Character then
		createPromptOnPlayer(targetPlayer)
	end
	
	--// Clean up old connection
	if characterConnections[targetPlayer] then
		characterConnections[targetPlayer]:Disconnect()
	end
	
	--// Track character respawns
	characterConnections[targetPlayer] = targetPlayer.CharacterAdded:Connect(function(character)
		dprint("CharacterAdded for:", targetPlayer.Name)
		
		--// Wait for HRP
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		if hrp and isLocalHoldingBrainrot then
			task.wait(0.1)
			createPromptOnPlayer(targetPlayer)
		end
	end)
end

--// ------------------------------
--// Cleanup tracking for a player
--// ------------------------------
local function cleanupPlayerTracking(targetPlayer: Player)
	dprint("cleanupPlayerTracking() for:", targetPlayer.Name)
	
	destroyPromptOnPlayer(targetPlayer)
	
	if characterConnections[targetPlayer] then
		characterConnections[targetPlayer]:Disconnect()
		characterConnections[targetPlayer] = nil
	end
end

--// ------------------------------
--// Shake animation
--// ------------------------------
local function shakeElement(element: GuiObject)
	local originalPosition = element.Position

	for i = 1, GiftingConfig.SHAKE_COUNT do
		local offsetX = (i % 2 == 0) and GiftingConfig.SHAKE_INTENSITY or -GiftingConfig.SHAKE_INTENSITY

		local tweenInfo = TweenInfo.new(GiftingConfig.SHAKE_SPEED, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(element, tweenInfo, {
			Position = UDim2.new(
				originalPosition.X.Scale,
				originalPosition.X.Offset + offsetX,
				originalPosition.Y.Scale,
				originalPosition.Y.Offset
			)
		})
		tween:Play()
		tween.Completed:Wait()
	end

	local returnTween = TweenService:Create(element, TweenInfo.new(GiftingConfig.SHAKE_SPEED), {
		Position = originalPosition
	})
	returnTween:Play()
	returnTween.Completed:Wait()
end

--// ------------------------------
--// Initialize UI references
--// ------------------------------
function GiftingController:_initializeUI()
	dprint("_initializeUI() start")

	playerGui = localPlayer:WaitForChild("PlayerGui")
	giftingScreenGui = playerGui:WaitForChild("Gifting")

	giftingUIFrame = giftingScreenGui:WaitForChild("GiftingUIFrame")
	acceptOrRejectText = giftingUIFrame:WaitForChild("AcceptOrRejectText")
	gifterNameTextReceiver = giftingUIFrame:WaitForChild("GifterNameText")

	local acceptButtonFrame = giftingUIFrame:WaitForChild("AcceptButtonFrame")
	acceptButton = acceptButtonFrame:WaitForChild("AcceptButton")

	local rejectButtonFrame = giftingUIFrame:WaitForChild("RejectTextButtonFrame")
	rejectButton = rejectButtonFrame:WaitForChild("RejectTextButton")

	giftingUIAnswerFrame = giftingScreenGui:WaitForChild("GiftingUIAnswerFrame")
	waitingForAnswerText = giftingUIAnswerFrame:WaitForChild("WaitingForAnswer")
	gifterNameTextGifter = giftingUIAnswerFrame:WaitForChild("GifterNameText")

	giftingUIFrame.Visible = false
	giftingUIAnswerFrame.Visible = false

	dprint("_initializeUI() complete")
end

--// ------------------------------
--// Connect button events
--// ------------------------------
function GiftingController:_connectButtons()
	dprint("_connectButtons() start")

	acceptButton.MouseButton1Click:Connect(function()
		dprint("Accept button clicked")
		GiftingService:RespondToGift(true)
	end)

	rejectButton.MouseButton1Click:Connect(function()
		dprint("Reject button clicked")
		GiftingService:RespondToGift(false)
		giftingUIFrame.Visible = false
		currentGifter = nil
	end)

	dprint("_connectButtons() complete")
end

--// ------------------------------
--// Show Gift UI (for RECEIVER)
--// ------------------------------
function GiftingController:_showGiftUI(gifter: Player)
	dprint("_showGiftUI() gifter:", gifter.Name)

	currentGifter = gifter
	gifterNameTextReceiver.Text = gifter.Name
	acceptOrRejectText.Text = GiftingConfig.ACCEPT_OR_REJECT_DEFAULT
	giftingUIFrame.Visible = true
end

--// ------------------------------
--// Hide Gift UI (for RECEIVER)
--// ------------------------------
function GiftingController:_hideGiftUI()
	dprint("_hideGiftUI()")
	giftingUIFrame.Visible = false
	currentGifter = nil
end

--// ------------------------------
--// Show Waiting UI (for GIFTER)
--// ------------------------------
function GiftingController:_showWaitingUI(receiver: Player)
	dprint("_showWaitingUI() receiver:", receiver.Name)

	gifterNameTextGifter.Text = receiver.Name
	waitingForAnswerText.Text = GiftingConfig.WAITING_FOR_ANSWER_TEXT
	giftingUIAnswerFrame.Visible = true
end

--// ------------------------------
--// Hide Waiting UI (for GIFTER)
--// ------------------------------
function GiftingController:_hideWaitingUI()
	dprint("_hideWaitingUI()")
	giftingUIAnswerFrame.Visible = false
end

--// ------------------------------
--// Handle Gift Rejected (for GIFTER)
--// ------------------------------
function GiftingController:_handleGiftRejected(receiverName: string)
	dprint("_handleGiftRejected() receiverName:", receiverName)

	waitingForAnswerText.Text = receiverName .. GiftingConfig.GIFT_REJECTED_TEXT

	task.delay(GiftingConfig.REJECTION_MESSAGE_DURATION, function()
		giftingUIAnswerFrame.Visible = false
	end)
end

--// ------------------------------
--// Handle Gift Accepted (for GIFTER)
--// ------------------------------
function GiftingController:_handleGiftAccepted(receiverName: string)
	dprint("_handleGiftAccepted() receiverName:", receiverName)

	waitingForAnswerText.Text = "Your Gift is accepted by:"
	gifterNameTextGifter.Text = receiverName

	task.delay(2, function()
		giftingUIAnswerFrame.Visible = false
	end)
	
	--// [CRITICAL] Force update: we gave away our brainrot
	--// Destroy all prompts immediately since we no longer have brainrot
	dprint("Gift accepted - forcing prompt destruction (gifter no longer has brainrot)")
	isLocalHoldingBrainrot = false
	destroyAllPrompts()
end

--// ------------------------------
--// Handle Inventory Full (for RECEIVER)
--// ------------------------------
function GiftingController:_handleInventoryFull()
	dprint("_handleInventoryFull()")

	acceptOrRejectText.Text = GiftingConfig.INVENTORY_FULL_LINE1
	gifterNameTextReceiver.Text = GiftingConfig.INVENTORY_FULL_LINE2

	task.spawn(function()
		shakeElement(acceptOrRejectText)
	end)

	task.delay(GiftingConfig.INVENTORY_FULL_MESSAGE_DURATION, function()
		if giftingUIFrame.Visible and currentGifter then
			acceptOrRejectText.Text = GiftingConfig.ACCEPT_OR_REJECT_DEFAULT
			gifterNameTextReceiver.Text = currentGifter.Name
		end
	end)
end

--// ------------------------------
--// Connect server signals
--// ------------------------------
function GiftingController:_connectSignals()
	dprint("_connectSignals() start")

	GiftingService.ShowGiftUI:Connect(function(gifter: Player)
		dprint("Signal: ShowGiftUI from:", gifter.Name)
		self:_showGiftUI(gifter)
	end)

	GiftingService.ShowWaitingUI:Connect(function(receiver: Player)
		dprint("Signal: ShowWaitingUI for:", receiver.Name)
		self:_showWaitingUI(receiver)
	end)

	GiftingService.HideGiftUI:Connect(function()
		dprint("Signal: HideGiftUI")
		self:_hideGiftUI()
		
		--// [CRITICAL] When gift UI hides, check if we just RECEIVED a brainrot
		--// Wait a moment for attributes to update, then rebuild prompts
		task.delay(0.5, function()
			dprint("After HideGiftUI - checking brainrot state")
			updatePromptsForBrainrotState()
		end)
	end)

	GiftingService.HideWaitingUI:Connect(function()
		dprint("Signal: HideWaitingUI")
		self:_hideWaitingUI()
	end)

	GiftingService.GiftRejected:Connect(function(receiverName: string)
		dprint("Signal: GiftRejected by:", receiverName)
		self:_handleGiftRejected(receiverName)
	end)

	GiftingService.GiftAccepted:Connect(function(receiverName: string)
		dprint("Signal: GiftAccepted by:", receiverName)
		self:_handleGiftAccepted(receiverName)
	end)

	GiftingService.InventoryFull:Connect(function()
		dprint("Signal: InventoryFull")
		self:_handleInventoryFull()
	end)

	dprint("_connectSignals() complete")
end

--// ------------------------------
--// Setup all player tracking
--// ------------------------------
function GiftingController:_setupAllPlayers()
	dprint("_setupAllPlayers() start")

	--// Track existing players
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayerTracking(player)
	end

	--// Track new players
	Players.PlayerAdded:Connect(function(player)
		dprint("PlayerAdded:", player.Name)
		setupPlayerTracking(player)
	end)

	--// Cleanup leaving players
	Players.PlayerRemoving:Connect(function(player)
		dprint("PlayerRemoving:", player.Name)
		cleanupPlayerTracking(player)
	end)

	dprint("_setupAllPlayers() complete")
end

--// ------------------------------
--// Setup local brainrot tracking
--// ------------------------------
function GiftingController:_setupLocalBrainrotTracking()
	dprint("_setupLocalBrainrotTracking() start")

	--// Listen for IsBrainrotEquipped changes
	localPlayer:GetAttributeChangedSignal("IsBrainrotEquipped"):Connect(function()
		dprint("IsBrainrotEquipped changed")
		updatePromptsForBrainrotState()
	end)

	--// Initial check
	updatePromptsForBrainrotState()

	dprint("_setupLocalBrainrotTracking() complete")
end

--// ------------------------------
--// Knit Lifecycle
--// ------------------------------
function GiftingController:KnitInit()
	dprint("KnitInit() start")

	GiftingService = Knit.GetService("GiftingService")
	dprint("Got GiftingService")

	dprint("KnitInit() complete")
end

function GiftingController:KnitStart()
	dprint("KnitStart() start")

	self:_initializeUI()
	self:_connectButtons()
	self:_connectSignals()
	self:_setupAllPlayers()
	self:_setupLocalBrainrotTracking()

	dprint("KnitStart() complete")
end

return GiftingController