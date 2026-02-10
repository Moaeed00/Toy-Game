--!strict
--// File: src/ReplicatedStorage/Configuration/PvPToolsConfig.lua
--// PvPToolsConfig.lua
--// Shared config for Tool-based Slide + Punch (Slap Hand) bump system (Osama tasks).

local PvPToolsConfig = {}

--// ------------------------------
--// Debug
--// ------------------------------
PvPToolsConfig.DEBUG_PRINTS = true

--// ------------------------------
--// Tool Names (what players will see in Backpack)
--// ------------------------------
PvPToolsConfig.SLIDE_TOOL_NAME = "Slide"
PvPToolsConfig.PUNCH_TOOL_NAME = "Default Slap Hand"

--// ------------------------------
--// Asset Template Path (ReplicatedStorage)
--// ReplicatedStorage -> Assets -> Punches -> Slap Hand -> Default Slap Hand
--// ------------------------------
PvPToolsConfig.ASSETS_FOLDER_NAME = "Assets"
PvPToolsConfig.PUNCHES_FOLDER_NAME = "Punches"
PvPToolsConfig.SLAP_HAND_FOLDER_NAME = "Slap Hand"
PvPToolsConfig.PUNCH_TOOL_TEMPLATE_NAME = "Default Slap Hand"

--// Remove these legacy scripts from the CLONE (keep templates intact)
PvPToolsConfig.REMOVE_LEGACY_SCRIPT_NAMES = { "Client", "Damage" }

--// ------------------------------
--// Tool Distribution
--// ------------------------------
PvPToolsConfig.GIVE_TO_BACKPACK = true
PvPToolsConfig.GIVE_TO_STARTER_GEAR = true

--// If true, server checks the tool is equipped before allowing actions
PvPToolsConfig.REQUIRE_EQUIPPED_TOOL = true

--// ------------------------------
--// Slide Settings (Tool Activated)
--// ------------------------------
PvPToolsConfig.SLIDE_COOLDOWN = 1.5 -- seconds
PvPToolsConfig.SLIDE_DURATION = 0.275 -- seconds (short)
PvPToolsConfig.SLIDE_SPEED = 60 -- studs/sec push
PvPToolsConfig.SLIDE_MAX_FORCE = 150000 -- LinearVelocity MaxForce

PvPToolsConfig.SLIDE_DISABLE_WALKSPEED = true
PvPToolsConfig.SLIDE_TEMP_WALKSPEED = 0

--// Slide bump settings (no damage)
PvPToolsConfig.SLIDE_BUMP_ENABLED = true
PvPToolsConfig.SLIDE_BUMP_CHECK_INTERVAL = 0.05
PvPToolsConfig.SLIDE_BUMP_HITBOX_SIZE = Vector3.new(14, 7, 16) -- unchanged
PvPToolsConfig.SLIDE_BUMP_FORWARD_OFFSET = 3.5 -- unchanged
PvPToolsConfig.SLIDE_BUMP_PUSH_POWER = 70
PvPToolsConfig.SLIDE_BUMP_PUSH_UP = 10

--// ------------------------------
--// Punch Settings (Slap Hand Tool Activated)
--// ------------------------------
PvPToolsConfig.PUNCH_COOLDOWN = 0.8 -- seconds

--// Wider punch hitbox (so it connects more reliably)
PvPToolsConfig.PUNCH_HITBOX_SIZE = Vector3.new(12, 8, 12)
PvPToolsConfig.PUNCH_HITBOX_FORWARD_OFFSET = 6

--// ------------------------------
--// SLAP GAME STYLE PHYSICS (NEW)
--// ------------------------------
--// We use server-owned physics briefly + LinearVelocity + AngularVelocity (spin)
PvPToolsConfig.SLAP_HIT_WINDOW = 0.18 -- seconds: keep checking hitbox after click

-- One-time impulse strength (scaled by target mass internally)
PvPToolsConfig.SLAP_IMPULSE = 30
PvPToolsConfig.SLAP_UP_IMPULSE = 25
PvPToolsConfig.SLAP_ANGULAR_IMPULSE = 200
PvPToolsConfig.SLAP_MAX_RISE_MULT = 2
PvPToolsConfig.SLAP_MAX_RISE_OFFSET = 6


-- How long target stays physics/ragdoll-like
PvPToolsConfig.SLAP_RAGDOLL_TIME = 0.9

PvPToolsConfig.SLAP_SPEED = 140 -- horizontal shove strength
PvPToolsConfig.SLAP_UP = 65 -- vertical lift
PvPToolsConfig.SLAP_DURATION = 0.25 -- duration before cleanup
PvPToolsConfig.SLAP_MAX_FORCE = 600000

PvPToolsConfig.SLAP_SPIN = 35 -- angular velocity magnitude (spin)
PvPToolsConfig.SLAP_MAX_TORQUE = 600000

--// ------------------------------
--// Brainrot Interaction
--// ------------------------------
--// IMPORTANT: When hit, if target has Brainrot -> drop in FRONT of target (NOT exact collision point)
PvPToolsConfig.FORCE_DROP_BRAINROT_ON_HIT = true

--// Slide Hitbox Debug (unchanged)
PvPToolsConfig.DEBUG_SHOW_SLIDE_HITBOX = true -- set false to HIDE
PvPToolsConfig.DEBUG_SLIDE_HITBOX_TRANSPARENCY = 0.5 -- 50% transparent

return PvPToolsConfig
