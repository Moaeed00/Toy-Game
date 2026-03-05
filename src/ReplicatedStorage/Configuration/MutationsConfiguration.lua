export type Mutations = {
	Gold: boolean,
	Zombie: boolean,
	Electric: boolean,
}

return {
	Gold = {
		Color = Color3.fromRGB(255, 208, 21),
		Multiplier = 1.25,
	},

	Diamond = {
		Color = Color3.fromRGB(0, 255, 255),
		Multiplier = 1.5,
	},

	Electric = {
		Color = Color3.fromRGB(11, 96, 255),
		Multiplier = 2,
	},

	Zombie = {
		Color = Color3.fromRGB(166, 255, 0),
		Multiplier = 2.5,
	},

	Valentine = {
		Color = Color3.fromRGB(245, 110, 255),
		Multiplier = 3,
	},
}
