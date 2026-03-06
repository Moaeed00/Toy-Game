--!strict
--// BrainrotConfig.lua
--// Shared configuration for Brainrot pickup/carry system.
--// FIXED: Uses Hold animation from ReplicatedStorage

local BrainrotConfig = {}

--// Tag used by CollectionService to identify brainrot parts
BrainrotConfig.BRAINROT_TAG_NAME = "Brainrot"

--// ProximityPrompt settings
BrainrotConfig.PROMPT_NAME = "BrainrotPickupPrompt"
BrainrotConfig.PROMPT_ACTION_TEXT = "Pick Up"
BrainrotConfig.PROMPT_OBJECT_TEXT = "Brainrot"
BrainrotConfig.PROMPT_KEYCODE = Enum.KeyCode.E
BrainrotConfig.MAX_BRAINROT_INVENTORY = 3
BrainrotConfig.PROMPT_MAX_DISTANCE = 10
BrainrotConfig.PROMPT_REQUIRES_LOS = false
BrainrotConfig.PROMPT_HOLD_DURATION = 0
BrainrotConfig.CARRY_CENTER_OFFSET = CFrame.new(0, 0, -2.5)

--// Hold Animation - Use the global animation from ReplicatedStorage
BrainrotConfig.HOLD_ANIMATION_NAME = "HoldBrainrot"

--// Carry positioning - centers Brainrot between both hands
--// Offset from HumanoidRootPart center
BrainrotConfig.CARRY_CENTER_OFFSET = CFrame.new(0, 2.25, -0.1) -- Slightly up and in front
BrainrotConfig.CARRY_ROTATION_OFFSET = CFrame.Angles(0, math.rad(-90), 0)

--// Hand weld offsets (fine-tuning for different sized Brainrots)
BrainrotConfig.LEFT_HAND_OFFSET = CFrame.new(-0.5, 0, 0) -- Left of center
BrainrotConfig.RIGHT_HAND_OFFSET = CFrame.new(0.5, 0, 0) -- Right of center

--// Drop placement settings (in front of player)
BrainrotConfig.DROP_FORWARD_DISTANCE = 4
BrainrotConfig.DROP_RAYCAST_DOWN_DISTANCE = 25
BrainrotConfig.DROP_UP_OFFSET = 0.25

--// Workspace folder to store dropped brainrots
BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME = "Brainrots"

return BrainrotConfig