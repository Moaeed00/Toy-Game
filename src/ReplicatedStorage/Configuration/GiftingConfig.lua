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
GiftingConfig.GIFT_REQUEST_TIMEOUT = 30 -- seconds (auto-cancel if no response)
GiftingConfig.WAITING_GUI_DURATION = 3

return GiftingConfig