--!strict
--// BrainrotConfig.lua
--// Shared configuration for Brainrot pickup/carry system.

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
BrainrotConfig.TWO_HAND_HOLD_ANIMATION_ID = "rbxassetid://0" -- set later

--// Carry offset relative to HumanoidRootPart
BrainrotConfig.CARRY_OFFSET_CFRAME = CFrame.new(0, 0, -2)

--// Drop placement settings (in front of player)
BrainrotConfig.DROP_FORWARD_DISTANCE = 4
BrainrotConfig.DROP_RAYCAST_DOWN_DISTANCE = 25
BrainrotConfig.DROP_UP_OFFSET = 0.25

--// Workspace folder to store dropped brainrots
BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME = "Brainrots"

return BrainrotConfig
