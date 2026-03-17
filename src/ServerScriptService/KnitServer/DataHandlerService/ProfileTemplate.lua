--!strict
--// File: ServerScriptService/KnitServer/Services/DataHandlerService/ProfileTemplate.lua
--// ProfileTemplate.lua
--// FINAL: Slide, Punch, Golden Slide, Golden Punch

return {
	Points = 10000,
	Footballs = {
		Equipped = 1,
		Owned = { 1 },
	},
	Money = 100,

	LikesReceived = 0,
	LikedPlayers = {},

	LastJoin = 0,

	Backpack = {},
	Base = {},

	--// Gear ownership
	Gear = {
		["Slide"] = true, -- Free
		["Punch"] = true, -- Free
		["Speed Coil"] = false,
		["Golden Slide"] = false,
		["Golden Punch"] = false,
		["Gravity Coil"] = false,
	},

	--// Auto-buy settings
	AutoBuy = {
		["Slide"] = false,
		["Punch"] = false,
		["Speed Coil"] = false,
		["Golden Slide"] = false,
		["Golden Punch"] = false,
		["Gravity Coil"] = false,
	},
}
