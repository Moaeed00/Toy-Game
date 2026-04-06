-- [Services] ----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- [Knit] ----
local Knit = require(ReplicatedStorage.Packages.Knit)

-- [Modules] ----
local NotificationHandler = require(ReplicatedStorage.Utility:WaitForChild("NotificationHandler"))
-- local Configuration = ReplicatedStorage:WaitForChild("Configuration")
-- local CodesConfig = require(Configuration:WaitForChild("CodesConfiguration"))

-- [UI References] ----
local PlayerGui = player:WaitForChild("PlayerGui")
local RedeemCodeGui = PlayerGui:WaitForChild("RedeemCode")

local MainFrame = RedeemCodeGui:WaitForChild("MainFrame")
local textBox = MainFrame:WaitForChild("Box")
local ClaimButton = MainFrame:WaitForChild("Buttons"):WaitForChild("Claim")
local CloseButton = MainFrame:WaitForChild("Close")

-- [Variables] ----
local PlaceHolderText = "Enter code..."
textBox.PlaceholderText = PlaceHolderText
textBox.ClearTextOnFocus = true

-- [Controller] ----
local CodesController = Knit.CreateController({
	Name = "CodesController",
})

local CodesService

-- [Utility] ----
local function Trim(str)
	return string.gsub(str, "^%s*(.-)%s*$", "%1")
end

local function HandleTextBoxFrame()
	textBox.Text = ""
end

-- [Core Logic] ----
function CodesController:OnClaim()
	if not CodesService then
		warn("CodesService not ready yet")
		return
	end

	local code = Trim(textBox.Text)
	if string.len(code) == 0 then
		NotificationHandler:DisplayNotificationMessage("Please enter a valid code!", "Error")
		textBox.Text = ""
		return
	end

	local success, message = CodesService:RedeemCode(code)
	if success then
		NotificationHandler:DisplayNotificationMessage(message, "Success")
	else
		NotificationHandler:DisplayNotificationMessage(message, "Error")
	end

	textBox.Text = ""
	textBox:ReleaseFocus()
	textBox:CaptureFocus()
end

-- [UI Events] ----
function CodesController:OnFocused()
	textBox.Text = ""
end

function CodesController:OnFocusLost(enterPressed)
	if enterPressed then
		self:OnClaim()
	end
end

-- [Init UI Effects] ----
function CodesController:InitializeUI()
	-- local UIHoverModule = require(ReplicatedStorage.Modules.UIHoverModule)

	-- UIHoverModule.Bind(RedeemCodeGui, {
	-- 	HoverScale = 1.08,
	-- 	HoverTime = 0.1,
	-- 	HoverColor3 = Color3.fromRGB(255, 255, 255),
	-- 	HoverSound = nil,
	-- 	ClickSound = nil,
	-- 	ApplyToDescendants = true,
	-- })
end

-- [Public API] ----
function CodesController:SetEnabled(enabled: boolean)
	RedeemCodeGui.Enabled = enabled

	if enabled then
		HandleTextBoxFrame()
	end
end

-- [Knit Lifecycle] ----
function CodesController:KnitInit()
	CodesService = Knit.GetService("CodesService")
end

function CodesController:KnitStart()
	textBox.Focused:Connect(function()
		self:OnFocused()
	end)

	textBox.FocusLost:Connect(function(enterPressed)
		self:OnFocusLost(enterPressed)
	end)

	ClaimButton.MouseButton1Click:Connect(function()
		self:OnClaim()
	end)

	CloseButton.MouseButton1Click:Connect(function()
		if self.LobbyHUD then
			self.LobbyHUD:OpenContainer("MainGui")
		end
	end)
end

return CodesController
