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

local Knit = require(ReplicatedStorage.Packages.Knit)

local GiftingConfig = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("GiftingConfig"))
local BrainrotConfig = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("BrainrotConfig"))
local AttributesConfiguration = require(ReplicatedStorage.Configuration.AttributesConfiguration)
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)

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
local BaseService = nil

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

	--// ============================================================
	--// CORRECT TRANSFER USING BASESERVICE
	--// ============================================================

	local entity = brainrotTool:GetAttribute(AttributesConfiguration.ENTITY_NAME) or brainrotTool.Name
	local biome = getBiomeByEntity(entity)
	local mutation = brainrotTool:GetAttribute(AttributesConfiguration.MUTATION)
	local entityId = brainrotTool:GetAttribute(AttributesConfiguration.ID)

	print("Gift transfer data:")
	print("entityId:", entityId)
	print("biome:", biome)
	print("entity:", entity)
	print("mutation:", mutation)

	dprint("Gift transfer via BaseService:", gifter.Name, "->", receiver.Name)

	-- release tool from gifter base
	BaseService:ReleaseTool(gifter, entityId)

	-- destroy tool instance
	brainrotTool:Destroy()

	-- give new tool to receiver
	BaseService:GiveTool(receiver, biome, entity, mutation)

	task.wait()

	local backpack = receiver:FindFirstChildOfClass("Backpack")

	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == entity then
				tool:SetAttribute("IsBrainrotTool", true)
				tool:SetAttribute("OwnedByUserId", receiver.UserId)
				break
			end
		end
	end

	gifter:SetAttribute("IsBrainrotEquipped", false)
	receiver:SetAttribute("IsCarryingBrainrot", true)

	dprint("Gift transfer SUCCESS via BaseService")

	--// Notify both players
	self.Client.GiftAccepted:Fire(gifter, receiver.Name)
	self.Client.HideGiftUI:Fire(receiver)

	activeGiftRequests[gifterUserId] = nil
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
--// Ensure brainrot attributes exist after join
--// ------------------------------
function GiftingService:_setupPlayerTools(player: Player)

	local function patchTool(tool: Tool)
		if not tool:IsA("Tool") then return end

		if tool:GetAttribute("IsBrainrotTool") ~= true then
			tool:SetAttribute("IsBrainrotTool", true)
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			patchTool(tool)
		end

		backpack.ChildAdded:Connect(function(tool)
			patchTool(tool)
		end)
	end

	local function onCharacter(character: Model)
		for _, tool in ipairs(character:GetChildren()) do
			patchTool(tool)
		end

		character.ChildAdded:Connect(function(tool)
			patchTool(tool)
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end

	player.CharacterAdded:Connect(onCharacter)

end

--// ------------------------------
--// Knit Lifecycle
--// ------------------------------
function GiftingService:KnitInit()
	dprint("KnitInit() start")

	Players.PlayerAdded:Connect(function(player)
		self:_setupPlayerTools(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_setupPlayerTools(player)
	end

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

	local ok2, baseOrErr = pcall(function()
		return Knit.GetService("BaseService")
	end)

	if ok2 then
		BaseService = baseOrErr
		dprint("Got BaseService ✅")
	else
		warn("[GiftingService] BaseService not found:", baseOrErr)
	end

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