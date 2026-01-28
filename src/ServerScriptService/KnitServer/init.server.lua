local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddServices(ServerScriptService.KnitServer)

Knit.Start():andThen(function()
    print("Knit started")
end):catch(warn)