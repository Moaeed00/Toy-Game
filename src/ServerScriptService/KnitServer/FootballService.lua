local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local FootballsConfig = require(ReplicatedStorage.Configurations.FootballsConfig)
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Football: Tool = Assets.Tools:WaitForChild("Basic_Football")
local Knit = require(ReplicatedStorage.Packages.Knit)

local FootballService = Knit.CreateService {
    Name = "FootballService",
    Client = {
        EquipBallEvent = Knit.CreateSignal(),
        KickBallEvent = Knit.CreateSignal(),
        UnequipBallEvent = Knit.CreateSignal(),
    },
}

function FootballService:KnitInit()
end

function FootballService:KnitStart()
    FootballService.KICK_RANGE = 7.5
    FootballService.FRONT_DISTANCE = 2.5
    FootballService.Footballs = {}
    FootballService.IsKicking = {}

    if not PhysicsService:IsCollisionGroupRegistered("Football") then
        PhysicsService:RegisterCollisionGroup("Football")
    end
    PhysicsService:CollisionGroupSetCollidable("MiniBlocks", "Football", false)

    self.Client.EquipBallEvent:Connect(function(player: Player)
        self:EquipBall(player)
    end)

    self.Client.KickBallEvent:Connect(function(player: Player, ballPosition: Vector3)
        self:KickBall(player, ballPosition)
    end)

    self.Client.UnequipBallEvent:Connect(function(player: Player)
        self:UnequipBall(player)
    end)
end

function FootballService:EquipBall(player: Player)
    if self.IsKicking[player] then
        return
    end

    local character = player.Character
    if not character then
        return
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local footballTool = self.Footballs[player]
    if not footballTool then
        return
    end
    local ball = footballTool:WaitForChild("Handle"):WaitForChild("Basic_Football")
    ball.Anchored = false
    ball.CanCollide = false

    if ball:FindFirstChild("BallWeld") then
        ball.BallWeld:Destroy()
    end

    local lookDirection = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
    local frontPosition = Vector3.new(root.Position.X, root.Position.Y - 2, root.Position.Z) + (lookDirection * self.FRONT_DISTANCE)
    ball.CFrame = CFrame.new(frontPosition)

    local weld = Instance.new("WeldConstraint")
    weld.Name = "BallWeld"
    weld.Part0 = ball
    weld.Part1 = root
    weld.Parent = ball
end

function FootballService:KickBall(player: Player, ballPosition: Vector3)
    if self.IsKicking[player] then
        return
    end
    self.IsKicking[player] = true

    if not player.Character then
        return
    end

    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local footballTool = self.Footballs[player]
    local ball = footballTool:WaitForChild("Handle"):WaitForChild("Basic_Football")

    if ball:FindFirstChild("BallWeld") then
        ball.BallWeld:Destroy()
    end
    ball.Anchored = false
    ball.CanCollide = true
    ball.CanTouch = true
    ball:PivotTo(CFrame.new(ballPosition))

    local lookDirection = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
    local kickTarget = ballPosition + (lookDirection * self.KICK_RANGE)

    local attachment = Instance.new("Attachment")
    attachment.Parent = ball

    local align = Instance.new("AlignPosition")
    align.Attachment0 = attachment
    align.Mode = Enum.PositionAlignmentMode.OneAttachment
    align.MaxForce = math.huge
    align.Responsiveness = 40 -- higher = faster (like tween speed)
    align.Position = kickTarget
    align.Parent = ball

    task.wait(0.4) -- forward movement duration

    if root and root.Parent then
        local returnPosition = Vector3.new(root.Position.X, root.Position.Y - 2, root.Position.Z) + (lookDirection * self.FRONT_DISTANCE)
        align.Position = returnPosition
        task.wait(0.4)
    end

    align:Destroy()
    attachment:Destroy()
    self.IsKicking[player] = false

    self:EquipBall(player)
end

function FootballService:UnequipBall(player: Player)
    self.IsKicking[player] = false
end

function FootballService.Client:GiveFootball(player: Player)
    local footballTool: Tool = Football:Clone()
    footballTool.Parent = player.Backpack
    self.Server.Footballs[player] = footballTool

    local handle: Part = footballTool:WaitForChild("Handle")
    local ball: MeshPart = handle:WaitForChild("Basic_Football")
    ball.Anchored = true
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

return FootballService