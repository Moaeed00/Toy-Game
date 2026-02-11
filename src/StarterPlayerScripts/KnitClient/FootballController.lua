local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

        ball.Transparency = 1
        ball.Anchored = true
        ball.CanCollide = false

        local updateConnection
        local isKicking = false

        football.Equipped:Connect(function()
            local character = football.Parent
            local root = character:FindFirstChild("HumanoidRootPart")
            if not root then
                return
            end

            isKicking = false
            ball.Anchored = true
            ball.CanCollide = false

            local frontDistance = 2.5
            local lookDirection = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
            local frontPosition = Vector3.new(root.Position.X, root.Position.Y - 2, root.Position.Z) + (lookDirection * frontDistance)
            ball.CFrame = CFrame.new(frontPosition)
            ball.Transparency = 0

            if updateConnection then
                updateConnection:Disconnect()
            end
            updateConnection = RunService.Heartbeat:Connect(function()
                if not root or not root.Parent then
                    if updateConnection then
                        updateConnection:Disconnect()
                        updateConnection = nil
                    end
                    return
                end

                if not isKicking then
                    local currentLookDirection = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
                    local currentFrontPosition = Vector3.new(root.Position.X, root.Position.Y - 2, root.Position.Z) + (currentLookDirection * frontDistance)

                    ball.CFrame = CFrame.new(currentFrontPosition)
                end
            end)
        end)

        football.Activated:Connect(function()
            if isKicking then
                return
            end
            isKicking = true

            task.spawn(function()
                local currentBallPosition = ball.CFrame.Position
                self.FootballService:KickBall(ball, currentBallPosition)
                task.wait(0.9)
                isKicking = false
            end)
        end)

        football.Unequipped:Connect(function()
            if updateConnection then
                updateConnection:Disconnect()
                updateConnection = nil
            end

            ball.Transparency = 1
            isKicking = false
        end)
    end)
end

return FootballController