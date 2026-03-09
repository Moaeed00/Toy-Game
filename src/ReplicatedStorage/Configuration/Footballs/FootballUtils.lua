local FootballsConfig = require(script.Parent.FootballsConfig)

local FootballUtils = {}

function FootballUtils:GetFootballById(id)
	for name, data in pairs(FootballsConfig) do
		if data.Id == id then
			return name, data
		end
	end
end

return FootballUtils