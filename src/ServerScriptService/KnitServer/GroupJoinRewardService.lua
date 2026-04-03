local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GroupJoinRewardService = Knit.CreateService {
    Name = "GroupJoinRewardService",
    Client = {},
}

local GROUP_INFO = {
    GROUP_ID = 35170883
}

function GroupJoinRewardService:KnitInit()
end

function GroupJoinRewardService:KnitStart()
    GroupJoinRewardService.DataHandlerService = Knit.GetService("DataHandlerService")
    GroupJoinRewardService.BaseService = Knit.GetService("BaseService")
end

function GroupJoinRewardService.Client:ClaimGroupReward(player: Player)
    local alreadyClaimed
    -- local joinStatus
    local ok, err = pcall(function()
        alreadyClaimed = self.Server.DataHandlerService:GetPlayerData(player).IsGroupJoinRewardClaimed
    end)

    if not ok then
        warn("DataStore read failed:", err)
        return { Success = false, Message = "Couldn't process the reward this time.\nPlease try again later." }
    end

    if alreadyClaimed then
        return { Success = false, Message = "You've already claimed this reward." }
    end

    if not player:IsInGroupAsync(GROUP_INFO.GROUP_ID) then
        return { Success = false, NeedsJoin = true, Message = "Join the group first to claim this reward!" }
    end

    local brainrotName = "Strawberry Elephant"
    local brainrotRarity = "Secret"
    local mutation = "Normal"
    self.Server.BaseService:GiveTool(player, brainrotRarity, brainrotName, mutation)

    -- Persist the claim so they can't grab it again on rejoin
    pcall(function()
        self.Server.DataHandlerService:SetPlayerData(player, { IsGroupJoinRewardClaimed = true })
    end)

    return { Success = true, Message = "Reward has been added to your inventory!" }
end

return GroupJoinRewardService