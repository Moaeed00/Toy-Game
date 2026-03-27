local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local TutorialService = Knit.CreateService {
    Name = "TutorialService",
    Client = {
        BeginTutorial = Knit.CreateSignal(),
        FootballEquipped = Knit.CreateSignal(),
    },
}

function TutorialService:KnitInit() end

function TutorialService:KnitStart()
    TutorialService.DataHandlerService = Knit.GetService("DataHandlerService")

    self.DataHandlerService.OnPlayerProfileLoaded:Connect(function(player: Player, profileData: {[string]: any})
        if profileData.IsFirstTimeLoad == true then
            -- Small delay so the client controller has time to fully initialize
            task.delay(0.75, function()
                if player and player.Parent then
                    self.Client.BeginTutorial:Fire(player)
                end
            end)
        end
    end)
end

function TutorialService:NotifyFootballEquipped(player: Player)
    local DataHandlerService = Knit.GetService("DataHandlerService")
    local data = DataHandlerService:GetPlayerData(player)
    if data and data.IsFirstTimeLoad then
        self.Client.FootballEquipped:Fire(player)
    end
end

function TutorialService.Client:CompleteTutorial(player: Player)
    local DataHandlerService = Knit.GetService("DataHandlerService")
    local data = DataHandlerService:GetPlayerData(player)

    if not data then
        warn(`[TutorialService] No data found for {player.DisplayName} on CompleteTutorial`)
        return false
    end

    if not data.IsFirstTimeLoad then
        -- Already completed — nothing to do
        return true
    end

    DataHandlerService:SetPlayerData(player, { IsFirstTimeLoad = false })
    print(`[TutorialService] Tutorial marked complete for {player.DisplayName}`)
    return true
end

return TutorialService