local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local getPlayerPicture = require(ReplicatedStorage.Shared.Utils.getPlayerPicture)
--local Assets = require(ReplicatedStorage.Shared.Modules.Assets)

local BasesFolder = workspace:WaitForChild("Bases")

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

	-- ✅ FIX: ne jamais faire slot.Base:Destroy() sans check (sinon 2e joueur crash)
	local placeholder = slot:FindFirstChild("Base")
	if placeholder then
		placeholder:Destroy()
	end

	base.Parent = BasesFolder

	return base
end
