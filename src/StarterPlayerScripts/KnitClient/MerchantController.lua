local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local BrainrotsData = require(ReplicatedStorage.Configuration.Brainrots.EntitiesConfiguration)
local Gradients = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Gradients")
local Knit = require(ReplicatedStorage.Packages.Knit)

local PlayerGui = Player:WaitForChild("PlayerGui")
local MerchantGui: ScreenGui = PlayerGui:WaitForChild("MerchantGui")
local MerchantFrame: Frame = MerchantGui:WaitForChild("MerchantFrame")
local InventoryValue: TextLabel = MerchantFrame:WaitForChild("InventoryValue")
local SellAllButton: ImageButton = MerchantFrame:WaitForChild("SellAllButton")
local ScrollingFrame: ScrollingFrame = MerchantFrame:WaitForChild("ScrollingFrame")
local TempItem = ScrollingFrame:WaitForChild("Temp")
local CloseButton: ImageButton = MerchantFrame:WaitForChild("CloseButton")
local NoBrainrotsLabel: TextLabel = MerchantFrame:WaitForChild("NoBrainrots")
local NotificationHandler = require(ReplicatedStorage:WaitForChild("Utility"):WaitForChild("NotificationHandler"))

local MerchantController = Knit.CreateController({ Name = "MerchantController" })

function MerchantController:KnitInit() end

function MerchantController:KnitStart()
	MerchantController.CameraController = Knit.GetController("CameraController")
	MerchantController.MerchantService = Knit.GetService("MerchantService")
	MerchantController.LobbyHud = Knit.GetController("Hud")
	MerchantController.CurrentInventory = {}
	MerchantController.ActiveFrames = {}

	self:ConnectCloseButton()

	self.MerchantService.InventoryUpdateEvent:Connect(function(inventorySnapshot: {})
		self.CurrentInventory = inventorySnapshot
		self:RefreshUI()
	end)
	SellAllButton.Activated:Connect(function()
		self.MerchantService:SellAll():andThen(function(totalInventoryValue: number)
			local message = `Inventory sold for ${self:FormatNumber(tostring(totalInventoryValue))}`
			NotificationHandler:DisplayNotificationMessage(message, "Success")
			self:UpdateTotalValue(0)
		end)
	end)
end

function MerchantController:ConnectCloseButton()
	CloseButton.Activated:Connect(function()
		self.LobbyHud:OpenContainer("MainGui")
	end)
end

function MerchantController:SetEnabled(enabled: boolean)
	MerchantGui.Enabled = enabled
end

function MerchantController:RefreshUI()
	self:ClearFrames()
	local sortable = {}
	local totalValue = 0

	for name, data: {} in pairs(self.CurrentInventory) do
		local brainrotData = BrainrotsData.Processed[name]
		if not brainrotData then
			continue
		end

		totalValue += (brainrotData.SellPrice * data.Amount)

		table.insert(sortable, {
			ID = data.ID,
			Name = name,
			Image = brainrotData.Icon,
			Amount = data.Amount,
			SellPrice = brainrotData.SellPrice,
			Variant = data.Variant,
			RarityType = brainrotData.RarityType,
		})
	end

	self:UpdateTotalValue(totalValue)

	table.sort(sortable, function(a, b)
		return a.SellPrice > b.SellPrice
	end)

	for index, item in ipairs(sortable) do
		local clone = TempItem:Clone()
		clone.Parent = ScrollingFrame
		clone.LayoutOrder = index

		clone.BrainrotName.Text = item.Name
		clone.BrainrotImage:WaitForChild("ImageLabel").Image = item.Image[item.Variant]
		clone.OwnedAmount.Text = "Owned: x" .. item.Amount
		clone.SellPrice.Text = "$" .. self:FormatNumber(item.SellPrice)
		clone.BrainrotRarity.Text = item.RarityType

		local rarity = item.RarityType
		if rarity then
			local gradient = Gradients:FindFirstChild(rarity)
			if gradient then
				gradient:Clone().Parent = clone:WaitForChild("BG")
				gradient:Clone().Parent = clone:WaitForChild("BrainrotRarity")
			end
		end
		clone.SellButton.Activated:Connect(function()
			self.MerchantService:Sell(item.ID):andThen(function(reward: number)
				local message = `Sold {item.Name} for ${self:FormatNumber(reward)}`
				NotificationHandler:DisplayNotificationMessage(message, "Success")
			end)
		end)
		clone.Visible = true

		self.ActiveFrames[index] = clone
	end

	self:ToggleNoBrainrotsVisibility(#sortable == 0)
end

function MerchantController:ClearFrames()
	for _, frame in pairs(self.ActiveFrames) do
		frame:Destroy()
	end
	table.clear(self.ActiveFrames)
end

function MerchantController:UpdateTotalValue(totalValue: number)
	InventoryValue.Text = "Total Value: $" .. self:FormatNumber(totalValue)
end

function MerchantController:ToggleNoBrainrotsVisibility(toggle: boolean)
	NoBrainrotsLabel.Visible = toggle
end

function MerchantController:FormatNumber(number: number)
	return tostring(math.floor(number)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

return MerchantController
