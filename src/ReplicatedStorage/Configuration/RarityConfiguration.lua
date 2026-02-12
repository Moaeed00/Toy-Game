export type Rarity = {
	DisplayName: string,
	Color: Color3,
	Weight: number,
}

return {
	Common = {
		DisplayName = "Common",
		Color = Color3.fromRGB(152, 255, 34),
		Weight = 80 / 100,
	},

	Uncommon = {
		DisplayName = "Uncommon",
		Color = Color3.fromRGB(154, 152, 152),
		Weight = 70 / 100,
	},

	Rare = {
		DisplayName = "Rare",
		Color = Color3.fromRGB(53, 184, 255),
		Weight = 60 / 100,
	},

	Epic = {
		DisplayName = "Epic",
		Color = Color3.fromRGB(232, 56, 255),
		Weight = 40 / 100,
	},

	Legendary = {
		DisplayName = "Legendary",
		Color = Color3.fromRGB(255, 225, 0),
		Weight = 20 / 100,
	},

	Mythic = {
		DisplayName = "Mythic",
		Color = Color3.fromRGB(255, 0, 4),
		Weight = 10 / 100,
	},

	Secret = {
		DisplayName = "Secret",
		Color = Color3.fromRGB(255, 255, 255),
		Weight = 5 / 100,
	},

	Celestial = {
		DisplayName = "Celestial",
		Color = Color3.fromRGB(255, 0, 255),
		Weight = 4 / 100,
	},

	Fire = {
		DisplayName = "Fire",
		Color = Color3.fromRGB(255, 136, 0),
		Weight = 3 / 100,
	},
}
