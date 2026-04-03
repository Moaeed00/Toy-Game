return {
	Points = 0,
	Footballs = {
		Equipped = 0,
		Owned = { },
	},
	Money = 50,
	Rebirth = 0,
	IsFirstTimeLoad = true,
	IsGroupJoinRewardClaimed = false,
	MoneyMultiplier = 1,
	LikesReceived = 0,
	LikedPlayers = {},
	LastJoin = 0,
	Backpack = {},
	Base = {},
	BaseColor = "Normal",
	--// Gear ownership
	Gear = {
		["Slide"] = true, -- Free
		["Punch"] = false, -- Free
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
	-- Brainrot Index: Stores discovered brainrot keys
	--   Normal variant → "Trippi_Troppi"        (true)
	--   Golden variant → "Golden_Trippi_Troppi"  (true)
	-- Missing keys are treated as undiscovered
	DiscoveredBrainrots = {},
	DiscoveredBrainrotsPercentage = 0,
	IndexMultiplierBonus = 0,
}
