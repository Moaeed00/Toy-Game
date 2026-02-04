local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Football: Tool = Assets.Tools:WaitForChild("Basic_Football")
local Knit = require(ReplicatedStorage.Packages.Knit)

local FootballService = Knit.CreateService {
    Name = "FootballService",
    Client = {},
}

function FootballService:KnitInit()
end

function FootballService:KnitStart()
    FootballService.KICK_RANGE = 10
end

function FootballService.Client:GiveFootball(player: Player)
    local footballTool: Tool = Football:Clone()
    footballTool.Parent = player.Backpack
    return footballTool
end

function FootballService.Client:KickBall(player: Player, ball: MeshPart)
    if not player.Character or not ball then
        return
    end

    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    ball.Anchored = true
    local lockedY = ball.Position.Y
    local rootFrontPosition: Vector3 = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)

    local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local ballStartCFrame = Vector3.new(ball.Position.X, lockedY, ball.Position.Z)
    local kickTarget = ballStartCFrame + (rootFrontPosition * FootballService.KICK_RANGE)
    local kickTween = TweenService:Create(ball, tweenInfo, { Position = kickTarget })
    kickTween:Play()
    kickTween.Completed:Wait()

    local frontDistance = 2.5
    local lookXZ: Vector3 = rootFrontPosition.Unit
    local returnPosition = Vector3.new(root.Position.X, lockedY, root.Position.Z) + (lookXZ * frontDistance)
    local returnTween = TweenService:Create(ball, tweenInfo, { Position = returnPosition })
    returnTween:Play()
    returnTween.Completed:Wait()
end


return FootballService