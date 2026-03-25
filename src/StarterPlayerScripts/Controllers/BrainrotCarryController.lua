--!strict
-- BrainrotCarryController.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local BrainrotCarryController = Knit.CreateController({
	Name = "BrainrotCarryController",
})

--------------------------------------------------
-- Player
--------------------------------------------------

local LocalPlayer: Player = Players.LocalPlayer

--------------------------------------------------
-- Config
--------------------------------------------------

local DROP_ACTION_NAME = "DropBrainrot"
local DROP_KEY = Enum.KeyCode.E
local DROP_HOLD_DURATION = 0.1

--------------------------------------------------
-- State
--------------------------------------------------

local isCarryingBrainrot = false
local pressStartTime: number? = nil

--------------------------------------------------
-- Services
--------------------------------------------------

local BrainrotCarryService

--------------------------------------------------
-- Debug
--------------------------------------------------

local function dprint(...)
	print("[BrainrotCarryController]", ...)
end

--------------------------------------------------
-- Carry State Changed
--------------------------------------------------

local function onCarryStateChanged(carrying: boolean)

	isCarryingBrainrot = carrying

	dprint("CarryStateChanged ->", carrying)

end

--------------------------------------------------
-- Drop Input Handler
--------------------------------------------------

local function handleDropAction(
	_actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
)

	local player = Players.LocalPlayer

	local carryingModel = player:GetAttribute("IsCarryingBrainrot") == true
	local equippedTool = player:GetAttribute("IsBrainrotEquipped") == true

	-- allow gift prompt when holding tool
	if not carryingModel or equippedTool then
		return Enum.ContextActionResult.Pass
	end

	--------------------------------------------------

	if inputState == Enum.UserInputState.Begin then

		pressStartTime = os.clock()

		return Enum.ContextActionResult.Sink

	end

	--------------------------------------------------

	if inputState == Enum.UserInputState.End then

		if not pressStartTime then
			return Enum.ContextActionResult.Sink
		end

		local heldTime = os.clock() - pressStartTime
		pressStartTime = nil

		if heldTime >= DROP_HOLD_DURATION then

			dprint("RequestDrop")

			if BrainrotCarryService then
				BrainrotCarryService.RequestDropEvent:Fire(LocalPlayer)
			end

		end

		return Enum.ContextActionResult.Sink

	end

	return Enum.ContextActionResult.Sink

end

--------------------------------------------------
-- Knit Init
--------------------------------------------------

function BrainrotCarryController:KnitInit()

	dprint("KnitInit")

	BrainrotCarryService = Knit.GetService("BrainrotCarryService")

	BrainrotCarryService.CarryStateChanged:Connect(function(carrying: boolean)

		onCarryStateChanged(carrying)

	end)

end

--------------------------------------------------
-- Knit Start
--------------------------------------------------

function BrainrotCarryController:KnitStart()

	dprint("KnitStart")

	ContextActionService:BindAction(
		DROP_ACTION_NAME,
		handleDropAction,
		false,
		DROP_KEY
	)

end

return BrainrotCarryController