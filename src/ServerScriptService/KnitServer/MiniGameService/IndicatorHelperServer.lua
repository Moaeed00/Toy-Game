local IndicatorHelperServer = {}

local Indicators = { "Left", "Right", "LeftFront", "RightFront" }

local LastIndicator = {}

function IndicatorHelperServer:SelectRandomIndicator(player)
	local last = LastIndicator[player]

	local choice
	repeat
		choice = Indicators[math.random(#Indicators)]
	until choice ~= last

	LastIndicator[player] = choice
	player:SetAttribute("CurrentIndicator", choice)

	print("indicatorServer", choice)
end

function IndicatorHelperServer:CleanUp(player)
	LastIndicator[player] = nil
	player:SetAttribute("CurrentIndicator", nil)
end

return IndicatorHelperServer
