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
    local rootPart = character:WaitForChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        return
    end

	self.NPCService:EnableRagdoll():andThen(function(canRagdoll: boolean)
		if not canRagdoll then
			return
		end

		local healthBefore = humanoid.Health

        humanoid:ChangeState(Enum.HumanoidStateType.Physics)

        local protecting = true
        task.spawn(function()
            while protecting and humanoid and humanoid.Parent do
                if humanoid.Health < healthBefore then
                    humanoid.Health = healthBefore
                end
                task.wait()
            end
        end)

        task.delay(RAGDOLL_DURATION, function()
            protecting = false

            rootPart.AssemblyLinearVelocity = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end)
end

return RagdollController