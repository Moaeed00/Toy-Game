--// init.server.lua
--// Boots Knit server and loads all services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)

print("[KnitServer] Adding services (deep) from:", ServerScriptService.KnitServer:GetFullName())
Knit.AddServicesDeep(ServerScriptService.KnitServer)

Knit.Start():andThen(function()
	print("[KnitServer] Knit started")
end):catch(function(err)
	warn("[KnitServer] Knit failed to start:", err)
end)
