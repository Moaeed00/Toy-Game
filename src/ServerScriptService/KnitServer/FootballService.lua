local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Football: Tool = Assets.Tools.Football

local FootballService = Knit.CreateService {
    Name = "FootballService",
    Client = { },
}

function FootballService:KnitInit()
end

function FootballService:KnitStart()
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

    local direction = root.CFrame.LookVector
	local impulse = direction * ball.AssemblyMass * 100 + Vector3.new(0, ball.AssemblyMass * 40, 0)

	ball:ApplyImpulse(impulse)
end

return FootballService