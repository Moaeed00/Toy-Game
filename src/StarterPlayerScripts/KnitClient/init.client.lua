--// init.client.lua
--// Boots Knit client and loads all controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

print("[KnitClient] Adding controllers (deep) from:", script.Parent:GetFullName())
Knit.AddControllersDeep(script.Parent.Controllers)

Knit.Start():andThen(function()
	print("[KnitClient] Knit Client Started!")
end):catch(function(err)
	warn("[KnitClient] Knit Client failed to start:", err)
end)
