---- [Services]			----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LobbyHUDHelpers: Folder = ReplicatedStorage:WaitForChild("LobbyHUDHelpers")

---- [Modules]			----
local Knit: {} = require(ReplicatedStorage.Packages.Knit)
local FocusEffect: {} = require(LobbyHUDHelpers:WaitForChild("FocusEffect"))
local LobbyCircleTouch: {} = require(LobbyHUDHelpers:WaitForChild("LobbyCircleTouch"))
local Format: {} = require(ReplicatedStorage.Libraries.Format)
local CounterTween: {} = require(ReplicatedStorage.Utility.Countertween)
local CashAnimation: {} = require(ReplicatedStorage.Utility.CashAnimation)
local NotificationHandler: {} = require(ReplicatedStorage.Utility.NotificationHandler)

----	[References]		----
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("MainGui")
local CurrencyTextHolder = MainGui:WaitForChild("Cash"):WaitForChild("Cash")
local PointsTextHolder = MainGui:WaitForChild("Points"):WaitForChild("Value")

local hoverTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local unHoverTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local DataHandlerService
local ProductPurchaseService

local Controllers = {
	-- DailySpin = "SpinClient",
	FootballShop = "FootballShopController",
	Merchant = "MerchantController",
	GearShop = "GearShopController",
	ProductShop = "ProductShopController",
	RedeemCode = "CodesController",
	Invite = "InviteFriendController",
	Rebirth = "RebirthController",
}

local Hud = Knit.CreateController({
	Name = "Hud",
})

Hud.CurrentActiveScreen = nil
Hud.FocusEffect = FocusEffect
LobbyCircleTouch.LobbyHUD = Hud

Hud.Buttons = {
	-- DailySpin = MainGui.Left.Last.DailySpin,
	ProductShop = MainGui.UILeft.Shop,
	Invite = MainGui.UILeft.Invite,
	VIP = MainGui.UILeft.VIP,
	Index = MainGui.UILeft.Index,
	Rebirth = MainGui.UILeft.Rebirth,
	RedeemCode = MainGui.UIRight.RedeemCode,
	StarterPack = MainGui.UIRight.StarterPack,
	MagicCarpet = MainGui.UIRight.MagicCarpet,
	Home = MainGui.UITop.Frame.Home,
	Shops = MainGui.UITop.Frame.Shops,
	Sell = MainGui.UITop.Frame.Sell,
}

Hud.Controller = { MainGui = Hud }

local GUIS = {
	-- DailySpin = "DailySpin",
	FootballShop = "FootballShopGui",
	Merchant = "MerchantGui",
	GearShop = "GearGui",
	ProductShop = "ProductShopGui",
	RedeemCode = "RedeemCode",
	Rebirth = "RebirthGui",
}

Hud.GUI = { MainGui = MainGui }
for key, guiName in pairs(GUIS) do
	Hud.GUI[key] = PlayerGui:WaitForChild(guiName)
end

local function SetUpButtonAnims(button)
	if not button:GetAttribute("OriginalSize") then
		button:SetAttribute("OriginalSize", button.Size)
	end

	local originalSize = button:GetAttribute("OriginalSize")
	local hover = TweenService:Create(button, hoverTweenInfo, {
		Size = originalSize + UDim2.fromScale(0.07, 0.03),
	})

	local unhover = TweenService:Create(button, unHoverTweenInfo, {
		Size = originalSize,
	})

	button.MouseEnter:Connect(function()
		hover:Play()
	end)

	button.MouseLeave:Connect(function()
		unhover:Play()
	end)

	button.MouseButton1Click:Connect(function()
		unhover:Play()
	end)
end

local function moneyFormatter(v: number): string
	return `${Format.commaNumber(v)}`
end

local function OnCashChanged(newValue: number, FirsTime: boolean)
	local prev = CounterTween.GetCurrentValue(CurrencyTextHolder)

	if not FirsTime then
		CashAnimation.play(prev, newValue)
	end

	CounterTween.Animate(CurrencyTextHolder, prev, newValue, {
		Duration = 0.35,
		Formatter = moneyFormatter,
	})
end

local function OnPointsChanged(newValue: number)
	PointsTextHolder.Text = math.floor(newValue)
end

function Hud:SetEnabled(enabled: boolean)
	MainGui.Enabled = enabled
end

function Hud:SetupHudValues()
	local leaderstats: Folder = Player:WaitForChild("leaderstats")

	local Points = leaderstats:WaitForChild("Points")
	Points.Changed:Connect(OnPointsChanged)
	OnPointsChanged(Points.Value)
end

function Hud:OpenContainer(name: string)
	local gui = self.GUI[name]
	if gui then
		self:CloseContainer(self.CurrentActiveScreen)
		self.CurrentActiveScreen = name

		if self.Controller[name] then
			self.Controller[name]:SetEnabled(true)
		else
			warn("No controller for: ", name)
		end

		if name ~= "MainGui" then
			FocusEffect.Show()
		else
			FocusEffect.Hide()
		end
	else
		if name == "Invite" then
			self.Controller[name]:SetEnabled(true)
		elseif name == "VIP" then
			ProductPurchaseService.PromptPurchase:Fire(3559290714)
		elseif name == "StarterPack" then
			ProductPurchaseService.PromptPurchase:Fire(3559281772)
		else
			NotificationHandler:DisplayNotificationMessage("Comming Soon", "Error")
		end
	end
end

function Hud:CloseContainer(name: string)
	for _, button in pairs(self.Buttons) do
		local originalSize = button:GetAttribute("OriginalSize")
		if originalSize then
			button.Size = originalSize
		end
	end

	if self.Controller[name] then
		self.Controller[name]:SetEnabled(false)
	end

	if self.CurrentActiveScreen == name then
		self.CurrentActiveScreen = nil
	end

	FocusEffect.Hide()
end

function Hud:CloseAllContainers()
	for _, button in pairs(self.Buttons) do
		local originalSize = button:GetAttribute("OriginalSize")
		if originalSize then
			button.Size = originalSize
		end
	end

	for _, gui in pairs(self.GUI) do
		if gui.Enabled == true then
			gui.Enabled = false
		end
	end

	self.CurrentActiveScreen = nil

	FocusEffect.Hide()
end

function Hud:OnClickButton(name: string)
	self:OpenContainer(name)
end

function Hud:KnitInit()
	DataHandlerService = Knit.GetService("DataHandlerService")
	ProductPurchaseService = Knit.GetService("ProductPurchaseService")
end

function Hud:KnitStart()
	DataHandlerService.UpdateMoney:Connect(OnCashChanged)

	self.CurrentActiveScreen = "MainGui"

	for key, controllerName in pairs(Controllers) do
		local controller = Knit.GetController(controllerName)
		if controller then
			self.Controller[key] = controller
			self.Controller[key].LobbyHUD = Hud
		else
			warn("Controller not found: " .. controllerName)
		end
	end

	for name, button in pairs(self.Buttons) do
		if button:IsA("TextButton") or button:IsA("ImageButton") then
			button.MouseButton1Down:Connect(function()
				self:OnClickButton(name)
			end)

			SetUpButtonAnims(button)
		else
			warn("Invalid button: " .. name)
		end
	end

	self:SetupHudValues()
	CashAnimation.init(MainGui)
end

return Hud
