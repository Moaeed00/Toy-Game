--!strict
--// File: ReplicatedStorage/Configuration/BlocksSpawnAreaConfig.lua
--// Configuration for BlocksSpawnArea mechanics

return {
	--// Debug
	DEBUG_PRINTS = true,
	
	--// Workspace path
	BLOCKS_SPAWN_AREA_NAME = "BlocksSpawnArea", -- Part name in Workspace
	
	--// Speed settings
	NORMAL_SPEED = 16, -- Speed when brainrot is EQUIPPED (in hand) inside area
	BOOSTED_SPEED = 32, -- 2x speed (everywhere else)
	
	--// UI settings (StarterGui paths)
	DROP_GUI_NAME = "DropGui",
	DROP_BUTTON_FRAME_NAME = "DropButtonFrame",
	DROP_BUTTON_NAME = "DropButton",
	
	--// Animation settings
	ZOOM_OUT_DURATION = 0.1, -- seconds
	
	--// Audio settings
	EXIT_AUDIO_ID = "rbxassetid://0", -- Placeholder - replace with actual audio
	EXIT_AUDIO_VOLUME = 0.5,
}