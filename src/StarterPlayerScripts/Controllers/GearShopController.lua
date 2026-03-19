--!strict
--// File: StarterPlayerScripts/KnitClient/Controllers/GearShopController.lua
--// GearShopController.lua
--// Client-side controller for gear shop UI and interactions

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local PlayerGui = Player:WaitForChild("PlayerGui")
local GearShopGui: ScreenGui = PlayerGui:WaitForChild("GearGui")
local GearFrame: Frame = GearShopGui:WaitForChild("GearFrame")
local CloseButton: ImageButton = GearFrame:WaitForChild("CloseButton")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GearShopController = Knit.CreateController({
	Name = "GearShopController",
})

local DEBUG_PRINTS = true

local function dprint(...: any)
	if DEBUG_PRINTS then
		print("[GearShopController]", ...)
	end
end

--// Service reference
GearShopController.GearShopService = nil

--// ==========================================
--// Buy Gear
--// ==========================================
function GearShopController:BuyGear(gearName: string)
	dprint("BuyGear() ->", gearName)

	if not self.GearShopService then
		warn("[GearShopController] GearShopService not available!")
		return
	end

	--// Call server
	self.GearShopService:BuyGear(gearName)
end

--// ==========================================
--// Toggle Auto-Buy
--// ==========================================
function GearShopController:ToggleAutoBuy(gearName: string, enabled: boolean)
	dprint("ToggleAutoBuy() ->", gearName, enabled)

	if not self.GearShopService then
		warn("[GearShopController] GearShopService not available!")
		return
	end

	--// Call server
	self.GearShopService:ToggleAutoBuy(gearName, enabled)
end

--// ==========================================
--// Handle Purchase Result
--// ==========================================
local function onPurchaseResult(success: boolean, gearName: string, message: string)
	dprint("PurchaseResult ->", gearName, "success:", success, "message:", message)

	--// You can add UI feedback here (notifications, sounds, etc.)
	if success then
		print("✅ Successfully purchased:", gearName)
		--// Play purchase sound?
		--// Show success notification?
	else
		warn("❌ Purchase failed:", gearName, "-", message)
		--// Show error notification?
	end
end

--// ==========================================
--// Handle Gear Updated
--// ==========================================
local function onGearUpdated()
	dprint("GearUpdated signal received - UI should refresh")
	--// The Buy.lua and AutoBuy.lua scripts will handle UI updates
end

--// ==========================================
--// Knit Lifecycle
--// ==========================================
function GearShopController:KnitInit()
	dprint("KnitInit() start")

	--// Get service
	self.GearShopService = Knit.GetService("GearShopService")
	dprint("Got GearShopService:", self.GearShopService)

	--// Connect to signals
	self.GearShopService.PurchaseResult:Connect(onPurchaseResult)
	self.GearShopService.GearUpdated:Connect(onGearUpdated)

	dprint("KnitInit() complete")
end

function GearShopController:KnitStart()
	dprint("KnitStart() start")

	GearShopController.LobbyHud = Knit.GetController("Hud")

	self:ConnectCloseButton()

	dprint("KnitStart() complete")
end

--// ==========================================
--// Handle UI Toggles
--// ==========================================

function GearShopController:ConnectCloseButton()
	CloseButton.Activated:Connect(function()
		self.LobbyHud:OpenContainer("MainGui")
	end)
end

function GearShopController:SetEnabled(enabled: boolean)
	GearShopGui.Enabled = enabled
end

return GearShopController
