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
            local character = football.Parent
            local root = character:FindFirstChild("HumanoidRootPart")
            if not root then
                return
            end

            local frontDistance = 2.5
            local lookDirection = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
            local frontPosition = Vector3.new(root.Position.X, 2, root.Position.Z) + (lookDirection * frontDistance)

            ball.Position = frontPosition
            ball.Transparency = 0
            ball.Anchored = true
            ball.CanCollide = true
        end)

        football.Activated:Connect(function()
            self.FootballService:KickBall(ball)
        end)

        football.Unequipped:Connect(function()
        end)
    end)
end

return FootballController