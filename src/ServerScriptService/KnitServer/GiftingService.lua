--!strict
--// File: src/ServerScriptService/KnitServer/Services/GiftingService.lua
--// GiftingService.lua
--// Server-authoritative Brainrot Gifting system.
--// 
--// FIXED VERSION: Properly handles tool transfer by:
--// 1. Destroying the old tool
--// 2. Creating a NEW tool for the receiver using BrainrotCarryService

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService: CollectionService = game:GetService("CollectionService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GiftingConfig = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("GiftingConfig"))
local BrainrotConfig = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("BrainrotConfig"))

local GiftingService = Knit.CreateService({
	Name = "GiftingService",

	Client = {
		--// Signals to client
		ShowGiftUI = Knit.CreateSignal(), -- (gifterPlayer: Player)
		ShowWaitingUI = Knit.CreateSignal(), -- (receiverPlayer: Player)
		HideGiftUI = Knit.CreateSignal(), -- ()
		HideWaitingUI = Knit.CreateSignal(), -- ()
		GiftRejected = Knit.CreateSignal(), -- (receiverName: string)
		GiftAccepted = Knit.CreateSignal(), -- (receiverName: string)
		InventoryFull = Knit.CreateSignal(), -- ()

		--// Client -> Server requests
		RequestGiftToPlayer = function() end,
		RespondToGift = function() end,
		CancelGiftRequest = function() end,
	},
})

--// Active gift requests: [gifterUserId] = { receiver: Player, brainrotTool: Tool, timestamp: number }
local activeGiftRequests: { [number]: { receiver: Player, brainrotTool: Tool, timestamp: number } } = {}

--// Reference to BrainrotCarryService
GiftingService.BrainrotCarryService = nil

--// ------------------------------
--// Debug print helper
--// ------------------------------
local function dprint(...: any)
	if GiftingConfig.DEBUG_PRINTS then
		print("[GiftingService]", ...)
	end
end

--// ------------------------------
--// Helper: Get brainrot tool count
--// ------------------------------
local function getBrainrotToolCount(player: Player): number
	local count = 0

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, inst in ipairs(backpack:GetChildren()) do
			if inst:IsA("Tool") and inst:GetAttribute("IsBrainrotTool") == true then
				count += 1
			end
		end
	end

	local character = player.Character
	if character then
		for _, inst in ipairs(character:GetChildren()) do
			if inst:IsA("Tool") and inst:GetAttribute("IsBrainrotTool") == true then
				count += 1
			end
		end
	end

	dprint("getBrainrotToolCount() ->", player.Name, "count =", count)
	return count
end

--// ------------------------------
--// Helper: Get equipped brainrot tool
--// ------------------------------
local function getEquippedBrainrotTool(player: Player): Tool?
	local character = player.Character
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("IsBrainrotTool") == true then
			return child
		end
	end

	return nil
end

--// ------------------------------
--// Helper: Check if player is holding brainrot
--// ------------------------------
local function isHoldingBrainrot(player: Player): boolean
	return getEquippedBrainrotTool(player) ~= nil
end

--// ------------------------------
--// Helper: Get or create brainrot folder
--// ------------------------------
local function getOrCreateBrainrotFolder(): Folder
	local existing = workspace:FindFirstChild(BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME
	folder.Parent = workspace
	return folder
end

--// ------------------------------
--// Handle gift request from client
--// ------------------------------
function GiftingService:_handleGiftRequest(gifter: Player, receiver: Player)
	dprint("_handleGiftRequest() gifter:", gifter.Name, "receiver:", receiver.Name)

	--// [IF] same player
	if gifter == receiver then
		dprint("_handleGiftRequest() FAIL -> same player")
		return
	end

	--// [IF] gifter not holding brainrot
	if not isHoldingBrainrot(gifter) then
		dprint("_handleGiftRequest() FAIL -> gifter not holding brainrot")
		return
	end

	--// [IF] gifter already has active request
	if activeGiftRequests[gifter.UserId] then
		dprint("_handleGiftRequest() FAIL -> gifter already has active request")
		return
	end

	local brainrotTool = getEquippedBrainrotTool(gifter)
	if not brainrotTool then
		dprint("_handleGiftRequest() FAIL -> no brainrot tool found")
		return
	end

	--// [IMPORTANT] Store active request
	activeGiftRequests[gifter.UserId] = {
		receiver = receiver,
		brainrotTool = brainrotTool,
		timestamp = os.clock(),
	}

	dprint("Gift request created:", gifter.Name, "->", receiver.Name)

	--// [IMPORTANT] Show UI to receiver (GiftingUIFrame)
	self.Client.ShowGiftUI:Fire(receiver, gifter)

	--// [IMPORTANT] Show waiting UI to gifter (GiftingUIAnswerFrame)
	self.Client.ShowWaitingUI:Fire(gifter, receiver)

	--// [IMPORTANT] Start timeout
	task.delay(GiftingConfig.GIFT_REQUEST_TIMEOUT, function()
		self:_cancelGiftRequest(gifter, "Timeout")
	end)
end

--// ------------------------------
--// Cancel gift request
--// ------------------------------
function GiftingService:_cancelGiftRequest(gifter: Player, reason: string)
	dprint("_cancelGiftRequest() gifter:", gifter.Name, "reason:", reason)

	local request = activeGiftRequests[gifter.UserId]
	if not request then
		dprint("_cancelGiftRequest() no active request for:", gifter.Name)
		return
	end

	self.Client.HideGiftUI:Fire(request.receiver)
	self.Client.HideWaitingUI:Fire(gifter)

	activeGiftRequests[gifter.UserId] = nil

	dprint("Gift request cancelled:", gifter.Name, "reason:", reason)
end

--// ------------------------------
--// Handle gift response (accept/reject)
--// ------------------------------
function GiftingService:_handleGiftResponse(receiver: Player, accepted: boolean)
	dprint("_handleGiftResponse() receiver:", receiver.Name, "accepted:", accepted)

	--// Find the gift request for this receiver
	local gifterUserId: number? = nil
	local request = nil

	for userId, req in pairs(activeGiftRequests) do
		if req.receiver == receiver then
			gifterUserId = userId
			request = req
			break
		end
	end

	if not gifterUserId or not request then
		dprint("_handleGiftResponse() FAIL -> no request found for receiver:", receiver.Name)
		return
	end

	local gifter = Players:GetPlayerByUserId(gifterUserId)
	if not gifter then
		dprint("_handleGiftResponse() FAIL -> gifter left game")
		activeGiftRequests[gifterUserId] = nil
		self.Client.HideGiftUI:Fire(receiver)
		return
	end

	--// IF: rejected
	if not accepted then
		dprint("Gift REJECTED by:", receiver.Name)

		self.Client.GiftRejected:Fire(gifter, receiver.Name)
		self.Client.HideGiftUI:Fire(receiver)

		activeGiftRequests[gifterUserId] = nil
		return
	end

	--// Check receiver inventory
	local receiverCount = getBrainrotToolCount(receiver)
	if receiverCount >= GiftingConfig.MAX_BRAINROT_INVENTORY then
		dprint("Gift BLOCKED -> receiver inventory full:", receiver.Name, receiverCount)

		self.Client.InventoryFull:Fire(receiver)
		return
	end

	--// Transfer brainrot
	local brainrotTool = request.brainrotTool
	if not brainrotTool or not brainrotTool.Parent then
		dprint("_handleGiftResponse() FAIL -> brainrot tool no longer exists")
		self.Client.HideGiftUI:Fire(receiver)
		self.Client.HideWaitingUI:Fire(gifter)
		activeGiftRequests[gifterUserId] = nil
		return
	end

	local handle = brainrotTool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		dprint("_handleGiftResponse() FAIL -> brainrot tool missing Handle")
		self.Client.HideGiftUI:Fire(receiver)
		self.Client.HideWaitingUI:Fire(gifter)
		activeGiftRequests[gifterUserId] = nil
		return
	end

	--// [IMPORTANT] Store original attributes from handle for recreation
	local brainrotId = handle:GetAttribute("BrainrotId")
	local brainrotWorldName = handle:GetAttribute("BrainrotWorldName") or "Brainrot"

	dprint("Transferring brainrot - ID:", brainrotId, "WorldName:", brainrotWorldName)

	--// ============================================================
	--// CRITICAL FIX: Instead of just moving the tool, we need to:
	--// 1. Drop the brainrot as a world part
	--// 2. Have receiver pick it up (which creates proper connections)
	--// ============================================================

	--// [STEP 1] Force drop the brainrot from gifter using BrainrotCarryService
	if self.BrainrotCarryService then
		dprint("Using BrainrotCarryService to drop brainrot from gifter")
		
		--// Call DropBrainrot to properly release the tool
		self.BrainrotCarryService:DropBrainrot(gifter, "GiftTransfer", nil)
		
		--// Wait for drop to complete
		task.wait(0.1)
		
		--// [STEP 2] Find the dropped brainrot part in workspace
		local brainrotFolder = getOrCreateBrainrotFolder()
		local droppedPart: BasePart? = nil
		
		--// Search by BrainrotId
		for _, child in ipairs(brainrotFolder:GetChildren()) do
			if child:IsA("BasePart") and child:GetAttribute("BrainrotId") == brainrotId then
				droppedPart = child
				dprint("Found dropped brainrot part:", child:GetFullName())
				break
			end
		end
		
		--// [STEP 3] Have receiver pick it up
		if droppedPart then
			dprint("Calling TryPickup for receiver:", receiver.Name)
			self.BrainrotCarryService:TryPickup(receiver, droppedPart)
			
			--// Update gifter attributes
			gifter:SetAttribute("IsBrainrotEquipped", false)
			local gifterRemaining = getBrainrotToolCount(gifter)
			gifter:SetAttribute("IsCarryingBrainrot", gifterRemaining > 0)
			
			dprint("Gift transfer SUCCESS via BrainrotCarryService:", gifter.Name, "->", receiver.Name)
		else
			--// Fallback: if we couldn't find the dropped part, try direct transfer
			dprint("WARNING: Could not find dropped brainrot, attempting direct transfer")
			self:_directTransferFallback(gifter, receiver, brainrotTool, handle, brainrotId, brainrotWorldName)
		end
	else
		--// No BrainrotCarryService, use direct transfer
		dprint("WARNING: BrainrotCarryService not available, using direct transfer")
		self:_directTransferFallback(gifter, receiver, brainrotTool, handle, brainrotId, brainrotWorldName)
	end

	--// Notify both players
	self.Client.GiftAccepted:Fire(gifter, receiver.Name)
	self.Client.HideGiftUI:Fire(receiver)

	activeGiftRequests[gifterUserId] = nil
end

--// ------------------------------
--// Direct transfer fallback (less ideal but works)
--// ------------------------------
function GiftingService:_directTransferFallback(gifter: Player, receiver: Player, brainrotTool: Tool, handle: BasePart, brainrotId: string?, brainrotWorldName: string)
	dprint("_directTransferFallback() starting")
	
	--// Unequip from gifter first
	local gifterChar = gifter.Character
	if gifterChar then
		local hum = gifterChar:FindFirstChildOfClass("Humanoid")
		if hum then
			dprint("Unequipping tool from gifter:", gifter.Name)
			hum:UnequipTools()
		end
	end

	task.wait()

	--// [CRITICAL] Destroy the old tool completely to disconnect old events
	--// Then create a fresh tool for the receiver
	
	--// Store handle properties before destroying
	local handleClone = handle:Clone()
	handleClone.Name = "Handle"
	handleClone:SetAttribute("IsCarried", true)
	handleClone:SetAttribute("CarriedByUserId", receiver.UserId)
	handleClone:SetAttribute("BrainrotId", brainrotId)
	handleClone:SetAttribute("BrainrotWorldName", brainrotWorldName)
	handleClone.Anchored = false
	handleClone.Massless = true
	handleClone.CanCollide = false
	
	--// Remove CollectionService tag from clone temporarily
	pcall(function()
		CollectionService:RemoveTag(handleClone, BrainrotConfig.BRAINROT_TAG_NAME)
	end)
	
	--// Destroy the OLD tool (this disconnects all old Equipped/Unequipped events)
	dprint("Destroying old tool to disconnect events")
	brainrotTool:Destroy()
	
	task.wait()
	
	--// Create a NEW tool for the receiver
	local newTool = Instance.new("Tool")
	newTool.Name = "Brainrot_" .. string.sub(brainrotId or "gift", 1, 6)
	newTool.RequiresHandle = true
	newTool:SetAttribute("IsBrainrotTool", true)
	newTool:SetAttribute("BrainrotId", brainrotId)
	
	--// Parent the cloned handle to new tool
	handleClone.Parent = newTool
	
	--// Move tool to receiver's backpack
	local receiverBackpack = receiver:FindFirstChildOfClass("Backpack")
	if receiverBackpack then
		dprint("Moving new tool to receiver backpack:", receiver.Name)
		newTool.Parent = receiverBackpack
		
		--// [CRITICAL] Connect Equipped/Unequipped for the RECEIVER
		newTool.Equipped:Connect(function()
			dprint("Gifted Brainrot EQUIPPED by:", receiver.Name, newTool.Name)
			receiver:SetAttribute("IsBrainrotEquipped", true)
		end)
		
		newTool.Unequipped:Connect(function()
			dprint("Gifted Brainrot UNEQUIPPED by:", receiver.Name, newTool.Name)
			receiver:SetAttribute("IsBrainrotEquipped", false)
		end)
		
		--// Update gifter attributes
		gifter:SetAttribute("IsBrainrotEquipped", false)
		local gifterRemaining = getBrainrotToolCount(gifter)
		gifter:SetAttribute("IsCarryingBrainrot", gifterRemaining > 0)
		
		--// Update receiver attributes
		receiver:SetAttribute("IsCarryingBrainrot", true)
		
		dprint("Direct transfer complete:", gifter.Name, "->", receiver.Name)
	else
		dprint("_directTransferFallback() FAIL -> receiver has no backpack")
		newTool:Destroy()
	end
end

--// ------------------------------
--// Client Remote Functions
--// ------------------------------
function GiftingService.Client:RequestGiftToPlayer(player: Player, targetPlayer: Player)
	--// player = the one calling (GIFTER)
	--// targetPlayer = the one they want to gift TO (RECEIVER)
	dprint("Client.RequestGiftToPlayer from:", player.Name, "to:", targetPlayer.Name)
	self.Server:_handleGiftRequest(player, targetPlayer)
end

function GiftingService.Client:RespondToGift(player: Player, accepted: boolean)
	dprint("Client.RespondToGift from:", player.Name, "accepted:", accepted)
	self.Server:_handleGiftResponse(player, accepted)
end

function GiftingService.Client:CancelGiftRequest(player: Player)
	dprint("Client.CancelGiftRequest from:", player.Name)
	self.Server:_cancelGiftRequest(player, "GifterCancelled")
end

--// ------------------------------
--// Knit Lifecycle
--// ------------------------------
function GiftingService:KnitInit()
	dprint("KnitInit() start")

	Players.PlayerRemoving:Connect(function(player: Player)
		dprint("PlayerRemoving:", player.Name)

		if activeGiftRequests[player.UserId] then
			self:_cancelGiftRequest(player, "PlayerLeft")
		end

		for userId, request in pairs(activeGiftRequests) do
			if request.receiver == player then
				local gifter = Players:GetPlayerByUserId(userId)
				if gifter then
					self:_cancelGiftRequest(gifter, "ReceiverLeft")
				else
					activeGiftRequests[userId] = nil
				end
			end
		end
	end)

	dprint("KnitInit() complete")
end

function GiftingService:KnitStart()
	dprint("KnitStart() start")

	local ok, serviceOrErr = pcall(function()
		return Knit.GetService("BrainrotCarryService")
	end)

	if ok then
		self.BrainrotCarryService = serviceOrErr
		dprint("Got BrainrotCarryService ✅")
	else
		warn("[GiftingService] BrainrotCarryService not found:", serviceOrErr)
	end

	dprint("KnitStart() complete")
end

return GiftingService