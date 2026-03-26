local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local FootballsConfig = require(ReplicatedStorage.Configuration.Footballs.FootballsConfig)
local GradientsFolder: Folder = ReplicatedStorage.Assets.Gradients
local Knit = require(ReplicatedStorage.Packages.Knit)
local PlayerGui = Player:WaitForChild("PlayerGui")
local FootballShopGui: ScreenGui = PlayerGui:WaitForChild("FootballShopGui")
local FootballFrameUI: ImageLabel = FootballShopGui:WaitForChild("FootballsFrame")
local CloseButton: ImageButton = FootballFrameUI:WaitForChild("CloseButton")
local NotificationHandler = require(ReplicatedStorage:WaitForChild("Utility"):WaitForChild("NotificationHandler"))

local FootballShopController = Knit.CreateController({ Name = "FootballShopController" })
local ProductPurchaseService

function FootballShopController:KnitInit() end

function FootballShopController:KnitStart()
	FootballShopController.CameraController = Knit.GetController("CameraController")
	FootballShopController.FootballShopService = Knit.GetService("FootballShopService")
	ProductPurchaseService = Knit.GetService("ProductPurchaseService")
	FootballShopController.LobbyHud = Knit.GetController("Hud")
	FootballShopController.ShopGenerated = false

	self:ConnectCloseButton()

	self.FootballShopService.UpdateClientDataEvent:Connect(function(data)
		self.PlayerData = data
		if not self.ShopGenerated then
			self:GenerateShopData()
			self.ShopGenerated = true
		end
		self:RefreshAllButtons()
		print("[FootballShopController] Player Data: ", self.PlayerData)
	end)
end

function FootballShopController:ConnectCloseButton()
	CloseButton.Activated:Connect(function()
		self.LobbyHud:OpenContainer("MainGui")
	end)
end

function FootballShopController:SetEnabled(enabled: boolean)
	FootballShopGui.Enabled = enabled
end

function FootballShopController:GenerateShopData()
	local footballList = {}
	for name, data in pairs(FootballsConfig) do
		table.insert(footballList, {
			Name = name,
			Data = data,
		})
	end

	table.sort(footballList, function(a, b)
		return a.Data.Power < b.Data.Power
	end)

	local ImageLabelFrame: ImageLabel = Player.PlayerGui:WaitForChild("FootballShopGui"):WaitForChild("FootballsFrame")
	local ScrollFrame: ScrollingFrame = ImageLabelFrame:WaitForChild("Scroll")
	local Template = ImageLabelFrame:WaitForChild("Temp")

	for _, football in pairs(footballList) do
		local name = football.Name
		local data = football.Data

		local item: ImageButton = Template:Clone()
		item.Name = name
		item.Parent = ScrollFrame
		local itemFrame: Frame = item:WaitForChild("Frame")
		local itemFrameBG = itemFrame:WaitForChild("BGFrame")
		itemFrame.ItemName.Text = name
		itemFrame.ItemRarity.Text = data.RarityType
		itemFrame.ImageBG.ItemImage.Image = data.Image
		itemFrame.HitPower.HitPowerText.Text = data.Power .. " Power"
		itemFrame.Equip.PriceStatus.Text = "$" .. self:FormatCommas(tostring(data.Price))
		itemFrame.RobuxBuy.Price.Text = self:FormatCommas(tostring(data.Robux))
		local RarityGradient: UIGradient = GradientsFolder:WaitForChild(data.RarityType)
		local OutlineRarityGradient = RarityGradient:Clone()
		OutlineRarityGradient.Parent = itemFrame
		local BGRarityGradient = RarityGradient:Clone()
		BGRarityGradient.Parent = itemFrameBG

		self:UpdateButtonState(item, name)

		itemFrame.RobuxBuy.MouseButton1Click:Connect(function()
			local footballUnlockId = FootballsConfig[name].UnlockID
			ProductPurchaseService.PromptPurchase:Fire(footballUnlockId)
		end)

		itemFrame.Equip.MouseButton1Click:Connect(function()
			local owned = self:IsOwned(name)
			local equipped = self:IsEquipped(name)
			if not owned then
				self.FootballShopService:BuyFootballViaCoins(name):andThen(function(result: {})
					if not result then
						return
					end

					if not result.Success then
						local message = `You need ${self:FormatCommas(tostring(result.CoinsRequired))} more cash.`
						NotificationHandler:DisplayNotificationMessage(message, "Error")
					else
						local message = `Successfully purchased ${result.FootballName} football!`
						NotificationHandler:DisplayNotificationMessage(message, "Success")
					end
				end)
				return
			end
			if equipped then
				return
			end

			self.FootballShopService.EquipFootballEvent:Fire(name)
		end)

		item.Visible = true
	end
end

function FootballShopController:IsOwned(name: string)
	if not self.PlayerData or not self.PlayerData.Owned then
		return false
	end

	local footballId: number = FootballsConfig[name].Id
	for _, ownedId in ipairs(self.PlayerData.Owned) do
		if ownedId == footballId then
			return true
		end
	end

	return false
end

function FootballShopController:IsEquipped(name: string)
	if not self.PlayerData then
		return false
	end

	return self.PlayerData.Equipped == FootballsConfig[name].Id
end

function FootballShopController:UpdateButtonState(item: Frame, name: string)
	local owned = self:IsOwned(name)
	local equipped = self:IsEquipped(name)
	local config = FootballsConfig[name]

	local robuxBuyButton: ImageButton = item:WaitForChild("Frame"):WaitForChild("RobuxBuy")
	local equipButton: ImageButton = item:WaitForChild("Frame"):WaitForChild("Equip")
	local priceText: TextLabel = equipButton:WaitForChild("PriceStatus")

	if not owned then
		-- not owned → show buy
		equipButton.Visible = true
		robuxBuyButton.Visible = config.UnlockID ~= nil
		priceText.Text = "$" .. self:FormatCommas(tostring(config.Price))
		self:ToggleButtonStatus(item, false)
		return
	end
	-- owned → hide buy
	robuxBuyButton.Visible = false
	equipButton.Visible = true

	if equipped then
		priceText.Text = "Equipped"
		self:ToggleButtonStatus(item, true)
	else
		priceText.Text = "Equip"
		self:ToggleButtonStatus(item, false)
	end
end

function FootballShopController:ToggleButtonStatus(item: Frame, toggle: boolean)
	item:WaitForChild("Frame"):WaitForChild("Equip"):WaitForChild("Blue").Enabled = not toggle
	item:WaitForChild("Frame"):WaitForChild("Equip").Active = not toggle
	item:WaitForChild("Frame"):WaitForChild("Equip").Interactable = not toggle
	item:WaitForChild("Frame"):WaitForChild("Equip"):WaitForChild("Green").Enabled = toggle
	item:WaitForChild("Frame"):WaitForChild("Equip"):WaitForChild("BG"):WaitForChild("Blue").Enabled = not toggle
	item:WaitForChild("Frame"):WaitForChild("Equip"):WaitForChild("BG"):WaitForChild("Green").Enabled = toggle
end

function FootballShopController:RefreshAllButtons()
	local ScrollFrame: ScrollingFrame = FootballFrameUI:WaitForChild("Scroll")

	for _, item in ipairs(ScrollFrame:GetChildren()) do
		if item:IsA("ImageButton") then
			local name: string = item:WaitForChild("Frame"):WaitForChild("ItemName").Text
			self:UpdateButtonState(item, name)
		end
	end
end

function FootballShopController:FormatCommas(arg: string)
	local prefix, numbers = arg:match("^(.-)(%d+)$")
	if not numbers then
		return
	end
	numbers = numbers:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return prefix .. numbers
end

return FootballShopController
