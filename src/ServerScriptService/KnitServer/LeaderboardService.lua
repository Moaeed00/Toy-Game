--!strict
--// File: src/ServerScriptService/KnitServer/Services/LeaderboardService.lua
--// LeaderboardService.lua
--// Handles both in-world leaderboard displays and client UI updates.
--// 
--// UPDATED VERSION: Works with TopEarnerLeaderboardModule and TopPointsLeaderboardModule
--// that use the existing Label > SurfaceGui > Frame hierarchy

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local LeaderboardService = Knit.CreateService {
	Name = "LeaderboardService",
	Client = {
		UpdateLeaderboard = Knit.CreateSignal(),
	},
}

--// ------------------------------
--// Configuration
--// ------------------------------
local CONFIG = {
	DEBUG_PRINTS = true,
	UPDATE_TICK = 15, -- seconds for global leaderboard update
	
	--// Workspace path to leaderboards
	LEADERBOARD_FOLDER_PATH = {"Environment", "Stadium", "Leaderboard"},
	
	--// Leaderboard part names
	GLOBAL_LEADERBOARD_NAME = "GlobalLeaderboard",
	TOP_EARNER_NAME = "TopEarnerLeaderboard",
	TOP_POINTS_NAME = "TopPointsLeaderboard",
	
	--// Module names inside each leaderboard
	TOP_EARNER_MODULE_NAME = "TopEarnerLeaderboardModule",
	TOP_POINTS_MODULE_NAME = "TopPointsLeaderboardModule",
	GLOBAL_MODULE_NAME = "LeaderboardModule",
}

--// ------------------------------
--// Debug helper
--// ------------------------------
local function dprint(...: any)
	if CONFIG.DEBUG_PRINTS then
		print("[LeaderboardService]", ...)
	end
end

--// ------------------------------
--// Variables
--// ------------------------------
local SortedPlayerList: { Player } = {}
local PlayerData: { [Player]: any } = {}

local DataHandlerService = nil
local Category: string = "Coins"

--// World leaderboard modules (references)
local GlobalLeaderboardModule = nil
local TopEarnerLeaderboardModule = nil
local TopPointsLeaderboardModule = nil

--// ------------------------------
--// Sort players by category
--// ------------------------------
local function SortTable()
	--// Function: SortTable
	--// Sorts the player list by category value (descending)
	
	table.sort(SortedPlayerList, function(playerOne: Player, playerTwo: Player): boolean
		local av = playerOne:GetAttribute("MoneyPerSec") or 0
		local bv = playerTwo:GetAttribute("MoneyPerSec") or 0
		return av >= bv
	end)
	
	dprint("SortTable() complete, players sorted by:", Category)
end

--// ------------------------------
--// Build server leaderboard table
--// ------------------------------
local function ReturnServerLeaderboardTable()
	--// Function: ReturnServerLeaderboardTable
	--// Returns formatted data for server (current session) leaderboard
	
	local leaderboardTable: { { [string]: any } } = {}

	for _, player in ipairs(SortedPlayerList) do
		local data = PlayerData[player]
		if data then
			local playerTable = {}

			local name
			local success = pcall(function()
				name = Players:GetNameFromUserIdAsync(player.UserId)
			end)

			playerTable.Name = success and name or "NotAvailable"
			playerTable.Value = player:GetAttribute("MoneyPerSec") or 0

			table.insert(leaderboardTable, playerTable)
		end
	end

	dprint("ReturnServerLeaderboardTable() returned", #leaderboardTable, "entries")
	return leaderboardTable
end

--// ------------------------------
--// Build global leaderboard table (for client UI)
--// ------------------------------
local function ReturnGlobalLeaderboardTable()
	--// Function: ReturnGlobalLeaderboardTable
	--// Returns formatted data for global (all-time) leaderboard for client UI
	
	local leaderboardTableCoins: { { [string]: any } } = {}
	local leaderboardTablePoints: { { [string]: any } } = {}

	local topTenPlayerDictionary = DataHandlerService and DataHandlerService:ReturnTopTenPlayers()
	if not topTenPlayerDictionary then
		dprint("ReturnGlobalLeaderboardTable() - no data from DataHandlerService")
		return { Points = leaderboardTablePoints, Coins = leaderboardTableCoins }
	end

	local function build(list, out)
		if not list then return end
		for _, data in ipairs(list) do
			local userId = tonumber(string.sub(data.key, 8))
			if userId then
				local playerTable = {}
				local name
				local success = pcall(function()
					name = Players:GetNameFromUserIdAsync(userId)
				end)

				playerTable.Name = success and name or "NotAvailable"
				playerTable.Value = data.value
				playerTable.key = data.key -- Keep original key for world modules

				table.insert(out, playerTable)
			end
		end
	end

	build(topTenPlayerDictionary.Coins, leaderboardTableCoins)
	build(topTenPlayerDictionary.Points, leaderboardTablePoints)

	dprint("ReturnGlobalLeaderboardTable() - Coins:", #leaderboardTableCoins, "Points:", #leaderboardTablePoints)
	return { Points = leaderboardTablePoints, Coins = leaderboardTableCoins }
end

--// ------------------------------
--// Build raw data for world leaderboard modules
--// ------------------------------
local function ReturnRawLeaderboardData()
	--// Function: ReturnRawLeaderboardData
	--// Returns raw data arrays for world leaderboard modules
	
	local topTenPlayerDictionary = DataHandlerService and DataHandlerService:ReturnTopTenPlayers()
	if not topTenPlayerDictionary then
		dprint("ReturnRawLeaderboardData() - no data from DataHandlerService")
		return { Coins = {}, Points = {} }
	end
	
	dprint("ReturnRawLeaderboardData() - Coins:", #(topTenPlayerDictionary.Coins or {}), "Points:", #(topTenPlayerDictionary.Points or {}))
	
	return {
		Coins = topTenPlayerDictionary.Coins or {},
		Points = topTenPlayerDictionary.Points or {},
	}
end

--// ------------------------------
--// Find leaderboard folder in workspace
--// ------------------------------
local function FindLeaderboardFolder(): Folder?
	--// Function: FindLeaderboardFolder
	--// Navigates workspace to find the leaderboard folder
	
	local current: Instance = workspace
	
	for _, pathPart in ipairs(CONFIG.LEADERBOARD_FOLDER_PATH) do
		local nextPart = current:FindFirstChild(pathPart)
		if not nextPart then
			warn("[LeaderboardService] Could not find:", pathPart, "in", current:GetFullName())
			return nil
		end
		current = nextPart
	end
	
	dprint("FindLeaderboardFolder() found:", current:GetFullName())
	return current :: Folder
end

--// ------------------------------
--// Initialize world leaderboard modules
--// ------------------------------
local function InitializeWorldLeaderboards()
	--// Function: InitializeWorldLeaderboards
	--// Finds and initializes all world leaderboard modules
	
	dprint("InitializeWorldLeaderboards() starting...")
	
	local leaderboardFolder = FindLeaderboardFolder()
	if not leaderboardFolder then
		warn("[LeaderboardService] Leaderboard folder not found, cannot initialize world leaderboards")
		return
	end
	
	--// ========================================
	--// Find and initialize TopEarnerLeaderboard
	--// ========================================
	local topEarnerLB = leaderboardFolder:FindFirstChild(CONFIG.TOP_EARNER_NAME)
	if topEarnerLB then
		dprint("Found TopEarnerLeaderboard part")
		
		local module = topEarnerLB:FindFirstChild(CONFIG.TOP_EARNER_MODULE_NAME)
		if module and module:IsA("ModuleScript") then
			local success, result = pcall(function()
				return require(module)
			end)
			
			if success and result then
				TopEarnerLeaderboardModule = result
				dprint("TopEarnerLeaderboardModule loaded ✅")
				
				--// Initialize if not auto-initialized
				if not TopEarnerLeaderboardModule.Initialized then
					TopEarnerLeaderboardModule:Init(topEarnerLB)
				end
			else
				warn("[LeaderboardService] Failed to require TopEarnerLeaderboardModule:", result)
			end
		else
			warn("[LeaderboardService] TopEarnerLeaderboardModule not found in:", topEarnerLB:GetFullName())
			dprint("Expected module name:", CONFIG.TOP_EARNER_MODULE_NAME)
		end
	else
		warn("[LeaderboardService] TopEarnerLeaderboard not found in leaderboard folder")
	end
	
	--// ========================================
	--// Find and initialize TopPointsLeaderboard
	--// ========================================
	local topPointsLB = leaderboardFolder:FindFirstChild(CONFIG.TOP_POINTS_NAME)
	if topPointsLB then
		dprint("Found TopPointsLeaderboard part")
		
		local module = topPointsLB:FindFirstChild(CONFIG.TOP_POINTS_MODULE_NAME)
		if module and module:IsA("ModuleScript") then
			local success, result = pcall(function()
				return require(module)
			end)
			
			if success and result then
				TopPointsLeaderboardModule = result
				dprint("TopPointsLeaderboardModule loaded ✅")
				
				--// Initialize if not auto-initialized
				if not TopPointsLeaderboardModule.Initialized then
					TopPointsLeaderboardModule:Init(topPointsLB)
				end
			else
				warn("[LeaderboardService] Failed to require TopPointsLeaderboardModule:", result)
			end
		else
			warn("[LeaderboardService] TopPointsLeaderboardModule not found in:", topPointsLB:GetFullName())
			dprint("Expected module name:", CONFIG.TOP_POINTS_MODULE_NAME)
		end
	else
		warn("[LeaderboardService] TopPointsLeaderboard not found in leaderboard folder")
	end
	
	--// ========================================
	--// Find and initialize GlobalLeaderboard (existing)
	--// ========================================
	local globalLB = leaderboardFolder:FindFirstChild(CONFIG.GLOBAL_LEADERBOARD_NAME)
	if globalLB then
		dprint("Found GlobalLeaderboard part")
		
		local module = globalLB:FindFirstChild(CONFIG.GLOBAL_MODULE_NAME)
		if module and module:IsA("ModuleScript") then
			local success, result = pcall(function()
				return require(module)
			end)
			
			if success and result then
				GlobalLeaderboardModule = result
				dprint("GlobalLeaderboardModule loaded ✅")
				
				--// Call Main for compatibility with existing module
				if GlobalLeaderboardModule.Main then
					GlobalLeaderboardModule:Main("Global Leaderboard", "#", "Coins", "Player")
				end
			else
				warn("[LeaderboardService] Failed to require GlobalLeaderboardModule:", result)
			end
		else
			dprint("GlobalLeaderboard has no LeaderboardModule (this is okay if not used)")
		end
	else
		dprint("GlobalLeaderboard not found (this is okay if not used)")
	end
	
	dprint("InitializeWorldLeaderboards() complete")
end

--// ------------------------------
--// Update world leaderboards
--// ------------------------------
local function UpdateWorldLeaderboards()
	--// Function: UpdateWorldLeaderboards
	--// Updates all world leaderboard displays with latest data
	
	dprint("UpdateWorldLeaderboards() starting...")
	
	local rawData = ReturnRawLeaderboardData()
	
	--// Update TopEarnerLeaderboard (Coins)
	if TopEarnerLeaderboardModule and TopEarnerLeaderboardModule.Initialized then
		local success, err = pcall(function()
			TopEarnerLeaderboardModule:UpdateLeaderboard(rawData.Coins)
		end)
		
		if success then
			dprint("TopEarnerLeaderboard updated ✅")
		else
			warn("[LeaderboardService] Failed to update TopEarnerLeaderboard:", err)
		end
	else
		dprint("TopEarnerLeaderboard not ready, skipping update")
	end
	
	--// Update TopPointsLeaderboard (Points)
	if TopPointsLeaderboardModule and TopPointsLeaderboardModule.Initialized then
		local success, err = pcall(function()
			TopPointsLeaderboardModule:UpdateLeaderboard(rawData.Points)
		end)
		
		if success then
			dprint("TopPointsLeaderboard updated ✅")
		else
			warn("[LeaderboardService] Failed to update TopPointsLeaderboard:", err)
		end
	else
		dprint("TopPointsLeaderboard not ready, skipping update")
	end
	
	--// Update GlobalLeaderboard (Coins by default)
	if GlobalLeaderboardModule then
		local success, err = pcall(function()
			GlobalLeaderboardModule:UpdateLeaderboard(rawData.Coins)
		end)
		
		if success then
			dprint("GlobalLeaderboard updated ✅")
		else
			warn("[LeaderboardService] Failed to update GlobalLeaderboard:", err)
		end
	end
	
	dprint("UpdateWorldLeaderboards() complete")
end

--// ------------------------------
--// Public: Update server leaderboard
--// ------------------------------
function LeaderboardService:UpdateServerLeaderboard()
	--// Function: UpdateServerLeaderboard
	--// Fires update signal to all clients with server leaderboard data
	
	dprint("UpdateServerLeaderboard() called")
	self.Client.UpdateLeaderboard:FireAll("Server", ReturnServerLeaderboardTable())
end

--// ------------------------------
--// Public: Update global leaderboard
--// ------------------------------
function LeaderboardService:UpdateGlobalLeaderboard()
	--// Function: UpdateGlobalLeaderboard
	--// Fires update signal to all clients AND updates world leaderboards
	
	dprint("UpdateGlobalLeaderboard() called")
	
	--// Fire to clients (for any client-side UI)
	self.Client.UpdateLeaderboard:FireAll("Global", ReturnGlobalLeaderboardTable())
	
	--// Update world leaderboards directly
	UpdateWorldLeaderboards()
end

--// ------------------------------
--// Client request handler
--// ------------------------------
function LeaderboardService.Client:RequestLeaderboard(player)
	--// Function: Client:RequestLeaderboard
	--// Returns both server and global leaderboard data to requesting client
	
	dprint("Client:RequestLeaderboard() from:", player.Name)
	
	return {
		Server = ReturnServerLeaderboardTable(),
		Global = ReturnGlobalLeaderboardTable(),
	}
end

--// ------------------------------
--// Knit Lifecycle: Init
--// ------------------------------
function LeaderboardService:KnitInit()
	dprint("KnitInit() start")
	
	--// Get reference to DataHandlerService
	DataHandlerService = Knit.GetService("DataHandlerService")
	dprint("Got DataHandlerService reference")
	
	dprint("KnitInit() complete")
end

--// ------------------------------
--// Knit Lifecycle: Start
--// ------------------------------
function LeaderboardService:KnitStart()
	dprint("KnitStart() start")
	
	--// Get category from DataHandlerService (default to "Coins")
	Category = (DataHandlerService.LeaderboardCategory and DataHandlerService.LeaderboardCategory[1]) or "Coins"
	dprint("Leaderboard category set to:", Category)
	
	--// Initialize world leaderboards (find modules and initialize them)
	InitializeWorldLeaderboards()
	
	--// ========================================
	--// Connect to DataHandlerService signals
	--// ========================================
	
	--// When a player's profile loads
	DataHandlerService.OnPlayerProfileLoaded:Connect(function(player: Player, profileData: {})
		--// Signal: OnPlayerProfileLoaded
		dprint("OnPlayerProfileLoaded:", player.Name)
		
		if player and profileData then
			PlayerData[player] = profileData
			table.insert(SortedPlayerList, player)
			SortTable()
			self:UpdateServerLeaderboard()
            self:UpdateGlobalLeaderboard()
		end
	end)

	--// When a player's data changes
	DataHandlerService.OnPlayerDataChanged:Connect(function(player: Player, profileData: {})
		--// Signal: OnPlayerDataChanged
		dprint("OnPlayerDataChanged:", player.Name)
		
		if player and profileData and PlayerData[player] then
			--// Only update if category value actually changed
			if (PlayerData[player][Category] or 0) == (profileData[Category] or 0) then
				return
			end

			PlayerData[player] = profileData
			SortTable()
			self:UpdateServerLeaderboard()
            self:UpdateGlobalLeaderboard()
		end
	end)

	--// When a player leaves
	Players.PlayerRemoving:Connect(function(player: Player)
		--// Event: PlayerRemoving
		dprint("PlayerRemoving:", player.Name)
		
		local idx = table.find(SortedPlayerList, player)
		if idx then
			table.remove(SortedPlayerList, idx)
		end
		PlayerData[player] = nil
		self:UpdateServerLeaderboard()
        self:UpdateGlobalLeaderboard()
	end)

	Players.PlayerAdded:Connect(function(player)

		player:GetAttributeChangedSignal("MoneyPerSec"):Connect(function()
			SortTable()
			self:UpdateServerLeaderboard()
		end)

	end)
	
	dprint("KnitStart() complete ✅")
end

return LeaderboardService
