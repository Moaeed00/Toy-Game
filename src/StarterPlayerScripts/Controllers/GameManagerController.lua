local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DebrisService = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local playerGui: PlayerGui = Player:WaitForChild("PlayerGui")
local mainGui: ScreenGui = playerGui:WaitForChild("MainGui")
local uiTopFrame: Frame = mainGui:WaitForChild("UITop")
local innerFrame: Frame = uiTopFrame:WaitForChild("Frame")
local homeButton: ImageButton = innerFrame:WaitForChild("Home")
local shopButton: ImageButton = innerFrame:WaitForChild("Shops")
local sellButton: ImageButton = innerFrame:WaitForChild("Sell")
local SoundPlay = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"):WaitForChild("PlaySound"))
local ClickSFX: Sound = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Sounds"):FindFirstChild("Click")

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
		SoundPlay:Play(
			"BGMusic",
			"Background", -- or "BackgroundSounds" depending on your setup
			1, -- pitch
			1 -- volume
		)
	end
end

local function teleportToShop()
	local shopTpPart = Workspace:WaitForChild("ShopsTeleport")

	if shopTpPart then
		Player.Character:PivotTo(shopTpPart.CFrame)
	end
end

local function teleportToSellShop()
	local SellToPart = Workspace:WaitForChild("SellTeleport")

	if SellToPart then
		Player.Character:PivotTo(SellToPart.CFrame)
	end
end

--// ==========================================
--// Knit Lifecycle
--// ==========================================
function GameManagerController:KnitInit() end

function GameManagerController:KnitStart()
	homeButton.MouseButton1Click:Connect(function()
		if Player:GetAttribute("IsInArea") then
			return
		end

		self:PlayButtonCLickSound()
		teleportToBase()
	end)

	shopButton.MouseButton1Click:Connect(function()
		if Player:GetAttribute("IsInArea") then
			return
		end

		self:PlayButtonCLickSound()
		teleportToShop()
	end)

	sellButton.MouseButton1Click:Connect(function()
		if Player:GetAttribute("IsInArea") then
			return
		end

		self:PlayButtonCLickSound()
		teleportToSellShop()
	end)

	task.spawn(function()
		task.wait(2) -- wait for camera + sounds to exist
		SoundPlay:Play("BGMusic", "Background", 1, 1)
	end)
end

function GameManagerController:PlayButtonCLickSound()
	if ClickSFX then
		local clickSfx = ClickSFX:Clone()
		clickSfx.Parent = Player
		clickSfx.Looped = false
		clickSfx.Volume = 0.75
		clickSfx:Play()

		DebrisService:AddItem(clickSfx, clickSfx.TimeLength + 0.1)
	end
end

return GameManagerController
