--!strict
--// File: ReplicatedStorage/Configuration/CombatMovementConfig.lua

local CombatMovementConfig = {}

CombatMovementConfig.DEBUG_PRINTS = true
CombatMovementConfig.INPUT_MODE = "Tool"

--// SLIDE TOOL NAMES
CombatMovementConfig.SLIDE_TOOL_NAME = "Slide"
CombatMovementConfig.GOLDEN_SLIDE_TOOL_NAME = "Golden Slide"

--// Slide Cooldown
CombatMovementConfig.SLIDE_COOLDOWN = 1.5

--// Slide Movement Settings
CombatMovementConfig.SLIDE_DURATION = 0.9
CombatMovementConfig.SLIDE_SPEED = 60
CombatMovementConfig.SLIDE_MAX_FORCE = 150000
CombatMovementConfig.SLIDE_DISABLE_WALKSPEED = true
CombatMovementConfig.SLIDE_TEMP_WALKSPEED = 0

--// Slide Hitbox
CombatMovementConfig.SLIDE_BUMP_ENABLED = true
CombatMovementConfig.SLIDE_BUMP_CHECK_INTERVAL = 0.05
CombatMovementConfig.SLIDE_BUMP_HITBOX_SIZE = Vector3.new(7, 7, 20)
CombatMovementConfig.SLIDE_BUMP_FORWARD_OFFSET = 4

--// Ragdoll Timing
CombatMovementConfig.RAGDOLL_VELOCITY_THRESHOLD = 1.5
CombatMovementConfig.RAGDOLL_STABLE_DELAY = 1.0

--// Head Ragdoll Tuning
CombatMovementConfig.HEAD_UPPER_ANGLE = 2
CombatMovementConfig.HEAD_TWIST_LIMIT = 2

--// Body Ragdoll Tuning
CombatMovementConfig.BODY_UPPER_ANGLE = 20
CombatMovementConfig.BODY_TWIST_LIMIT = 20

--// Debug
CombatMovementConfig.DEBUG_SHOW_SLIDE_HITBOX = true
CombatMovementConfig.DEBUG_SLIDE_HITBOX_TRANSPARENCY = 0.5

return CombatMovementConfig