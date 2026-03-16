local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local getPlayerPicture = require(ReplicatedStorage.Shared.Utils.getPlayerPicture)
--local Assets = require(ReplicatedStorage.Shared.Modules.Assets)

local BasesFolder = workspace:WaitForChild("Bases")

local function init_like_prompt(player: Player, base: Model)
	local sign = base:FindFirstChild("Sign")
	if not sign then
		warn("[LikePrompt] ❌ No 'Sign' found in base:", base.Name)
		return
	end

	local surface = sign:FindFirstChild("Surface")
	if not surface then
		warn("[LikePrompt] ❌ No 'Surface' found in Sign. Children:", sign:GetChildren())
		return
	end

	print("[LikePrompt] Surface ClassName:", surface.ClassName)
	print("[LikePrompt] Surface IsA BasePart:", surface:IsA("BasePart"))

	if not surface:IsA("BasePart") then
		warn("[LikePrompt] ❌ Surface is NOT a BasePart — ProximityPrompt won't work on a", surface.ClassName)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LikePrompt"
	prompt.ActionText = player.DisplayName .. "'s Base!"
	prompt.ObjectText = "Like this Base"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 20
	prompt.Parent = surface
	prompt.RequiresLineOfSight = false

	print("[LikePrompt] ✅ Prompt created. Parent:", prompt.Parent, "| Enabled:", prompt.Enabled)
	print("[LikePrompt] Surface children:", surface:GetChildren())
end

local function init_player_info(player: Player, base: Model)
	local playerPictureId = getPlayerPicture(player.UserId)

	local sign = base.Sign
	local surfaceGui = sign.Surface.SurfaceGui

	surfaceGui.PlayerPicture.Image = playerPictureId
end

local function init_sign(player: Player, base: Model)
	local sign = base.Sign
	local surfaceGui = sign.Surface.SurfaceGui

	surfaceGui.Frame.Info.Username.Text = `@{player.DisplayName} Base!`
end

return function(player: Player, slot: BasePart)
	local baseModel = ServerStorage:WaitForChild("Assets"):WaitForChild("Bases"):WaitForChild("BaseTemplate")
	if not baseModel then
		return
	end

	local base = baseModel:Clone()
	base.Name = tostring(player.UserId)

	base:PivotTo(slot.CFrame)
	init_player_info(player, base)
	init_sign(player, base)
	init_like_prompt(player, base)

	-- ✅ FIX: ne jamais faire slot.Base:Destroy() sans check (sinon 2e joueur crash)
	local placeholder = slot:FindFirstChild("Base")
	if placeholder then
		placeholder:Destroy()
	end

	base.Parent = BasesFolder

	return base
end
