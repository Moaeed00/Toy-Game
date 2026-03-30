local PhysicsService = game:GetService("PhysicsService")

local CollisionGroupHandler = {}

local PlayerCollisionGroup = "Player"
local FootBallCollisionGroup = "FootBall"
local MiniGameWallCollisionGroup = "MiniGameWall"
local MiniBlocksCollisionGroup = "MiniBlocks"
local BlocksCollisionGroup = "Blocks"
local NPCCollisionGroup = "NPC"

PhysicsService:RegisterCollisionGroup(PlayerCollisionGroup)
PhysicsService:RegisterCollisionGroup(FootBallCollisionGroup)
PhysicsService:RegisterCollisionGroup(MiniBlocksCollisionGroup)
PhysicsService:RegisterCollisionGroup(MiniGameWallCollisionGroup)
PhysicsService:RegisterCollisionGroup(BlocksCollisionGroup)
PhysicsService:RegisterCollisionGroup(NPCCollisionGroup)

PhysicsService:CollisionGroupSetCollidable(PlayerCollisionGroup, FootBallCollisionGroup, false)
PhysicsService:CollisionGroupSetCollidable(PlayerCollisionGroup, PlayerCollisionGroup, false)
PhysicsService:CollisionGroupSetCollidable(FootBallCollisionGroup, MiniGameWallCollisionGroup, false)
PhysicsService:CollisionGroupSetCollidable(MiniBlocksCollisionGroup, MiniBlocksCollisionGroup, false)
PhysicsService:CollisionGroupSetCollidable(MiniBlocksCollisionGroup, FootBallCollisionGroup, false)
PhysicsService:CollisionGroupSetCollidable(MiniBlocksCollisionGroup, BlocksCollisionGroup, false)
PhysicsService:CollisionGroupSetCollidable(NPCCollisionGroup, BlocksCollisionGroup, false)

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
