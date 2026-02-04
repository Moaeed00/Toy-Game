local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootballsConfig = require(ReplicatedStorage.Configurations.FootballsConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)

local FootballController = Knit.CreateController { Name = "FootballController" }

function FootballController:KnitInit()
end

function FootballController:KnitStart()
    FootballController.FootballService = Knit.GetService("FootballService")

    task.wait(1)
    self:OnFootballToolTriggered()
end

function FootballController:OnFootballToolTriggered()
    self.FootballService:GiveFootball():andThen(function(football: Tool)
        local ball: MeshPart = football:WaitForChild("Handle")

        football.Equipped:Connect(function()
        end)

        football.Activated:Connect(function()
            local character = football.Parent
            local root = character:FindFirstChild("HumanoidRootPart")
			if not root then
                return
            end

            ball.CanCollide = true
            self:SetHitPower(ball)
            self.FootballService:KickBall(ball)
        end)

        football.Unequipped:Connect(function()
        end)
    end)
end

function FootballController:SetHitPower(ball: MeshPart)
    for index, footballToolData in ipairs(FootballsConfig) do
        if footballToolData.Name == ball.Name then
            ball:SetAttribute("ToolType", "Football")
            ball:SetAttribute("HitPower", footballToolData.Power)
        end
    end
end

return FootballController