local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Utils: Folder = ServerScriptService:WaitForChild("Utils")
local CollisionGroupHandler: {} = require(Utils:WaitForChild("CollisionGroupHandler"))
local FootballUtils = require(ReplicatedStorage.Configuration.Footballs.FootballUtils)
local DataStoreHandler = require(script.Parent.DataHandlerService)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Assets = ReplicatedStorage:WaitForChild("Assets")
local FootballsFolder = Assets.Tools:WaitForChild("Footballs")

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
    FootballService.FRONT_DISTANCE = 2
    FootballService.Footballs = {}
    FootballService.IsKicking = {}

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
    local playerData = DataStoreHandler:GetPlayerData(player)
    if not playerData then
        return
    end

    local equippedId = playerData.Footballs.Equipped
    local footballName, _footballData = FootballUtils:GetFootballById(equippedId)

    local handle = footballTool:WaitForChild("Handle")
    local ball: Part = handle:WaitForChild(footballName)
    ball.Anchored = false
    ball.CanCollide = false
    ball.CanTouch = false

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

    CollisionGroupHandler:AddCollisionGroup("FootBall", footballTool)
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
    local playerData = DataStoreHandler:GetPlayerData(player)
    if not playerData then
        return
    end

    local equippedId = playerData.Footballs.Equipped
    local footballName, _footballData = FootballUtils:GetFootballById(equippedId)

    local handle = footballTool:WaitForChild("Handle")
    local ball: Part = handle:WaitForChild(footballName)
    if ball:FindFirstChild("Weld") then
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

    task.wait(0.43) -- forward movement duration

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
    local playerData = DataStoreHandler:GetPlayerData(player)
    if not playerData then
        return
    end

    local equippedFootballId = playerData.Footballs.Equipped
    local footballName, footballData = FootballUtils:GetFootballById(equippedFootballId)
    if not footballName then
        warn("Football id not found:", equippedFootballId)
        return
    end

    local toolTemplate = FootballsFolder:FindFirstChild(footballName)
    if not toolTemplate then
        warn("Football tool missing:", footballName)
        return
    end

     -- remove previous tool
    if self.Server.Footballs[player] then
        self.Server.Footballs[player]:Destroy()
    end

    local footballTool: Tool = toolTemplate:Clone()
    footballTool.Parent = player.Backpack
    self.Server.Footballs[player] = footballTool

    local ball: MeshPart = footballTool:WaitForChild("Handle"):WaitForChild(footballName)
    ball.Anchored = true

    CollectionService:AddTag(ball, "Football")
    ball:SetAttribute("HitPower", footballData.Power)

    return footballTool
end

return FootballService