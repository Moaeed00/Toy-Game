--!strict
--// File: src/ReplicatedStorage/Configuration/GiftingConfig.lua
--// GiftingConfig.lua
--// Shared configuration for Brainrot Gifting system.

local GiftingConfig = {}

--// ------------------------------
--// Debug
--// ------------------------------
GiftingConfig.DEBUG_PRINTS = true

--// ------------------------------
--// Proximity Prompt Settings
--// ------------------------------
GiftingConfig.GIFT_PROMPT_NAME = "GiftBrainrotPrompt"
GiftingConfig.GIFT_PROMPT_ACTION_TEXT = "Gift Brainrot"
GiftingConfig.GIFT_PROMPT_OBJECT_TEXT = ""
GiftingConfig.GIFT_PROMPT_KEYCODE = Enum.KeyCode.E
GiftingConfig.GIFT_PROMPT_MAX_DISTANCE = 8
GiftingConfig.GIFT_PROMPT_HOLD_DURATION = 0.2
GiftingConfig.GIFT_PROMPT_REQUIRES_LOS = false

--// ------------------------------
--// Inventory Limits
--// ------------------------------
GiftingConfig.MAX_BRAINROT_INVENTORY = 3

--// ------------------------------
--// UI Timing
--// ------------------------------
GiftingConfig.REJECTION_MESSAGE_DURATION = 2 -- seconds
GiftingConfig.INVENTORY_FULL_MESSAGE_DURATION = 2 -- seconds
GiftingConfig.GIFT_REQUEST_TIMEOUT = 30 -- seconds (auto-cancel if no response)

--// ------------------------------
--// UI Shake Animation
--// ------------------------------
GiftingConfig.SHAKE_INTENSITY = 10 -- pixels
GiftingConfig.SHAKE_COUNT = 6
GiftingConfig.SHAKE_SPEED = 0.05 -- seconds per shake

--// ------------------------------
--// Messages
--// ------------------------------
GiftingConfig.WAITING_FOR_ANSWER_TEXT = "Waiting for answer..."
GiftingConfig.GIFT_REJECTED_TEXT = " rejected your gift"
GiftingConfig.INVENTORY_FULL_LINE1 = "You already have"
GiftingConfig.INVENTORY_FULL_LINE2 = "3 Brainrots"
GiftingConfig.ACCEPT_OR_REJECT_DEFAULT = "Accept or Reject?"

return GiftingConfig