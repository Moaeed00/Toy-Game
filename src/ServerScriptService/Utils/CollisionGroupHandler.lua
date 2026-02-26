local PhysicsService = game:GetService("PhysicsService")

local CollisionGroupHandler = {}

local PlayerCollisionGroup = "Player"
local FootBallCollisionGroup = "FootBall"

PhysicsService:RegisterCollisionGroup(PlayerCollisionGroup)
PhysicsService:RegisterCollisionGroup(FootBallCollisionGroup)
PhysicsService:CollisionGroupSetCollidable(PlayerCollisionGroup, FootBallCollisionGroup, false)
PhysicsService:CollisionGroupSetCollidable(PlayerCollisionGroup, PlayerCollisionGroup, false)

function CollisionGroupHandler:AddCollisionGroup(CollisionGroupName: string, Parts: Instance)
	if Parts:IsA("BasePart") or Parts:IsA("MeshPart") then
		Parts.CollisionGroup = CollisionGroupName
	end

	for _, Part in pairs(Parts:GetDescendants()) do
		if Part:IsA("BasePart") or Part:IsA("MeshPart") then
			Part.CollisionGroup = CollisionGroupName
		end
	end
end

return CollisionGroupHandler
