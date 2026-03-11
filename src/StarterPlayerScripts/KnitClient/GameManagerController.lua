local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local playerGui: PlayerGui = Player:WaitForChild("PlayerGui")
local mainGui: ScreenGui = playerGui:WaitForChild("MainGui")
local uiTopFrame: Frame = mainGui:WaitForChild("UITop")
local innerFrame: Frame = uiTopFrame:WaitForChild("Frame")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GameManagerController = Knit.CreateController({
	Name = "GameManagerController",
})

local function teleportToBase()
	local bases: Folder = Workspace:WaitForChild("Bases")
	local base: Model = bases:WaitForChild(tostring(Player.UserId))
	local spawnPoint = base:WaitForChild("Spawn")

	local homeButton: ImageButton = innerFrame:WaitForChild("Home")

	homeButton.MouseButton1Click:Connect(function()
		if spawnPoint then
			Player.Character:PivotTo(spawnPoint.CFrame)
		end	
	end)
end

local function teleportToShop()
	local shopTpPart = Workspace:WaitForChild("ShopTpPart")	

	local shopButton: ImageButton = innerFrame:WaitForChild("Shops")

	shopButton.MouseButton1Click:Connect(function()
		if shopTpPart then
			Player.Character:PivotTo(shopTpPart.CFrame)
		end	
	end)
end

--// ==========================================
--// Knit Lifecycle
--// ==========================================
function GameManagerController:KnitInit()
end

function GameManagerController:KnitStart()
    teleportToBase()
	teleportToShop()
end

return GameManagerController
