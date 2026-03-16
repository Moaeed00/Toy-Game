--!strict
-- BlocksSpawnAreaController.lua
-- Handles Drop UI + Backpack visibility for Brainrot system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(
	ReplicatedStorage.Configuration.BlocksSpawnAreaConfig
)

local BlocksSpawnAreaController = Knit.CreateController({
	Name = "BlocksSpawnAreaController",
})

--------------------------------------------------
-- Player
--------------------------------------------------

local LocalPlayer: Player = Players.LocalPlayer
local PlayerGui: PlayerGui

--------------------------------------------------
-- UI
--------------------------------------------------

local DropButtonFrame: Frame?
local DropButton: TextButton?

--------------------------------------------------
-- State
--------------------------------------------------

local isInArea = false
local isCarryingBrainrot = false

--------------------------------------------------
-- Services
--------------------------------------------------

local BrainrotCarryService
local BlocksSpawnAreaService

--------------------------------------------------
-- Audio
--------------------------------------------------

local ExitAudio: Sound?

--------------------------------------------------
-- Debug
--------------------------------------------------

local function dprint(...)

	if Config.DEBUG_PRINTS then
		print("[BlocksSpawnAreaController]", ...)
	end

end

--------------------------------------------------
-- Backpack Visibility
--------------------------------------------------

local function setBackpackVisible(visible: boolean)

	local ok, err = pcall(function()

		StarterGui:SetCoreGuiEnabled(
			Enum.CoreGuiType.Backpack,
			visible
		)

	end)

	if not ok then
		warn("[BlocksSpawnAreaController]", err)
	end

end

--------------------------------------------------
-- UI Animation
--------------------------------------------------

local function zoomOutFrame(frame: Frame)

	local originalSize = frame.Size

	local tweenInfo = TweenInfo.new(
		Config.ZOOM_OUT_DURATION,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.In
	)

	local tween = TweenService:Create(frame,tweenInfo,{
		Size = UDim2.new(0,0,0,0)
	})

	tween:Play()

	tween.Completed:Connect(function()

		frame.Visible = false
		frame.Size = originalSize

	end)

end

--------------------------------------------------
-- Drop UI Logic
--------------------------------------------------

local function updateDropUI()

	if not DropButtonFrame then return end

	local shouldShow = (isInArea and isCarryingBrainrot)

	if shouldShow then

		if not DropButtonFrame.Visible then
			dprint("Show Drop UI")
			DropButtonFrame.Visible = true
		end

	else

		if DropButtonFrame.Visible then

			if not isInArea then
				zoomOutFrame(DropButtonFrame)
			else
				DropButtonFrame.Visible = false
			end

		end

	end

end

--------------------------------------------------
-- Backpack Logic
--------------------------------------------------

local function updateBackpack()

	local shouldHide = (isInArea and isCarryingBrainrot)

	if shouldHide then
		setBackpackVisible(false)
	else
		setBackpackVisible(true)
	end

end

--------------------------------------------------
-- Update All UI
--------------------------------------------------

local function updateAll()

	updateDropUI()
	updateBackpack()

end

--------------------------------------------------
-- Zone Changed
--------------------------------------------------

local function onZoneChanged(newIsInside: boolean)

	dprint("ZoneChanged:", newIsInside)

	isInArea = newIsInside

	isCarryingBrainrot =
		(LocalPlayer:GetAttribute("IsCarryingBrainrot") == true)

	updateAll()

end

--------------------------------------------------
-- Carry State Changed
--------------------------------------------------

local function onCarryChanged()

	isCarryingBrainrot =
		(LocalPlayer:GetAttribute("IsCarryingBrainrot") == true)

	dprint("CarryStateChanged:", isCarryingBrainrot)

	updateAll()

end

--------------------------------------------------
-- Initialize UI
--------------------------------------------------

function BlocksSpawnAreaController:_initUI()

	PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

	local dropGui =
		PlayerGui:WaitForChild("DropGui")

	DropButtonFrame =
		dropGui:WaitForChild("DropButtonFrame")

	DropButton =
		DropButtonFrame:WaitForChild("DropButton")

	DropButton.MouseButton1Click:Connect(function()

		if BrainrotCarryService then
			BrainrotCarryService:RequestDrop("DropButtonClicked")
		end

	end)

	DropButtonFrame.Visible = false

end

--------------------------------------------------
-- Initialize Audio
--------------------------------------------------

function BlocksSpawnAreaController:_initAudio()

	ExitAudio = Instance.new("Sound")
	ExitAudio.Name = "ExitAreaAudio"
	ExitAudio.SoundId = Config.EXIT_AUDIO_ID
	ExitAudio.Volume = Config.EXIT_AUDIO_VOLUME
	ExitAudio.Parent = LocalPlayer

end

--------------------------------------------------
-- Connect Signals
--------------------------------------------------

function BlocksSpawnAreaController:_connectSignals()

	BlocksSpawnAreaService.ZoneChanged:Connect(function(isInside)

		onZoneChanged(isInside)

	end)

	LocalPlayer:GetAttributeChangedSignal(
		"IsCarryingBrainrot"
	):Connect(function()

		onCarryChanged()

	end)

	LocalPlayer:GetAttributeChangedSignal(
		"IsInBlocksSpawnArea"
	):Connect(function()

		local attr =
			(LocalPlayer:GetAttribute("IsInBlocksSpawnArea") == true)

		if attr ~= isInArea then
			onZoneChanged(attr)
		end

	end)

end

--------------------------------------------------
-- Knit Init
--------------------------------------------------

function BlocksSpawnAreaController:KnitInit()

	dprint("KnitInit")

	BlocksSpawnAreaService =
		Knit.GetService("BlocksSpawnAreaService")

	BrainrotCarryService =
		Knit.GetService("BrainrotCarryService")

end

--------------------------------------------------
-- Knit Start
--------------------------------------------------

function BlocksSpawnAreaController:KnitStart()

	dprint("KnitStart")

	self:_initUI()
	self:_initAudio()
	self:_connectSignals()

	isInArea =
		(LocalPlayer:GetAttribute("IsInBlocksSpawnArea") == true)

	isCarryingBrainrot =
		(LocalPlayer:GetAttribute("IsCarryingBrainrot") == true)

	updateAll()

end

return BlocksSpawnAreaController