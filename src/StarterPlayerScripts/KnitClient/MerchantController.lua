local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local BrainrotsData = require(ReplicatedStorage.Configurations.Brainrots.BrainrotsConfig)
local Gradients: Folder = ReplicatedStorage.Assets.Gradients
local Knit = require(ReplicatedStorage.Packages.Knit)

local PlayerGui = Player:WaitForChild("PlayerGui")
local MerchantGui = PlayerGui:WaitForChild("MainGui"):WaitForChild("MerchantFrame")
local InventoryValue: TextLabel = MerchantGui:WaitForChild("InventoryValue")
local SellAllButton: ImageButton = MerchantGui:WaitForChild("SellAllButton")
local ScrollingFrame: ScrollingFrame = MerchantGui:WaitForChild("ScrollingFrame")
local TempItem = ScrollingFrame:WaitForChild("Temp")
local CloseButton: ImageButton = MerchantGui:WaitForChild("CloseButton")
local NoBrainrotsLabel: TextLabel = MerchantGui:WaitForChild("NoBrainrots")
local NotificationHandler = require(ReplicatedStorage:WaitForChild("Utility"):WaitForChild("NotificationHandler"))

local MerchantController = Knit.CreateController { Name = "MerchantController" }

function MerchantController:KnitInit()
end

function MerchantController:KnitStart()
    MerchantController.CameraController = Knit.GetController("CameraController")
    MerchantController.MerchantService = Knit.GetService("MerchantService")
    MerchantController.CurrentInventory = {}
    MerchantController.ActiveFrames = {}

    self:ConnectSellBrainrots()
    self:ConnectCloseButton()

    self.MerchantService.InventoryUpdateEvent:Connect(function(inventorySnapshot: {})
        self.CurrentInventory = inventorySnapshot
        self:RefreshUI()
    end)
    SellAllButton.Activated:Connect(function()
        self.MerchantService:SellAll():andThen(function(totalInventoryValue: number)
            local message = `Inventory sold for ${self:FormatNumber(tostring(totalInventoryValue))}`
            NotificationHandler:DisplayNotificationMessage(message, "Success")
        end)
    end)
end

function MerchantController:ConnectSellBrainrots()
    local proximityPrompt: ProximityPrompt = workspace.Environment:WaitForChild("SellShop"):WaitForChild("Prompt"):WaitForChild("ProximityPrompt")
    if proximityPrompt then
        proximityPrompt.Triggered:Connect(function()
            self:ToggleSellShopUI(true)
        end)
    end
end

function MerchantController:ConnectCloseButton()
    CloseButton.Activated:Connect(function()
        self:ToggleSellShopUI(false)
    end)
end

function MerchantController:ToggleSellShopUI(toggle: boolean)
    self.CameraController:ToggleCameraBlurEffect(toggle)
    MerchantGui.Visible = toggle
end

function MerchantController:RefreshUI()
    self:ClearFrames()
    local sortable = {}
    local totalValue = 0

    for name, amount in pairs(self.CurrentInventory) do
        local data = BrainrotsData[name]
        if not data then
            continue
        end

        totalValue += (data.SellPrice * amount)

        table.insert(sortable, {
            Name = name,
            Amount = amount,
            SellPrice = data.SellPrice,
            RarityType = data.RarityType
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
            self.MerchantService:Sell(item.Name):andThen(function(reward: number)
                local message = `Sold {item.Name} for ${self:FormatNumber(tostring(reward))}`
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

function MerchantController:UpdateTotalValue(totalValue)
	InventoryValue.Text = "Total Value: $" .. self:FormatNumber(totalValue)
end

function MerchantController:ToggleNoBrainrotsVisibility(toggle: boolean)
    NoBrainrotsLabel.Visible = toggle
end

function MerchantController:FormatNumber(number: number)
	return tostring(math.floor(number)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

return MerchantController