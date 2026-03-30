local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local TutorialService = Knit.CreateService {
    Name = "TutorialService",
    Client = {
		BeginTutorial    = Knit.CreateSignal(),
		FinishTutorial   = Knit.CreateSignal(),
		TutorialComplete = Knit.CreateSignal(),
        FootballBought   = Knit.CreateSignal(),
        BrainrotPlaced   = Knit.CreateSignal(),
    },
}

function TutorialService:KnitInit() end

function TutorialService:KnitStart()
    TutorialService.DataHandlerService = Knit.GetService("DataHandlerService")

    self.DataHandlerService.OnPlayerProfileLoaded:Connect(function(player: Player, profileData)
        if profileData.IsFirstTimeLoad == true then
            self.Client.BeginTutorial:Fire(player)
        end
	end)

	self.Client.FinishTutorial:Connect(function(player: Player)
        self:CompleteTutorial(player)
    end)

    -- Reset tutorial progress if player leaves before completing it
    game.Players.PlayerRemoving:Connect(function(player: Player)
        local data = self.DataHandlerService:GetPlayerData(player)
        if not data or data.IsFirstTimeLoad ~= true then return end

        -- Reset tutorial flag
        self.DataHandlerService:SetPlayerData(player, { IsFirstTimeLoad = true })

        -- Reset football ownership and equipped state back to default
        self.DataHandlerService:SetPlayerData(player, {
            Footballs = {
                Owned    = {},
                Equipped = 0,
            }
        })

        -- Reset any brainrots discovered during the tutorial session
        -- (they haven't earned index progress since tutorial wasn't completed)
        self.DataHandlerService:SetPlayerData(player, {
            DiscoveredBrainrots = {},
            DiscoveredBrainrotsPercentage = 0,
            IndexMultiplierBonus = 0,
            MoneyMultiplier = 1,
            Points = 0,
            Money = 50,
        })

        print(`[TutorialService] {player.DisplayName} left mid-tutorial, full reset applied`)
    end)
end

-- ─────────────────────────────────────────────────────────────────
-- Called by FootballShopService after a successful football purchase
-- ─────────────────────────────────────────────────────────────────
function TutorialService:NotifyFootballBought(player: Player)
    local data = self.DataHandlerService:GetPlayerData(player)
    if data and data.IsFirstTimeLoad then
        self.Client.FootballBought:Fire(player)
    end
end

-- ─────────────────────────────────────────────────────────────────
-- Called by whatever service handles placing brainrots into bases
-- ─────────────────────────────────────────────────────────────────
function TutorialService:NotifyBrainrotPlaced(player: Player)
    local data = self.DataHandlerService:GetPlayerData(player)
    if data and data.IsFirstTimeLoad then
        self.Client.BrainrotPlaced:Fire(player)
    end
end

-- ─────────────────────────────────────────────────────────────────
-- Client RPC: called when the tutorial UI reports completion
-- ─────────────────────────────────────────────────────────────────
function TutorialService:CompleteTutorial(player: Player)
    local DataHandlerService = Knit.GetService("DataHandlerService")
    local data = DataHandlerService:GetPlayerData(player)

    if not data then
        warn(`[TutorialService] No data found for {player.DisplayName} on CompleteTutorial`)
        return
    end
    if not data.IsFirstTimeLoad then
        return
    end

	DataHandlerService:SetPlayerData(player, { IsFirstTimeLoad = false })
	self.Client.TutorialComplete:Fire(player)  -- ✅ server fires TO client
    print(`[TutorialService] Tutorial marked complete for {player.DisplayName}`)
end

function TutorialService.Client:GetIsFirstTimeLoad(player: Player)
    local data = Knit.GetService("DataHandlerService"):GetPlayerData(player)
    return data ~= nil and data.IsFirstTimeLoad == true
end

return TutorialService