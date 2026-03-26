local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)

local RagdollController = Knit.CreateController { Name = "RagdollController" }

local RAGDOLL_DURATION = 1.5

function RagdollController:KnitInit()
end

function RagdollController:KnitStart()
    RagdollController.NPCService = Knit.GetService("NPCService")

    self.NPCService.ActivatePlayerRagdollEvent:Connect(function()
        self:DoRagdoll()
    end)
end

function RagdollController:DoRagdoll()
    local character = Player.Character
    local humanoid = character:WaitForChild("Humanoid")
    if not humanoid then
        return
    end

	self.NPCService:EnableRagdoll():andThen(function(canRagdoll: boolean)
        if canRagdoll then
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            task.delay(RAGDOLL_DURATION, function()
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end)
        end
    end)
end

return RagdollController