--!strict
--// File: ReplicatedStorage/Configuration/PvPToolsConfig.lua
--// PvPToolsConfig.lua
--// Fully aligned with CombatMovementConfig ragdoll system

local PvPToolsConfig = {}

PvPToolsConfig.DEBUG_PRINTS = true

PvPToolsConfig.PUNCH_TOOL_NAME = "Punch"
PvPToolsConfig.GOLDEN_PUNCH_TOOL_NAME = "Golden Punch"

PvPToolsConfig.PUNCH_HITBOX_SIZE = Vector3.new(12, 8, 12)
PvPToolsConfig.PUNCH_HITBOX_FORWARD_OFFSET = 6

PvPToolsConfig.PUNCH_COOLDOWN = 0.8

PvPToolsConfig.DEFAULT_BUMP_POWER = 80
PvPToolsConfig.DEFAULT_BUMP_UP = 14
PvPToolsConfig.DEFAULT_KNOCKBACK_DISTANCE = 20

-- 1 = strong diagonal
-- 0.7 = softer diagonal
PvPToolsConfig.FRONT_LEFT_MULTIPLIER = 1

--// Ragdoll Timing
PvPToolsConfig.RAGDOLL_VELOCITY_THRESHOLD = 1.5
PvPToolsConfig.RAGDOLL_STABLE_DELAY = 1.0

--// Emergency safety timeout (extra protection)
PvPToolsConfig.RAGDOLL_MAX_DURATION = 4

PvPToolsConfig.HEAD_UPPER_ANGLE = 2
PvPToolsConfig.HEAD_TWIST_LIMIT = 2

PvPToolsConfig.BODY_UPPER_ANGLE = 20
PvPToolsConfig.BODY_TWIST_LIMIT = 20

PvPToolsConfig.DEBUG_SHOW_PUNCH_HITBOX = true
PvPToolsConfig.DEBUG_PUNCH_HITBOX_TRANSPARENCY = 0.5

return PvPToolsConfig