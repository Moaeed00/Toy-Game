local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)
-- local BackpackSorter = require(ReplicatedStorage.Utility.BackpackSorter)
local FootballsConfig = require(ReplicatedStorage.Configuration.Footballs.FootballsConfig)
local Assets = ReplicatedStorage:WaitForChild("Assets")
local KickAnimation: Animation = Assets.Animations.Kick_with_Event
local KickImpactParticle = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("CamParticles"):WaitForChild("KickImpact")

local FootballController = Knit.CreateController { Name = "FootballController" }

function FootballController:KnitInit()
end

function FootballController:KnitStart()
    FootballController.FootballService = Knit.GetService("FootballService")
    FootballController.IsKicking = false

    local character: Model = Player.Character or Player.CharacterAdded:Wait()
    local humanoid: Humanoid = character:WaitForChild("Humanoid")

    -- listen for any football tool added to the backpack (covers both
    -- initial spawn and shop purchases) instead of connecting once at startup
    Player.Backpack.ChildAdded:Connect(function(tool: Tool)
        if not tool:IsA("Tool") or not FootballsConfig[tool.Name] then
            return
        end
        self:ConnectFootballTool(tool, humanoid)
    end)

    task.wait(2)
    self.FootballService:GiveFootball():andThen(function(_football: Tool)
        -- BackpackSorter.Sort(Player)
    end)
end

function FootballController:ConnectFootballTool(football: Tool, humanoid: Humanoid)
    -- local handle: Part = football:FindFirstChild("Handle") or football:FindFirstChild("HandlePoint")
    local handle: Part = football:WaitForChild("Handle")
    local ball: MeshPart = handle:WaitForChild(football.Name)

    football.Equipped:Connect(function()
        self.FootballService.EquipBallEvent:Fire()
    end)

    football.Activated:Connect(function()
        if self.IsKicking then
            return
        end
        self.IsKicking = true

        local mouse = Player:GetMouse()
        local mouseHitPosition = mouse.Hit.Position
        task.wait(0.05)
        local track = self:PlayKickBallAnimation(humanoid)

        track:GetMarkerReachedSignal("KickMoment"):Once(function()
            local currentBallPosition = ball.CFrame.Position
            self:PlayKickParticle(humanoid.Parent)
            self.FootballService.KickBallEvent:Fire(currentBallPosition, mouseHitPosition)
        end)

        track.Stopped:Once(function()
            self.IsKicking = false
        end)
    end)

    football.Unequipped:Connect(function()
        self.FootballService.UnequipBallEvent:Fire()
    end)
end

function FootballController:PlayKickParticle(character: Model)
    local root: BasePart = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local impact: Model = KickImpactParticle:Clone()

    local groundCFrame = CFrame.new(root.Position - Vector3.new(0, 2.5, 0))
    for _, part in ipairs(impact:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
            part.CanTouch = false
            part.CFrame = groundCFrame
        end
    end
    impact.Parent = workspace

    for _, descendant in ipairs(impact:GetDescendants()) do
        if descendant:IsA("ParticleEmitter") then
            descendant:Emit(1)
        end
    end
    Debris:AddItem(impact, 0.475)
end

function FootballController:PlayKickBallAnimation(humanoid: Humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
    local animationTrack = animator:LoadAnimation(KickAnimation)
    animationTrack.Looped = false
    animationTrack:AdjustSpeed(1)
	animationTrack:Play()

    return animationTrack
end

return FootballController