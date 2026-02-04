local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local FootballController = Knit.CreateController { Name = "FootballController" }

function FootballController:KnitInit()
end

function FootballController:KnitStart()
    FootballController.FootballService = Knit.GetService("FootballService")

    task.wait(2)
    self:OnFootballToolTriggered()
end

function FootballController:OnFootballToolTriggered()
    self.FootballService:GiveFootball():andThen(function(football: Tool)
        local ball: MeshPart = football:WaitForChild("Handle")

        football.Equipped:Connect(function()
        end)

        football.Activated:Connect(function()
            self.FootballService:KickBall(ball)
        end)

        football.Unequipped:Connect(function()
        end)
    end)
end

return FootballController