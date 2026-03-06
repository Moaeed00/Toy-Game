--!strict
--// BrainrotCarryController.lua
--// Client controller that ONLY listens to server carry state.
--// IMPORTANT: We do NOT bind E here because ProximityPrompt consumes E.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local BrainrotCarryController = Knit.CreateController({
	Name = "BrainrotCarryController",
})

--// Drop bind (debug)
local DROP_ACTION_NAME = "DropBrainrot_Hold"
local DROP_KEY = Enum.KeyCode.E
local DROP_HOLD_DURATION = 0.1 -- seconds

function BrainrotCarryController:KnitInit()
	--// Function: KnitInit
	--// Get service + connect signals.

	print("[BrainrotCarryController] KnitInit() start")

	self.BrainrotCarryService = Knit.GetService("BrainrotCarryService")
	print("[BrainrotCarryController] Got BrainrotCarryService:", self.BrainrotCarryService)

	self.BrainrotCarryService.CarryStateChanged:Connect(function(isCarrying: boolean, brainrot: Instance?)
		--// Event: carry state changed
		print("[BrainrotCarryController] CarryStateChanged ->", isCarrying, brainrot)

		if isCarrying then
			print("[BrainrotCarryController] ✅ Carry started.")
		else
			print("[BrainrotCarryController] ❌ Carry stopped.")
		end
	end)

	print("[BrainrotCarryController] KnitInit() complete")
end

function BrainrotCarryController:KnitStart()
	--// Function: KnitStart
	--// Bind drop key G.

	print("[BrainrotCarryController] KnitStart() start")
	local keyDownAt: number? = nil

	ContextActionService:BindAction(
		DROP_ACTION_NAME,
		function(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
			--// Event: Drop key input (E)
			--// IMPORTANT: We ONLY handle E when brainrot is equipped, otherwise PASS so ProximityPrompt can use E.

			local isEquipped = (game.Players.LocalPlayer:GetAttribute("IsBrainrotEquipped") == true)

			--// IF: player is NOT equipped with brainrot -> let ProximityPrompt handle E
			if not isEquipped then
				--// [DEBUG] pass-through so pickup prompt works
				--print("[BrainrotCarryController] E pressed but no brainrot equipped -> PASS to pickup prompt")
				return Enum.ContextActionResult.Pass
			end

			--// IF: key begin -> start hold timer
			if inputState == Enum.UserInputState.Begin then
				--// [DEBUG] start hold
				keyDownAt = os.clock()
				print("[BrainrotCarryController] E hold start -> ready to drop (hold", DROP_HOLD_DURATION, "sec)")
				return Enum.ContextActionResult.Sink
			end

			--// IF: key end -> check hold duration
			if inputState == Enum.UserInputState.End then
				--// [IF] no start time
				if not keyDownAt then
					return Enum.ContextActionResult.Sink
				end

				local heldFor = os.clock() - keyDownAt
				keyDownAt = nil

				print("[BrainrotCarryController] E hold end -> heldFor:", heldFor)

				--// IF: held long enough -> request drop
				if heldFor >= DROP_HOLD_DURATION then
					print("[BrainrotCarryController] ✅ Hold met -> RequestDrop()")
					self.BrainrotCarryService:RequestDrop("ClientHoldDropKey_E")
				else
					print("[BrainrotCarryController] ❌ Hold too short -> no drop")
				end

				return Enum.ContextActionResult.Sink
			end

			return Enum.ContextActionResult.Sink
		end,
		false,
		DROP_KEY
	)


	print("[BrainrotCarryController] KnitStart() complete (Drop key =", DROP_KEY.Name, ")")
end

return BrainrotCarryController
