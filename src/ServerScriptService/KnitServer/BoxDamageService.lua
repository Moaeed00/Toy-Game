local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BoxesFolder: Folder = workspace:WaitForChild("Boxes")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BoxDamageService = Knit.CreateService {
    Name = "BoxDamageService",
    Client = {},
}

function BoxDamageService:KnitInit()
end

function BoxDamageService:KnitStart()
    BoxDamageService.GUIService = Knit.GetService("GUIService")
    BoxDamageService.BoxSpawningService = Knit.GetService("BoxSpawningService")

    BoxDamageService.CurrentHitBoxIndex = nil
end

function BoxDamageService:DealDamage(footballHitPower: number, boxIndex: number)
    if self.CurrentHitBoxIndex ~= boxIndex then
        self.CurrentHitBoxIndex = boxIndex
        print("Now hitting box with index: " .. tostring(boxIndex))
    end

    local hitBox = self:FindHitBoxByIndex(boxIndex)
    if not hitBox then
        return
    end

    if not hitBox:GetAttribute("TotalHitPower") then
        hitBox:SetAttribute("TotalHitPower", hitBox:GetAttribute("HitPower"))
    end
    local totalHitPower = hitBox:GetAttribute("TotalHitPower")
    local currentHitPower = hitBox:GetAttribute("HitPower")
    local updatedHitPower: number = math.max(0, currentHitPower - footballHitPower)
    hitBox:SetAttribute("HitPower", updatedHitPower)

    self:UpdateProgressUI(hitBox, totalHitPower, updatedHitPower)
    task.spawn(function()
        self:PlayDamageVFX(hitBox)
    end)

    if updatedHitPower <= 0 then
        self:DestroyBox(hitBox)
    end
end

function BoxDamageService:UpdateProgressUI(box: Model, totalHitPower: number, currentHitPower: number)
    local hitProgress: Frame = box:WaitForChild(box.Name):WaitForChild("BillboardGui"):WaitForChild("Frame"):WaitForChild("HitProgressBar")
    local hitProgressBar: Frame = hitProgress:WaitForChild("ProgressBar")
    local hitProgressText: TextLabel = hitProgress:WaitForChild("ProgressText")

    self.GUIService:HandleProgressBar(hitProgressBar, hitProgressText, totalHitPower, currentHitPower)
end

function BoxDamageService:PlayDamageVFX(box: Model)
    print("PlayDamageVFX")
    -- scale-in tween on box here
end

function BoxDamageService:DestroyBox(box: Model)
    print("Box destroyed: " .. box.Name)
    self.CurrentHitBoxIndex = nil
    box:Destroy()

    self.BoxSpawningService:SpawnBoxes(1)
end

function BoxDamageService:FindHitBoxByIndex(boxIndex: number)
    for _, box: Model in ipairs(BoxesFolder:GetChildren()) do
        if box:GetAttribute("Index") == boxIndex then
            return box
        end
    end

    return nil
end

function BoxDamageService:ResetBoxHitPower(box: Model)
    box:SetAttribute("TotalHitPower", box:GetAttribute("HitPower"))
end

return BoxDamageService