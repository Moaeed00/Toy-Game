--!strict
--// File: StarterPlayerScripts/KnitClient/Controllers/BlocksSpawnAreaController.lua
--// BlocksSpawnAreaController.lua
--// FINAL WITH OWNERSHIP:
--// - Show DropButton + hide Backpack ONLY when equipped + inside + NOT owned
--// - Show Backpack + hide DropButton when equipped + inside + IS owned

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("BlocksSpawnAreaConfig"))

local BlocksSpawnAreaController = Knit.CreateController({
	Name = "BlocksSpawnAreaController",
})

--// Local player reference
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui

--// UI References
local dropButtonFrame: Frame? = nil
local dropButton: TextButton? = nil

--// Audio instance
local exitAudio: Sound? = nil

--// State tracking
local isInArea: boolean = false
local isBrainrotEquipped: boolean = false
local ownsEquippedBrainrot: boolean = false

--// Reference to BrainrotCarryService
local BrainrotCarryService = nil

--// ------------------------------
--// Debug print helper
--// ------------------------------
local function dprint(...: any)
	--// Function: dprint
	--// Debug print helper.

	--// IF: debug enabled
	if Config.DEBUG_PRINTS then
		print("[BlocksSpawnAreaController]", ...)
	end
end

--// ------------------------------
--// Set CoreGui Backpack visibility
--// ------------------------------
local function setBackpackVisible(visible: boolean)
	--// Function: setBackpackVisible
	--// Shows/hides the default Roblox Backpack.

	dprint("setBackpackVisible() ->", visible)

	local success, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, visible)
	end)

	--// IF: failed
	if not success then
		warn("[BlocksSpawnAreaController] Failed to set Backpack visibility:", err)
	end
end

--// ------------------------------
--// Play exit audio
--// ------------------------------
local function playExitAudio()
	--// Function: playExitAudio
	--// Plays audio when player exits area with brainrot equipped.

	--// IF: no audio instance
	if not exitAudio then
		dprint("playExitAudio() FAIL -> audio not initialized")
		return
	end

	dprint("Playing exit audio")
	exitAudio:Play()
end

--// ------------------------------
--// Zoom out animation for frame
--// ------------------------------
local function zoomOutFrame(frame: Frame)
	--// Function: zoomOutFrame
	--// Animates frame zooming out (scale 1 -> 0) over ZOOM_OUT_DURATION.

	--// IF: no frame
	if not frame then
		return
	end

	dprint("zoomOutFrame() animating:", frame.Name)

	--// Store original size
	local originalSize = frame.Size

	--// Create tween (scale down to 0)
	local tweenInfo = TweenInfo.new(
		Config.ZOOM_OUT_DURATION,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.In
	)

	local tween = TweenService:Create(frame, tweenInfo, {
		Size = UDim2.new(0, 0, 0, 0)
	})

	tween:Play()

	--// After animation, hide and restore size
	tween.Completed:Connect(function()
		--// Event: tween completed
		frame.Visible = false
		frame.Size = originalSize
		dprint("zoomOutFrame() complete:", frame.Name)
	end)
end

--// ------------------------------
--// Update DropButtonFrame visibility
--// ------------------------------
local function updateDropButtonFrame()
	--// Function: updateDropButtonFrame
	--// Shows DropButtonFrame ONLY when inside area AND equipped AND NOT owned.

	--// IF: no frame
	if not dropButtonFrame then
		dprint("updateDropButtonFrame() FAIL -> frame not found")
		return
	end

	--// [IMPORTANT] Show ONLY when inside + equipped + NOT owned
	local character = localPlayer.Character
	local carryingBrainrotModel = false

	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("IsCarried") == true then
				carryingBrainrotModel = true
				break
			end
		end
	end

	local shouldShow = (isInArea and carryingBrainrotModel)

	dprint("updateDropButtonFrame() -> shouldShow:", shouldShow)
	dprint("  isInArea:", isInArea, "equipped:", isBrainrotEquipped, "owned:", ownsEquippedBrainrot)

	--// IF: should show
	if shouldShow then
		--// [IMPORTANT] Show frame
		if not dropButtonFrame.Visible then
			dropButtonFrame.Visible = true
			dprint("DropButtonFrame SHOWN (not owned)")
		end
	else
		--// [IMPORTANT] Hide frame
		if dropButtonFrame.Visible then
			--// IF: exiting area with non-owned brainrot
			if isBrainrotEquipped and not ownsEquippedBrainrot and not isInArea then
				dprint("DropButtonFrame HIDING with zoom out animation")
				playExitAudio()
				zoomOutFrame(dropButtonFrame)
			else
				--// ELSE: just hide instantly
				dropButtonFrame.Visible = false
				dprint("DropButtonFrame HIDDEN (instant)")
			end
		end
	end
end

--// ------------------------------
--// Update Backpack visibility
--// ------------------------------
local function updateBackpackVisibility()
	--// Function: updateBackpackVisibility
	--// Hides Backpack ONLY when inside area AND equipped AND NOT owned.

	--// [IMPORTANT] Hide ONLY when inside + equipped + NOT owned
	local character = localPlayer.Character
	local carryingBrainrotModel = false

	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("IsCarried") == true then
				carryingBrainrotModel = true
				break
			end
		end
	end

	local shouldHide = (isInArea and carryingBrainrotModel)

	dprint("updateBackpackVisibility() -> shouldHide:", shouldHide)
	dprint("  isInArea:", isInArea, "equipped:", isBrainrotEquipped, "owned:", ownsEquippedBrainrot)

	--// IF: should hide
	if shouldHide then
		--// [IMPORTANT] Hide Backpack (brainrot picked up inside, not owned yet)
		setBackpackVisible(false)
		dprint("Backpack HIDDEN (not owned)")
	else
		--// [IMPORTANT] Show Backpack (owned brainrot OR outside area OR not equipped)
		setBackpackVisible(true)
		dprint("Backpack SHOWN")
	end
end

--// ------------------------------
--// Update all UI
--// ------------------------------
local function updateAllUI()
	--// Function: updateAllUI
	--// Updates both DropButton and Backpack based on current state.

	dprint("updateAllUI() called")
	dprint("  State: isInArea=", isInArea, "equipped=", isBrainrotEquipped, "owned=", ownsEquippedBrainrot)
	
	updateDropButtonFrame()
	updateBackpackVisibility()
end

--// ------------------------------
--// Handle zone change
--// ------------------------------
local function onZoneChanged(newIsInside: boolean)
	--// Function: onZoneChanged
	--// Called when player enters/exits BlocksSpawnArea.

	dprint("onZoneChanged() -> newIsInside:", newIsInside)

	--// [IMPORTANT] Update state
	isInArea = newIsInside

	--// [IMPORTANT] Force check current equipped and ownership state
	isBrainrotEquipped = (localPlayer:GetAttribute("IsBrainrotEquipped") == true)
	ownsEquippedBrainrot = (localPlayer:GetAttribute("OwnsEquippedBrainrot") == true)
	
	dprint("onZoneChanged() -> forced state check:")
	dprint("  equipped:", isBrainrotEquipped, "owned:", ownsEquippedBrainrot)

	--// [IMPORTANT] Update UI immediately
	updateAllUI()
end

--// ------------------------------
--// Handle brainrot equipped state change
--// ------------------------------
local function onBrainrotEquippedChanged()
	--// Function: onBrainrotEquippedChanged
	--// Called when IsBrainrotEquipped attribute changes.

	local newEquipped = (localPlayer:GetAttribute("IsBrainrotEquipped") == true)

	dprint("onBrainrotEquippedChanged() -> newEquipped:", newEquipped)

	--// [IMPORTANT] Update state
	isBrainrotEquipped = newEquipped

	--// [IMPORTANT] Also update ownership
	ownsEquippedBrainrot = (localPlayer:GetAttribute("OwnsEquippedBrainrot") == true)

	--// [IMPORTANT] Update UI
	updateAllUI()
end

--// ------------------------------
--// Handle ownership state change
--// ------------------------------
local function onOwnershipChanged()
	--// Function: onOwnershipChanged
	--// Called when OwnsEquippedBrainrot attribute changes.

	local newOwned = (localPlayer:GetAttribute("OwnsEquippedBrainrot") == true)

	dprint("onOwnershipChanged() -> newOwned:", newOwned)

	--// [IMPORTANT] Update state
	ownsEquippedBrainrot = newOwned

	--// [IMPORTANT] Update UI
	updateAllUI()
end

--// ------------------------------
--// Initialize UI references
--// ------------------------------
function BlocksSpawnAreaController:_initializeUI()
	--// Function: _initializeUI
	--// Finds UI frames in PlayerGui (from StarterGui).

	dprint("_initializeUI() start")

	playerGui = localPlayer:WaitForChild("PlayerGui")

	--// [IMPORTANT] Find DropGui from StarterGui (cloned to PlayerGui)
	local dropGui = playerGui:WaitForChild(Config.DROP_GUI_NAME, 10)

	--// IF: not found
	if not dropGui then
		warn("[BlocksSpawnAreaController] DropGui not found in PlayerGui!")
		warn("[BlocksSpawnAreaController] Expected path: PlayerGui/DropGui")
		warn("[BlocksSpawnAreaController] Make sure DropGui exists in StarterGui")
		return
	end

	dprint("Found DropGui:", dropGui:GetFullName())

	--// [IMPORTANT] Find DropButtonFrame
	dropButtonFrame = dropGui:FindFirstChild(Config.DROP_BUTTON_FRAME_NAME) :: Frame?

	--// IF: not found
	if not dropButtonFrame then
		warn("[BlocksSpawnAreaController] DropButtonFrame not found in DropGui!")
		warn("[BlocksSpawnAreaController] Expected: DropGui/DropButtonFrame")
		return
	end

	dprint("Found DropButtonFrame:", dropButtonFrame:GetFullName())

	--// [IMPORTANT] Find DropButton
	dropButton = dropButtonFrame:FindFirstChild(Config.DROP_BUTTON_NAME) :: TextButton?

	--// IF: not found
	if not dropButton then
		warn("[BlocksSpawnAreaController] DropButton not found in DropButtonFrame!")
		warn("[BlocksSpawnAreaController] Expected: DropGui/DropButtonFrame/DropButton")
		return
	end

	dprint("Found DropButton:", dropButton:GetFullName())

	--// [IMPORTANT] Connect drop button click
	dropButton.MouseButton1Click:Connect(function()
		--// Event: Drop button clicked
		dprint("Drop button clicked -> requesting drop from server")

		--// IF: service available
		if BrainrotCarryService then
			BrainrotCarryService:RequestDrop("DropButtonClicked")
		else
			warn("[BlocksSpawnAreaController] BrainrotCarryService not available!")
		end
	end)

	--// [IMPORTANT] Initially hide DropButtonFrame
	dropButtonFrame.Visible = false

	dprint("_initializeUI() complete ✅")
end

--// ------------------------------
--// Initialize audio
--// ------------------------------
function BlocksSpawnAreaController:_initializeAudio()
	--// Function: _initializeAudio
	--// Creates exit audio instance.

	dprint("_initializeAudio() start")

	exitAudio = Instance.new("Sound")
	exitAudio.Name = "ExitAreaAudio"
	exitAudio.SoundId = Config.EXIT_AUDIO_ID
	exitAudio.Volume = Config.EXIT_AUDIO_VOLUME
	exitAudio.Parent = localPlayer

	dprint("_initializeAudio() complete ✅")
end

--// ------------------------------
--// Connect signals
--// ------------------------------
function BlocksSpawnAreaController:_connectSignals()
	--// Function: _connectSignals
	--// Connects to server signals and attribute changes.

	dprint("_connectSignals() start")

	--// [SIGNAL] ZoneChanged from server
	self.BlocksSpawnAreaService.ZoneChanged:Connect(function(newIsInside: boolean)
		--// Event: ZoneChanged
		dprint("ZoneChanged signal received:", newIsInside)
		onZoneChanged(newIsInside)
	end)

	--// [ATTRIBUTE] IsBrainrotEquipped changed
	localPlayer:GetAttributeChangedSignal("IsBrainrotEquipped"):Connect(function()
		--// Event: IsBrainrotEquipped changed
		onBrainrotEquippedChanged()
	end)

	--// [ATTRIBUTE] OwnsEquippedBrainrot changed (NEW)
	localPlayer:GetAttributeChangedSignal("OwnsEquippedBrainrot"):Connect(function()
		--// Event: OwnsEquippedBrainrot changed
		onOwnershipChanged()
	end)

	--// [ATTRIBUTE] IsInBlocksSpawnArea changed (backup check)
	localPlayer:GetAttributeChangedSignal("IsInBlocksSpawnArea"):Connect(function()
		--// Event: IsInBlocksSpawnArea changed
		local attrInArea = (localPlayer:GetAttribute("IsInBlocksSpawnArea") == true)
		dprint("IsInBlocksSpawnArea attribute changed:", attrInArea)
		
		--// [IMPORTANT] If attribute changed but our state didn't update, force update
		if attrInArea ~= isInArea then
			dprint("Attribute mismatch detected -> forcing zone update")
			onZoneChanged(attrInArea)
		end
	end)

	dprint("_connectSignals() complete ✅")
end

--// ------------------------------
--// Knit Lifecycle: Init
--// ------------------------------
function BlocksSpawnAreaController:KnitInit()
	--// Function: KnitInit
	--// Get service references.

	dprint("KnitInit() start")

	self.BlocksSpawnAreaService = Knit.GetService("BlocksSpawnAreaService")
	dprint("Got BlocksSpawnAreaService:", self.BlocksSpawnAreaService)

	BrainrotCarryService = Knit.GetService("BrainrotCarryService")
	dprint("Got BrainrotCarryService:", BrainrotCarryService)

	dprint("KnitInit() complete")
end

--// ------------------------------
--// Knit Lifecycle: Start
--// ------------------------------
function BlocksSpawnAreaController:KnitStart()
	--// Function: KnitStart
	--// Initialize UI, audio, and connect signals.

	dprint("KnitStart() start")

	self:_initializeUI()
	self:_initializeAudio()
	self:_connectSignals()

	--// [IMPORTANT] Initial state check from attributes
	isInArea = (localPlayer:GetAttribute("IsInBlocksSpawnArea") == true)
	isBrainrotEquipped = (localPlayer:GetAttribute("IsBrainrotEquipped") == true)
	ownsEquippedBrainrot = (localPlayer:GetAttribute("OwnsEquippedBrainrot") == true)

	dprint("Initial state:")
	dprint("  isInArea:", isInArea)
	dprint("  equipped:", isBrainrotEquipped)
	dprint("  owned:", ownsEquippedBrainrot)

	--// [IMPORTANT] Initial UI update
	updateAllUI()

	--// [IMPORTANT] Setup periodic check (backup safety net)
	task.spawn(function()
		while true do
			task.wait(0.5)

			local attrInArea = (localPlayer:GetAttribute("IsInBlocksSpawnArea") == true)
			local attrEquipped = (localPlayer:GetAttribute("IsBrainrotEquipped") == true)
			local attrOwned = (localPlayer:GetAttribute("OwnsEquippedBrainrot") == true)

			--// IF: state mismatch detected
			if attrInArea ~= isInArea or attrEquipped ~= isBrainrotEquipped or attrOwned ~= ownsEquippedBrainrot then
				dprint("Periodic check: State mismatch detected!")
				dprint("  Attributes: inArea=", attrInArea, "equipped=", attrEquipped, "owned=", attrOwned)
				dprint("  Local state: inArea=", isInArea, "equipped=", isBrainrotEquipped, "owned=", ownsEquippedBrainrot)
				
				--// [IMPORTANT] Force sync
				isInArea = attrInArea
				isBrainrotEquipped = attrEquipped
				ownsEquippedBrainrot = attrOwned
				updateAllUI()
			end
		end
	end)

	dprint("KnitStart() complete ✅")
end

return BlocksSpawnAreaController