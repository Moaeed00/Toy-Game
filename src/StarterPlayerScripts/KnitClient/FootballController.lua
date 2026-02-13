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
        local handle: Part = football:WaitForChild("Handle")
        local ball: MeshPart = handle:WaitForChild("Basic_Football")

        football.Equipped:Connect(function()
            self.FootballService.EquipBallEvent:Fire()
        end)

        football.Activated:Connect(function()
            local currentBallPosition = ball.CFrame.Position
            self.FootballService.KickBallEvent:Fire(currentBallPosition)
        end)

        football.Unequipped:Connect(function()
            self.FootballService.UnequipBallEvent:Fire()
        end)
    end)
end

return FootballController