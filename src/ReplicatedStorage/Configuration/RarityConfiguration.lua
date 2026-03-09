local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Gradients = Assets:WaitForChild("Effects"):WaitForChild("Gradients")

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
		Color = Gradients:WaitForChild("Secret"),
		Weight = 9 / 100,
	},

	Celestial = {
		DisplayName = "Celestial",
		Color = Gradients:WaitForChild("Celestial"),
		Weight = 8 / 100,
	},

	Fire = {
		DisplayName = "Fire",
		Color = Gradients:WaitForChild("Fire"),
		Weight = 7 / 100,
	},

	Abyssal = {
		DisplayName = "Abyssal",
		Color = Gradients:WaitForChild("Abyssal"),
		Weight = 6 / 100,
	},

	Void = {
		DisplayName = "Void",
		Color = Gradients:WaitForChild("Void"),
		Weight = 5 / 100,
	},

	Ancient = {
		DisplayName = "Ancient",
		Color = Color3.fromRGB(210, 170, 110),
		Weight = 4 / 100,
	},

	Neon = {
		DisplayName = "Neon",
		Color = Gradients:WaitForChild("Neon"),
		Weight = 3.5 / 100,
	},

	Rainbow = {
		DisplayName = "Rainbow",
		Color = Gradients:WaitForChild("Rainbow"),
		Weight = 3.4 / 100,
	},
}
