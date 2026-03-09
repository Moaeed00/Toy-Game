local CharacterSize = {}

local DefaultSize = 1

function CharacterSize:ScaleUp(player: Player, ScaleValue: number)
	player.Character:ScaleTo(ScaleValue)
end

function CharacterSize:ScaleDown(player: Player)
	player.Character:ScaleTo(DefaultSize)
end

return CharacterSize
