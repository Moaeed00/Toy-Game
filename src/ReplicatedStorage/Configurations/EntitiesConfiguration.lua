local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RarityConfiguration = require(ReplicatedStorage.Configurations.RarityConfiguration)

export type Entity = {
	DisplayName: string,
	Icon: string,
	MoneyPerSec: number,
	StealPoints: number,
	Rarity: {},
}

return {
	Common = {
		MiniWave_Common = {
			DisplayName = "Mini Wave",
			Icon = "rbxassetid://126841142944996",
			MoneyPerSec = 1,
			StealPoints = 100,
			Robux = 25,
			Rarity = RarityConfiguration.Common,
		},
	},
}
