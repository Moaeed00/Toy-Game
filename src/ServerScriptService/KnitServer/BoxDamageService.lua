local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoxesFolder: Folder = workspace:WaitForChild("Boxes")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BoxDamageService = Knit.CreateService {
    Name = "BoxDamageService",
    Client = { },
}

function BoxDamageService:KnitInit()
end

function BoxDamageService:KnitStart()
    BoxDamageService.GUIService = Knit.GetService("GUIService")

    BoxDamageService.CurrentHitBoxIndex = nil
end

function BoxDamageService:DealDamage(box: Part, footballHitPower: number, boxIndex: number)
    if self.CurrentHitBoxIndex ~= boxIndex then
        self.CurrentHitBoxIndex = boxIndex
        print("Now hitting box with index: " .. tostring(boxIndex))
    end

    local hitBox = self:FindHitBoxByIndex(boxIndex)
    if not hitBox then
        return
    end

    local hitPower = hitBox:GetAttribute("HitPower")
    local updatedHitPower: number = math.max(0, hitPower - footballHitPower)
    hitBox:SetAttribute("HitPower", updatedHitPower)

    print("Box Index: ", tostring(boxIndex))
    print("Box Hit Power: ", hitPower)
    print("Ball Hit Power: ", footballHitPower)

    self:UpdateProgressUI(box, updatedHitPower)
    self:PlayDamageVFX(box)

    if updatedHitPower <= 0 then
        self:DestroyBox(hitBox)
    end
end

function BoxDamageService:UpdateProgressUI(box: Part, currentHitPower: number)
    print("UpdateProgressUI")
    local hitProgress: Frame = box:WaitForChild("BillboardGui"):WaitForChild("Frame"):WaitForChild("HitProgressBar")
    local hitProgressBar: Frame = hitProgress:WaitForChild("ProgressBar")
    local hitProgressText: TextLabel = hitProgress:WaitForChild("ProgressText")
    self.GUIService:HandleProgressBar(hitProgressBar, hitProgressText, currentHitPower)
end

function BoxDamageService:PlayDamageVFX(box: Model)
    print("PlayDamageVFX")
    -- scale-in tween on box here
end

function BoxDamageService:DestroyBox(box: Model)
    print("Box destroyed: " .. box.Name)
    self.CurrentHitBoxIndex = nil
    box:Destroy()
end

function BoxDamageService:FindHitBoxByIndex(boxIndex: number)
    for _, box: Model in ipairs(BoxesFolder:GetChildren()) do
        if box:GetAttribute("Index") == boxIndex then
            return box
        end
    end

    return nil
end

return BoxDamageService