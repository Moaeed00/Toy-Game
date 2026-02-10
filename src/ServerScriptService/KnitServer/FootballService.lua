local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FootballsConfig = require(ReplicatedStorage.Configurations.FootballsConfig)
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
    FootballService.KICK_RANGE = 7.5
    FootballService.FRONT_DISTANCE = 2.5
end

function FootballService.Client:GiveFootball(player: Player)
    local footballTool: Tool = Football:Clone()
    footballTool.Parent = player.Backpack

    local handle: Part = footballTool:WaitForChild("Handle")
    local ball: MeshPart = handle:WaitForChild("Basic_Football")
    ball.Transparency = 1
    ball.Anchored = true
    ball.CanCollide = false

    self:SetHitPower(ball)

    return footballTool
end

function FootballService.Client:SetHitPower(ball: MeshPart)
    for index, footballToolData in ipairs(FootballsConfig) do
        if footballToolData.Name == ball.Name then
            CollectionService:AddTag(ball, "Football")
            ball:SetAttribute("HitPower", footballToolData.Power)
        end
    end
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
    ball.CanCollide = true

    local startPosition: Vector3 = ball.Position
    local lookDirection: Vector3 = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit

    -- local startPosition: Vector3 = Vector3.new(root.CFrame.Position.X, 2, root.CFrame.Position.Z)
    -- local lookDirection: Vector3 = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit

    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local kickTarget: Vector3 = startPosition + (lookDirection * self.Server.KICK_RANGE)
    local kickTween = TweenService:Create(ball, tweenInfo, { Position = kickTarget })
    kickTween:Play()
    kickTween.Completed:Wait()

    if root and root.Parent then
        local returnLookDirection = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
        local returnPosition = Vector3.new(root.Position.X, 2, root.Position.Z) + (returnLookDirection * self.Server.FRONT_DISTANCE)

        local returnTween = TweenService:Create(ball, tweenInfo, { Position = returnPosition })
        returnTween:Play()
        returnTween.Completed:Wait()
    end

    ball.CanCollide = false
end

return FootballService