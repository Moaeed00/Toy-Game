--!strict
--// File: ServerScriptService/KnitServer/Services/DataHandlerService/ProfileTemplate.lua
--// ProfileTemplate.lua
--// FINAL: Slide, Punch, Golden Slide, Golden Punch

return {
	Coins = 0,
	Points = 0,
	
	--// Gear ownership
	Gear = {
		["Slide"] = true, -- Free
		["Punch"] = true, -- Free
		["Golden Slide"] = false,
		["Golden Punch"] = false,
	},
	
	--// Auto-buy settings
	AutoBuy = {
		["Slide"] = false,
		["Punch"] = false,
		["Golden Slide"] = false,
		["Golden Punch"] = false,
	},
}