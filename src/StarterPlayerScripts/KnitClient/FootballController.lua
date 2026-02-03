local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local FootballController = Knit.CreateController { Name = "FootballController" }

function FootballController:KnitInit()
end

function FootballController:KnitStart()
    FootballController.FootballService = Knit.GetService("FootballService")

    task.wait(3)
    self:OnFootballToolTriggered()
end

function FootballController:OnFootballToolTriggered()
    self.FootballService:GiveFootball():andThen(function(football: Tool)
        local ball: MeshPart = football:WaitForChild("Football")

        football.Equipped:Connect(function()
            ball.Transparency = 1
            ball.CanCollide = false
        end)

        football.Activated:Connect(function()
            local character = football.Parent
            local root = character:FindFirstChild("HumanoidRootPart")
			if not root then
                return
            end

            ball.CFrame = root.CFrame * CFrame.new(0, -2, -3)
            ball.Parent = workspace
            ball.Transparency = 0
            ball.CanCollide = true

            football:Destroy()

            self.FootballService:KickBall(ball)
        end)

        football.Unequipped:Connect(function()
        end)
    end)
end

return FootballController