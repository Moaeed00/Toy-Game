local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local KickAnimation: Animation = Assets.Animations.Kick_with_Event

local FootballController = Knit.CreateController { Name = "FootballController" }

function FootballController:KnitInit()
end

function FootballController:KnitStart()
    FootballController.FootballService = Knit.GetService("FootballService")

    FootballController.IsKicking = false

    task.wait(2)
    self:OnFootballToolTriggered()
end

function FootballController:OnFootballToolTriggered()
    local character: Model = Player.Character
	local humanoid: Humanoid = character:WaitForChild("Humanoid")

    self.FootballService:GiveFootball():andThen(function(football: Tool)
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

            local currentBallPosition = ball.CFrame.Position
            local track = self:PlayKickBallAnimation(humanoid)

            track:GetMarkerReachedSignal("KickMoment"):Once(function()
                self.FootballService.KickBallEvent:Fire(currentBallPosition)
            end)

            track.Stopped:Once(function()
                self.IsKicking = false
            end)
        end)

        football.Unequipped:Connect(function()
            self.FootballService.UnequipBallEvent:Fire()
        end)
    end)
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