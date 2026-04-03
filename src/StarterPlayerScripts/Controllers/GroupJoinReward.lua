local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local NotificationHandler = require(ReplicatedStorage.Utility.NotificationHandler)
local Prompt: ProximityPrompt = workspace:WaitForChild("UIPortals"):WaitForChild("JoinGroupReward"):WaitForChild("Base"):FindFirstChild("ProximityPrompt")

local GroupJoinReward = Knit.CreateController {
    Name = "GroupJoinReward"
}

local GROUP_INFO = {
    GROUP_ID = 35170883
}

function GroupJoinReward:KnitStart()
    GroupJoinReward.GroupJoinRewardService = Knit.GetService("GroupJoinRewardService")

    Prompt.Triggered:Connect(function()
        self.GroupJoinRewardService:ClaimGroupReward():andThen(function(result)
            if result.Success then
                NotificationHandler:DisplayNotificationMessage(result.Message, "Success")
            elseif result.NeedsJoin then
                NotificationHandler:DisplayNotificationMessage(result.Message, "Error")
                GroupService:PromptToJoinAsync(GROUP_INFO.GROUP_ID)
            else
                NotificationHandler:DisplayNotificationMessage(result.Message, "Error")
            end
        end)
    end)
end

function GroupJoinReward:KnitInit()
end

return GroupJoinReward