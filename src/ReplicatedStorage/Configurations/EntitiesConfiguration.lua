local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RarityConfiguration = require(ReplicatedStorage.Configurations.RarityConfiguration)

export type Entity = {
	DisplayName: string,
	Icon: string,
	MoneyPerSec: number,
	Rarity: RarityConfiguration.Rarity,
}

return {
	SELL_FACTOR = 0.6,

	-- =======================
	-- Common
	-- =======================
	Common = {
		MiniWave_Common = {
			DisplayName = "Mini Wave",
			Icon = "rbxassetid://126841142944996",
			MoneyPerSec = 1,
			Rarity = RarityConfiguration.Common,
		},

		SmallWave_Common = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://126841142944996",
			MoneyPerSec = 3,
			Rarity = RarityConfiguration.Common,
		},

		MediumWave_Common = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://126841142944996",
			MoneyPerSec = 9,
			Rarity = RarityConfiguration.Common,
		},

		LargeWave_Common = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://126841142944996",
			MoneyPerSec = 15,
			Rarity = RarityConfiguration.Common,
		},

		HugeWave_Common = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://126841142944996",
			MoneyPerSec = 22,
			Rarity = RarityConfiguration.Common,
		},

		GiganticWave_Common = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://126841142944996",
			MoneyPerSec = 25,
			Rarity = RarityConfiguration.Common,
		},
	},

	-- =======================
	-- Uncommon
	-- =======================
	Uncommon = {
		MiniWave_Uncommon = {
			DisplayName = "Mini Wave",
			Icon = "rbxassetid://125517422318516",
			MoneyPerSec = 10,
			Rarity = RarityConfiguration.Uncommon,
		},

		SmallWave_Uncommon = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://125517422318516",
			MoneyPerSec = 30,
			Rarity = RarityConfiguration.Uncommon,
		},

		MediumWave_Uncommon = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://125517422318516",
			MoneyPerSec = 60,
			Rarity = RarityConfiguration.Uncommon,
		},

		LargeWave_Uncommon = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://125517422318516",
			MoneyPerSec = 100,
			Rarity = RarityConfiguration.Uncommon,
		},

		HugeWave_Uncommon = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://125517422318516",
			MoneyPerSec = 150,
			Rarity = RarityConfiguration.Uncommon,
		},

		GiganticWave_Uncommon = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://125517422318516",
			MoneyPerSec = 200,
			Rarity = RarityConfiguration.Uncommon,
		},
	},

	-- =======================
	-- Rare
	-- =======================
	Rare = {
		MiniWave_Rare = {
			DisplayName = "Mini Wave",
			Icon = "rbxassetid://106743348432002",
			MoneyPerSec = 100,
			Rarity = RarityConfiguration.Rare,
		},

		SmallWave_Rare = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://106743348432002",
			MoneyPerSec = 300,
			Rarity = RarityConfiguration.Rare,
		},

		MediumWave_Rare = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://106743348432002",
			MoneyPerSec = 600,
			Rarity = RarityConfiguration.Rare,
		},

		LargeWave_Rare = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://106743348432002",
			MoneyPerSec = 1_000,
			Rarity = RarityConfiguration.Rare,
		},

		HugeWave_Rare = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://106743348432002",
			MoneyPerSec = 1_500,
			Rarity = RarityConfiguration.Rare,
		},

		GiganticWave_Rare = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://106743348432002",
			MoneyPerSec = 2_000,
			Rarity = RarityConfiguration.Rare,
		},
	},

	-- =======================
	-- Epic
	-- =======================
	Epic = {
		MiniWave_Epic = {
			DisplayName = "Mini Wave",
			Icon = "rbxassetid://97059193661551",
			MoneyPerSec = 550,
			Rarity = RarityConfiguration.Epic,
		},

		SmallWave_Epic = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://97059193661551",
			MoneyPerSec = 1_650,
			Rarity = RarityConfiguration.Epic,
		},

		MediumWave_Epic = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://97059193661551",
			MoneyPerSec = 3_300,
			Rarity = RarityConfiguration.Epic,
		},

		LargeWave_Epic = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://97059193661551",
			MoneyPerSec = 5_500,
			Rarity = RarityConfiguration.Epic,
		},

		HugeWave_Epic = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://97059193661551",
			MoneyPerSec = 8_250,
			Rarity = RarityConfiguration.Epic,
		},

		GiganticWave_Epic = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://97059193661551",
			MoneyPerSec = 11_000,
			Rarity = RarityConfiguration.Epic,
		},
	},

	-- =======================
	-- Legendary
	-- =======================
	Legendary = {
		MiniWave_Legendary = {
			DisplayName = "Mini Wave",
			Icon = "rbxassetid://118632376815849",
			MoneyPerSec = 2_500,
			Rarity = RarityConfiguration.Legendary,
		},

		SmallWave_Legendary = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://118632376815849",
			MoneyPerSec = 7_500,
			Rarity = RarityConfiguration.Legendary,
		},

		MediumWave_Legendary = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://118632376815849",
			MoneyPerSec = 15_000,
			Rarity = RarityConfiguration.Legendary,
		},

		LargeWave_Legendary = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://118632376815849",
			MoneyPerSec = 25_000,
			Rarity = RarityConfiguration.Legendary,
		},

		HugeWave_Legendary = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://118632376815849",
			MoneyPerSec = 37_500,
			Rarity = RarityConfiguration.Legendary,
		},

		GiganticWave_Legendary = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://118632376815849",
			MoneyPerSec = 50_000,
			Rarity = RarityConfiguration.Legendary,
		},
	},

	-- =======================
	-- Mythic
	-- =======================
	Mythic = {
		MiniWave_Mythic = {
			DisplayName = "Mini Wave",
			Icon = "rbxassetid://126496380378878",
			MoneyPerSec = 12_500,
			Rarity = RarityConfiguration.Mythic,
		},

		SmallWave_Mythic = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://126496380378878",
			MoneyPerSec = 37_500,
			Rarity = RarityConfiguration.Mythic,
		},

		MediumWave_Mythic = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://126496380378878",
			MoneyPerSec = 75_000,
			Rarity = RarityConfiguration.Mythic,
		},

		LargeWave_Mythic = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://126496380378878",
			MoneyPerSec = 125_000,
			Rarity = RarityConfiguration.Mythic,
		},

		HugeWave_Mythic = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://126496380378878",
			MoneyPerSec = 187_500,
			Rarity = RarityConfiguration.Mythic,
		},

		GiganticWave_Mythic = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://126496380378878",
			MoneyPerSec = 250_000,
			Rarity = RarityConfiguration.Mythic,
		},
	},

	-- =======================
	-- Secret
	-- =======================
	Secret = {
		SmallWave_Secret = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://87734398690152",
			MoneyPerSec = 260_000,
			Rarity = RarityConfiguration.Secret,
		},

		MediumWave_Secret = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://87734398690152",
			MoneyPerSec = 300_000,
			Rarity = RarityConfiguration.Secret,
		},

		LargeWave_Secret = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://87734398690152",
			MoneyPerSec = 320_000,
			Rarity = RarityConfiguration.Secret,
		},

		HugeWave_Secret = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://87734398690152",
			MoneyPerSec = 325_000,
			Rarity = RarityConfiguration.Secret,
		},

		GiganticWave_Secret = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://87734398690152",
			MoneyPerSec = 350_000,
			Rarity = RarityConfiguration.Secret,
		},
	},

	Celestial = {
		SmallWave_Celestial = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://136921259720236",
			MoneyPerSec = 375_000,
			Rarity = RarityConfiguration.Celestial,
		},

		MediumWave_Celestial = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://136921259720236",
			MoneyPerSec = 399_000,
			Rarity = RarityConfiguration.Celestial,
		},

		LargeWave_Celestial = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://136921259720236",
			MoneyPerSec = 400_000,
			Rarity = RarityConfiguration.Celestial,
		},

		HugeWave_Celestial = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://136921259720236",
			MoneyPerSec = 425_000,
			Rarity = RarityConfiguration.Celestial,
		},

		GiganticWave_Celestial = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://136921259720236",
			MoneyPerSec = 450_000,
			Rarity = RarityConfiguration.Celestial,
		},
	},

	Fire = {
		SmallWave_Fire = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://84556238171161",
			MoneyPerSec = 475_000,
			Rarity = RarityConfiguration.Fire,
		},

		MediumWave_Fire = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://84556238171161",
			MoneyPerSec = 500_000,
			Rarity = RarityConfiguration.Fire,
		},

		LargeWave_Fire = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://84556238171161",
			MoneyPerSec = 550_000,
			Rarity = RarityConfiguration.Fire,
		},

		HugeWave_Fire = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://84556238171161",
			MoneyPerSec = 575_000,
			Rarity = RarityConfiguration.Fire,
		},

		GiganticWave_Fire = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://84556238171161",
			MoneyPerSec = 600_000,
			Rarity = RarityConfiguration.Fire,
		},
	},

	Abyssal = {
		SmallWave_Abyssal = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://113501184771496",
			MoneyPerSec = 625_000,
			Rarity = RarityConfiguration.Abyssal,
		},

		MediumWave_Abyssal = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://113501184771496",
			MoneyPerSec = 650_000,
			Rarity = RarityConfiguration.Abyssal,
		},

		LargeWave_Abyssal = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://113501184771496",
			MoneyPerSec = 675_000,
			Rarity = RarityConfiguration.Abyssal,
		},

		HugeWave_Abyssal = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://113501184771496",
			MoneyPerSec = 700_000,
			Rarity = RarityConfiguration.Abyssal,
		},

		GiganticWave_Abyssal = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://113501184771496",
			MoneyPerSec = 725_000,
			Rarity = RarityConfiguration.Abyssal,
		},
	},

	Void = {
		SmallWave_Void = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://120621392445944",
			MoneyPerSec = 750_000,
			Rarity = RarityConfiguration.Void,
		},

		MediumWave_Void = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://120621392445944",
			MoneyPerSec = 775_000,
			Rarity = RarityConfiguration.Void,
		},

		LargeWave_Void = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://120621392445944",
			MoneyPerSec = 800_000,
			Rarity = RarityConfiguration.Void,
		},

		HugeWave_Void = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://120621392445944",
			MoneyPerSec = 825_000,
			Rarity = RarityConfiguration.Void,
		},

		GiganticWave_Void = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://120621392445944",
			MoneyPerSec = 850_000,
			Rarity = RarityConfiguration.Void,
		},
	},

	Ancient = {
		SmallWave_Ancient = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://98816571105602",
			MoneyPerSec = 875_000,
			Rarity = RarityConfiguration.Ancient,
		},

		MediumWave_Ancient = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://98816571105602",
			MoneyPerSec = 900_000,
			Rarity = RarityConfiguration.Ancient,
		},

		LargeWave_Ancient = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://98816571105602",
			MoneyPerSec = 925_000,
			Rarity = RarityConfiguration.Ancient,
		},

		HugeWave_Ancient = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://98816571105602",
			MoneyPerSec = 950_000,
			Rarity = RarityConfiguration.Ancient,
		},

		GiganticWave_Ancient = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://98816571105602",
			MoneyPerSec = 975_000,
			Rarity = RarityConfiguration.Ancient,
		},
	},

	Neon = {
		SmallWave_Neon = {
			DisplayName = "Small Wave",
			Icon = "rbxassetid://133264531236585",
			MoneyPerSec = 1_000_000,
			Rarity = RarityConfiguration.Neon,
		},

		MediumWave_Neon = {
			DisplayName = "Medium Wave",
			Icon = "rbxassetid://133264531236585",
			MoneyPerSec = 1_025_000,
			Rarity = RarityConfiguration.Neon,
		},

		LargeWave_Neon = {
			DisplayName = "Large Wave",
			Icon = "rbxassetid://133264531236585",
			MoneyPerSec = 1_050_000,
			Rarity = RarityConfiguration.Neon,
		},

		HugeWave_Neon = {
			DisplayName = "Huge Wave",
			Icon = "rbxassetid://133264531236585",
			MoneyPerSec = 1_075_000,
			Rarity = RarityConfiguration.Neon,
		},

		GiganticWave_Neon = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://133264531236585",
			MoneyPerSec = 1_100_000,
			Rarity = RarityConfiguration.Neon,
		},
	},

	-- =======================
	-- Premium
	-- =======================
	Premium = {
		GiganticWave_Celestial = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://89649824047024",
			MoneyPerSec = 350_000,
			Rarity = RarityConfiguration.Celestial,
		},

		GiganticWave_Fire = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://80443195955749",
			MoneyPerSec = 400_000,
			Rarity = RarityConfiguration.Fire,
		},

		GiganticWave_Rainbow = {
			DisplayName = "Gigantic Wave",
			Icon = "rbxassetid://119329112873753",
			MoneyPerSec = 5_000_000,
			Rarity = RarityConfiguration.Rainbow,
		},
	},
}
