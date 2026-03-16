local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local playerGui: PlayerGui = Player:WaitForChild("PlayerGui")
local mainGui: ScreenGui = playerGui:WaitForChild("MainGui")
local uiTopFrame: Frame = mainGui:WaitForChild("UITop")
local innerFrame: Frame = uiTopFrame:WaitForChild("Frame")
local homeButton: ImageButton = innerFrame:WaitForChild("Home")
local shopButton: ImageButton = innerFrame:WaitForChild("Shops")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GameManagerController = Knit.CreateController({
	Name = "GameManagerController",
})

local function teleportToBase()
	local bases: Folder = Workspace:WaitForChild("Bases")
	local base: Model = bases:WaitForChild(tostring(Player.UserId))
	local spawnPoint = base:WaitForChild("Spawn")

	if spawnPoint then
		Player.Character:PivotTo(spawnPoint.CFrame)
	end
end

local function teleportToShop()
	local shopTpPart = Workspace:WaitForChild("ShopTpPart")

	if shopTpPart then
		Player.Character:PivotTo(shopTpPart.CFrame)
	end
end

--// ==========================================
--// Knit Lifecycle
--// ==========================================
function GameManagerController:KnitInit() end

function GameManagerController:KnitStart()
	homeButton.MouseButton1Click:Connect(function()
		teleportToBase()
	end)

	shopButton.MouseButton1Click:Connect(function()
		teleportToShop()
	end)
end

return GameManagerController
