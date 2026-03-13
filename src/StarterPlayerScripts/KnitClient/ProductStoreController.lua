-- ProductShopController.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerService = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ProductStoreData = require(ReplicatedStorage.Configuration.ProductStoreData)
local NotificationHandler = require(ReplicatedStorage.Utility.NotificationHandler)
local DeveloperProductHelper = require(ReplicatedStorage.Utility.DeveloperProductHelper)

local ProductShopController = Knit.CreateController({ Name = "ProductShopController" })

--[Player]
local Player = PlayerService.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--[UI References]
local ProductShopGui = PlayerGui:WaitForChild("ProductShopGui")
local ShopFrame = ProductShopGui:WaitForChild("ShopFrame")
local Deals = ShopFrame:WaitForChild("Deals")

local ProductPurchaseService
local RewardHandlerService

local function ShowNotification(message: string)
	NotificationHandler:DisplayNotificationMessage(message, "Success")
end

local function WireItem(itemFrame: Frame, itemData: {})
	if not itemData or not itemData.Id then
		warn("[ProductShopController] Missing ItemData for:", itemFrame.Name)
		return
	end

	local buyButton = itemFrame:FindFirstChild("Buy")
	if not buyButton then
		return
	end

	local imagebutton = buyButton:FindFirstChild("Button")
	if not imagebutton then
		return
	end

	local costLabel: TextLabel = imagebutton:FindFirstChild("Cost")
	local titleLabel: TextLabel = imagebutton:FindFirstChild("Title")

	if costLabel then
		costLabel.Text = "\u{E002}" .. DeveloperProductHelper:GetPrice(itemData.Id, itemData.Price)
	end

	if titleLabel then
		titleLabel.Text = itemData.Title
	end

	buyButton.MouseButton1Click:Connect(function()
		ProductPurchaseService.PromptPurchase:Fire(itemData.Id)
	end)
end

function ProductShopController:KnitInit()
	ProductPurchaseService = Knit.GetService("ProductPurchaseService")
	RewardHandlerService = Knit.GetService("RewardHandlerService")
end

function ProductShopController:KnitStart()
	for itemKey, itemData in pairs(ProductStoreData) do
		local itemFrame = Deals:FindFirstChild(itemKey, true)
		if itemFrame and itemFrame:IsA("Frame") then
			WireItem(itemFrame, itemData)
		else
			warn("[ProductShopController] Frame not found for:", itemKey)
		end
	end

	RewardHandlerService.OnPurchaseNotification:Connect(function(message: string)
		task.wait(1)
		ShowNotification(message)
	end)
end

return ProductShopController
