--!strict
--// File: src/ReplicatedStorage/Configuration/CombatMovementConfig.lua
--// CombatMovementConfig.lua
--// Shared config for LEGACY CombatMovementService/Controller (Task 12).
--// UPDATED:
--// - No damage on punch
--// - Brainrot drop is ALWAYS in front of the hit player (not exact collision pos)

local CombatMovementConfig = {}

--// ------------------------------
--// Debug
--// ------------------------------
CombatMovementConfig.DEBUG_PRINTS = true

--// ------------------------------
--// Input Mode (NEW)
--// "Tool" = Use Tool.Activated (mouse left click)
--// "Keybind" = Use CTRL for Slide and Q for Punch
--// ------------------------------
CombatMovementConfig.INPUT_MODE = "Tool"

--// Tool names (only used if INPUT_MODE == "Tool")
CombatMovementConfig.SLIDE_TOOL_NAME = "Slide"
CombatMovementConfig.PUNCH_TOOL_NAME = "Default Slap Hand"

--// ------------------------------
--// Animation IDs (Optional - if you still use animations)
--// ------------------------------
CombatMovementConfig.SLIDE_ANIMATION_ID = "rbxassetid://0"
CombatMovementConfig.PUNCH_ANIMATION_ID = "rbxassetid://0"

--// ----------------E: We keep cooldowns as-is
CombatMovementConfig.SLIDE_COOLDOWN = 1.5
CombatMovementConfig.PUNCH_COOLDOWN = 0.8

--// ------------------------------
--// Slide Settings
--// ------------------------------
CombatMovementConfig.SLIDE_DURATION = 0.275
CombatMovementConfig.SLIDE_SPEED = 60
CombatMovementConfig.SLIDE_MAX_FORCE = 150000
CombatMovementConfig.SLIDE_DISABLE_WALKSPEED = true
CombatMovementConfig.SLIDE_TEMP_WALKSPEED = 0

--// Slide bump settings (NO DAMAGE)
CombatMovementConfig.SLIDE_BUMP_ENABLED = true
CombatMovementConfig.SLIDE_BUMP_CHECK_INTERVAL = 0.05
CombatMovementConfig.SLIDE_BUMP_HITBOX_SIZE = Vector3.new(16, 7, 20)
CombatMovementConfig.SLIDE_BUMP_FORWARD_OFFSET = 4
CombatMovementConfig.SLIDE_BUMP_PUSH_POWER = 60
CombatMovementConfig.SLIDE_BUMP_PUSH_UP = 10

--// ------------------------------
--// Punch Settings (NO DAMAGE)
--// ------------------------------
CombatMovementConfig.PUNCH_HITBOX_SIZE = Vector3.new(8, 6, 8)
CombatMovementConfig.PUNCH_HITBOX_FORWARD_OFFSET = 5

--// Punch bump power (NO DAMAGE)
CombatMovementConfig.PUNCH_BUMP_PUSH_POWER = 80
CombatMovementConfig.PUNCH_BUMP_PUSH_UP = 14

--// Slide Hitbox Debug
CombatMovementConfig.DEBUG_SHOW_SLIDE_HITBOX = true -- set false to HIDE
CombatMovementConfig.DEBUG_SLIDE_HITBOX_TRANSPARENCY = 0.5 -- 50% transparent

return CombatMovementConfig
