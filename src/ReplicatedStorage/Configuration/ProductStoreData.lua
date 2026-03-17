local ProductStoreData = {
	["E1"] = {
		Title = "Starter Pack",
		Price = 9,
		Id = 3465786864,
		Type = "Bundle",
		RewardData = {
			{ Type = "Money", Data = { Amount = 2_500 } },
			{ Type = "Brainrot", Data = { Name = "Fluri Flura", Rarity = "Common", Mutation = "Lava" } },
			{ Type = "Brainrot", Data = { Random = true } },
		},
	},
	["E2"] = {
		Title = "$5,000 Cash",
		Price = 9,
		Id = 3465787348,
		Type = "Money",
		RewardData = {
			Amount = 5_000,
		},
	},
	["E3"] = {
		Title = "$25,000 Cash",
		Price = 29,
		Id = 3465787479,
		Type = "Money",
		RewardData = {
			Amount = 25_000,
		},
	},
	["E4"] = {
		Title = "$100,000 Cash",
		Price = 69,
		Id = 3465787762,
		Type = "Money",
		RewardData = {
			Amount = 100_000,
		},
	},
	["E5"] = {
		Price = 599,
		Title = "$1,000,000 Cash",
		Id = 3486130019,
		Type = "Money",
		RewardData = {
			Amount = 1_000_000,
		},
	},
}

return ProductStoreData
