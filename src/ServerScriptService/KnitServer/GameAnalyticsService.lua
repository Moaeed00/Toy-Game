local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GameAnalyticsService = Knit.CreateService {
	Name = "GameAnalyticsService",
	Client = {
		TrackFunnelStepEvent = Knit.CreateSignal(),
	},
}

local FUNNEL_NAME = "KTLB_core"
local FUNNEL_STEPS = {
	player_joined    = 1,
	block_broken     = 2,
	brainrot_picked  = 3,
	brainrot_placed  = 4,
	rebirth_used     = 5,
}

local function tryCalls(calls)
	for _, fn in ipairs(calls) do
		if pcall(fn) then
			return true
		end
	end

	return false
end

function GameAnalyticsService:KnitInit()
	GameAnalyticsService.funnelSessions = {}

	Players.PlayerAdded:Connect(function(player: Player)
		self:TrackFunnelStep(player, "player_joined")
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self.funnelSessions[player] = nil
	end)
end

function GameAnalyticsService:KnitStart()
	self.Client.TrackFunnelStepEvent:Connect(function(player, stepName)
		local step = type(stepName) == "string" and string.lower(stepName) or nil
		if not step then
			warn("[Analytics] tried to fire an unauthorized funnel step:", stepName)
			return
		end

		self:TrackFunnelStep(player, step)
	end)
end

function GameAnalyticsService:GetFunnelSessionId(player: Player)
	local sessionId
	if not self.funnelSessions[player] then
		sessionId = HttpService:GenerateGUID(false)
		self.funnelSessions[player] = sessionId
	end

	return sessionId
end

function GameAnalyticsService:TrackFunnelStep(player: Player, stepName: string)
	print("[Analytics] Tracking step:", stepName)
	if not player then
		return
	end

	local step = type(stepName) == "string" and string.lower(stepName) or nil
	if not step then
		return
	end

	local stepId = FUNNEL_STEPS[step]
	if not stepId then
		warn("[Analytics] Unknown step:", stepName)
		return
	end

	local sessionId = self:GetFunnelSessionId(player)

	tryCalls({
		function()
			AnalyticsService:LogFunnelStepEvent(player, FUNNEL_NAME, sessionId, stepId, step)
		end,
		function()
			AnalyticsService:LogCustomEvent(player, FUNNEL_NAME .. ":" .. step, 1)
		end,
	})
end

return GameAnalyticsService