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
end

function FootballService.Client:GiveFootball(player: Player)
    local footballTool: Tool = Football:Clone()
    footballTool.Parent = player.Backpack

    local handle: Part = footballTool:WaitForChild("Handle")
    local ball: MeshPart = handle:WaitForChild("Basic_Football")
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

    ball.Anchored = true

    local startPosition: Vector3 = ball.Parent.CFrame.Position
    local lookDirection: Vector3 = Vector3.new(ball.Parent.CFrame.LookVector.X, 0, ball.Parent.CFrame.LookVector.Z).Unit
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local kickTarget: Vector3 = Vector3.new(startPosition.X, startPosition.Y, startPosition.Z) + (lookDirection * self.Server.KICK_RANGE)
    local kickTween = TweenService:Create(ball, tweenInfo, { Position = kickTarget })
    kickTween:Play()
    kickTween.Completed:Wait()

    local returnTween = TweenService:Create(ball, tweenInfo, { Position = startPosition })
    returnTween:Play()
    returnTween.Completed:Wait()
end

return FootballService