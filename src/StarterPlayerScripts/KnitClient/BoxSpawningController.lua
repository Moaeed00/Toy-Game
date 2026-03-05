local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local BoxSpawningController = Knit.CreateController { Name = "BoxSpawningController" }

function BoxSpawningController:KnitInit()
end

function BoxSpawningController:KnitStart()
end

return BoxSpawningController