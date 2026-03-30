local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local TutorialController = Knit.CreateController { Name = "TutorialController" }

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────────
-- Step definitions
-- ─────────────────────────────────────────────────────────────────
local STEPS = {
    {
        id        = "shop",
        text      = "Head to the Football Shop\nand buy your first football.",
        beamColor = Color3.fromRGB(255, 210, 50),
    },
    {
        id        = "block",
        text      = "Kick the football at a Block\nto break it open.",
        beamColor = Color3.fromRGB(50, 200, 255),
    },
    {
        id        = "base",
        text      = "Equip and Place the Brainrot\ninto your Base.",
        beamColor = Color3.fromRGB(100, 255, 120),
    },
}

-- ─────────────────────────────────────────────────────────────────
-- Module-level state
-- ─────────────────────────────────────────────────────────────────
local tutorialActive   = false
local currentStepIndex = 1
local isFirstTimePlayer = false

local tutorialGui  = nil   -- ScreenGui
local beamInst: Beam  = nil   -- Beam instance
local att0         = nil   -- Attachment on HumanoidRootPart (moves with player)
local att1         = nil   -- Attachment on world target

local respawnConn  = nil   -- persistent for whole tutorial duration
local stepConns    = {}    -- cleared + rebuilt every step
local heartbeatConn = nil  -- block-retarget loop, cleared with beam

-- ─────────────────────────────────────────────────────────────────
-- Knit lifecycle
-- ─────────────────────────────────────────────────────────────────
function TutorialController:KnitInit() end

function TutorialController:KnitStart()
	TutorialController.TutorialService = Knit.GetService("TutorialService")
	TutorialController.GameManagerController = Knit.GetController("GameManagerController")

	TutorialController.TutorialService.BeginTutorial:Connect(function()
		self.GameManagerController:ToggleUITopFrame(false)
        self:StartTutorial()
    end)
end

-- ─────────────────────────────────────────────────────────────────
-- Workspace finders
-- ─────────────────────────────────────────────────────────────────
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function findShopPart()
    local portals = workspace:FindFirstChild("UIPortals")
    if not portals then
        warn("[TutorialController] UIPortals folder not found in workspace")
        return nil
    end
    local shop = portals:FindFirstChild("FootballSHOP")
    if not shop then
        warn("[TutorialController] FootballSHOP not found under UIPortals")
        return nil
    end

    -- The existing hierarchy has UIPortals/FootballSHOP/BEAM/Part
    local beamFolder = shop:FindFirstChild("BEAM")
    if beamFolder then
        local p = beamFolder:FindFirstChild("Part")
               or beamFolder:FindFirstChildWhichIsA("BasePart")
        if p then return p end
    end

    -- Fallback to primary part / any BasePart
    return shop.PrimaryPart or shop:FindFirstChildWhichIsA("BasePart")
end

local function findNearestBlock()
    local hrp = getHRP()
    if not hrp then return nil end

    local normalFolder = workspace:FindFirstChild("Blocks") and workspace.Blocks:FindFirstChild("Normal")
    if not normalFolder then
        warn("[TutorialController] workspace.Blocks.Normal not found")
        return nil
    end

    local best, bestDist = nil, math.huge
    for _, obj in ipairs(normalFolder:GetChildren()) do
        local part = nil
        if obj:IsA("Model") and obj.Name == "Basic_Block" then
            part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        elseif obj:IsA("BasePart") and obj.Name == "Basic_Block" then
            part = obj
        end

        if part then
            local dist = (part.Position - hrp.Position).Magnitude
            if dist < bestDist then
                best, bestDist = part, dist
            end
        end
    end

    if not best then
        warn("[TutorialController] No valid BasePart found inside Blocks.Normal children")
    end

    return best
end

local function findPlayerBase()
    local basesFolder = workspace:FindFirstChild("Bases")
    if not basesFolder then
        warn("[TutorialController] Bases folder not found")
        return nil
    end

    local playerBase = basesFolder:FindFirstChild(tostring(LocalPlayer.UserId))
    if not playerBase then
        warn("[TutorialController] No base found for player " .. LocalPlayer.UserId)
        return nil
    end

    local grid = playerBase:FindFirstChild("Grid")
    if not grid then
        warn("[TutorialController] Grid not found inside player base")
        return nil
    end

    local slot1 = grid:FindFirstChild("1")
    if not slot1 then
        warn("[TutorialController] Grid slot 1 not found")
        return nil
    end

    -- Slot 1 is a Part itself, not a Model
    if slot1:IsA("BasePart") then
        return slot1
    end

    return slot1:FindFirstChildWhichIsA("BasePart", true)
end

-- ─────────────────────────────────────────────────────────────────
-- GUI
-- ─────────────────────────────────────────────────────────────────
function TutorialController:BuildGui()
    if tutorialGui then tutorialGui:Destroy() end

    tutorialGui = Instance.new("ScreenGui")
    tutorialGui.Name           = "TutorialGui"
    tutorialGui.ResetOnSpawn   = false
    tutorialGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    tutorialGui.IgnoreGuiInset = true
    tutorialGui.Parent         = PlayerGui

    -- Dark rounded card, top-center
    local card = Instance.new("Frame")
    card.Name                   = "Card"
    card.AnchorPoint            = Vector2.new(0.5, 0)
    card.Position               = UDim2.new(0.5, 0, 0, 24)
    card.Size                   = UDim2.new(0, 520, 0, 90)
    card.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
    card.BackgroundTransparency = 0.18
    card.BorderSizePixel        = 0
    card.ZIndex                 = 5
    card.Parent                 = tutorialGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent       = card

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft   = UDim.new(0, 20)
    padding.PaddingRight  = UDim.new(0, 20)
    padding.PaddingTop    = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent        = card

    -- Subtle stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color       = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.88
    stroke.Thickness   = 1.2
    stroke.Parent      = card

    local label = Instance.new("TextLabel")
    label.Name                   = "Text"
    label.Size                   = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text                   = ""
    label.TextColor3             = Color3.fromRGB(255, 255, 255)
    label.Font                   = Enum.Font.Montserrat
    label.FontFace               = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
    label.TextScaled             = true
    label.TextWrapped            = true
    label.LineHeight             = 1.25
    label.ZIndex                 = 6
    label.Parent                 = card

    -- Constrain text size so it doesn't get comically huge on wide screens
    local sizeConstraint = Instance.new("UITextSizeConstraint")
    sizeConstraint.MaxTextSize = 28
    sizeConstraint.MinTextSize = 14
    sizeConstraint.Parent      = label
end

function TutorialController:UpdateGuiForStep(step)
    if not tutorialGui then return end
    local card = tutorialGui:FindFirstChild("Card")
    if not card then return end
    local txt = card:FindFirstChild("Text")
    if txt then txt.Text = step.text end
end
-- ─────────────────────────────────────────────────────────────────
-- Beam
-- ─────────────────────────────────────────────────────────────────
function TutorialController:ClearBeam()
    if heartbeatConn then
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end
    -- Destroy attachments first; beam goes with att0 since it's parented there
    if att0 and att0.Parent then
        att0:Destroy()
    end
    if att1 and att1.Parent then
        att1:Destroy()
    end
    if beamInst and beamInst.Parent then
        beamInst:Destroy()
    end
    att0, att1, beamInst = nil, nil, nil
end

function TutorialController:SetBeamTarget(targetPart, color)
    self:ClearBeam()

    local hrp = getHRP()
    if not hrp then
        warn("[TutorialController] HumanoidRootPart not available for beam")
        return
    end
    if not targetPart then
        warn("[TutorialController] No target part provided for beam")
        return
    end

    att0 = Instance.new("Attachment")
    att0.Parent = hrp

    att1 = Instance.new("Attachment")
    att1.Parent = targetPart

    beamInst = Instance.new("Beam")
    beamInst.Attachment0    = att0
    beamInst.Attachment1    = att1
    beamInst.Width0         = 1
    beamInst.Width1         = 1
    beamInst.Segments       = 25
    beamInst.FaceCamera     = true
    beamInst.LightEmission  = 0.9
    beamInst.Texture = "rbxassetid://16686518302"
    beamInst.TextureLength = 1
    beamInst.TextureMode = Enum.TextureMode.Static
    beamInst.TextureSpeed = 5
    beamInst.LightInfluence = 0.1
    beamInst.CurveSize0     = 0
    beamInst.CurveSize1     = 0
    beamInst.Color          = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   color),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1,   color),
    })
    beamInst.Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.15),
        NumberSequenceKeypoint.new(0.5, 0.0),
        NumberSequenceKeypoint.new(1,   0.15),
    })
    beamInst.Parent = hrp  -- parent to HRP so it gets cleaned up on respawn automatically
end

-- ─────────────────────────────────────────────────────────────────
-- Tutorial lifecycle
-- ─────────────────────────────────────────────────────────────────
function TutorialController:StartTutorial()
    if tutorialActive then return end

    local ok = TutorialController.TutorialService:GetIsFirstTimeLoad()
    if not ok then
        print("[TutorialController] Not a first-time player, skipping tutorial.")
        return
    end
    isFirstTimePlayer = true
    tutorialActive   = true
    currentStepIndex = 1

    self:BuildGui()

    -- Rebuild beam on character respawn without restarting the whole tutorial
    respawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart", 10)
        task.wait(0.3) -- let physics settle
        if tutorialActive then
            self:RebuildBeamForCurrentStep()
        end
    end)

    self:RunStep(1)
end

function TutorialController:ClearStepListeners()
    for _, c in ipairs(stepConns) do
        c:Disconnect()
    end
    stepConns = {}
end

function TutorialController:RunStep(index)
    currentStepIndex = index
    local step = STEPS[index]
    if not step then return end

    self:ClearBeam()
    self:ClearStepListeners()
    self:UpdateGuiForStep(step)

    if step.id == "shop" then
        self:RunShopStep(step)
    elseif step.id == "block" then
        self:RunBlockStep(step)
    elseif step.id == "base" then
        self:RunBaseStep(step)
    end
end

function TutorialController:RebuildBeamForCurrentStep()
    local step = STEPS[currentStepIndex]
    if not step then return end

    self:ClearBeam()

    if step.id == "shop" then
        self:SetBeamTarget(findShopPart(), step.beamColor)

    elseif step.id == "block" then
        self:SetBeamTarget(findNearestBlock(), step.beamColor)
        self:StartBlockRetargetLoop(step)

    elseif step.id == "base" then
        self:SetBeamTarget(findPlayerBase(), step.beamColor)
    end
end

-- ─────────────────────────────────────────────────────────────────
-- Step: Shop
-- ─────────────────────────────────────────────────────────────────
function TutorialController:RunShopStep(step)
    self:SetBeamTarget(findShopPart(), step.beamColor)

    local shopGui = PlayerGui:WaitForChild("FootballShopGui", 10)
    if not shopGui then
        warn("[TutorialController] FootballShopGui not found")
        return
    end

    local frame       = shopGui:WaitForChild("FootballsFrame", 5)
    local scroll      = frame and frame:WaitForChild("Scroll", 5)
    local closeButton: ImageButton = frame and frame:WaitForChild("CloseButton", 5)

    -- Hide close arrow initially
    local closeArrow = closeButton and closeButton:FindFirstChild("Arrow")
    if closeArrow then closeArrow.Visible = false end

    -- Show equip arrow on the first football in scroll
    local function activateEquipArrow()
        if not scroll then return end
        for _, item in ipairs(scroll:GetChildren()) do
            if item.Name ~= "Basic" then
                continue
            end
            local equip = item:WaitForChild("Frame"):FindFirstChild("Equip")
            if equip then
                local arrow = equip:FindFirstChild("Arrow")
                if arrow then
                    arrow.Visible = true
                end
            end
        end
    end

    local function deactivateEquipArrows()
        if not scroll then return end
        for _, item in ipairs(scroll:GetChildren()) do
            if item.Name ~= "Basic" then
                continue
            end
            local equip = item:WaitForChild("Frame"):FindFirstChild("Equip")
            if equip then
                local arrow = equip:FindFirstChild("Arrow")
                if arrow then arrow.Visible = false end
            end
        end
    end

    -- Wait for the shop to actually open before showing arrows
    if shopGui.Enabled then
        activateEquipArrow()
    else
        local c = shopGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if shopGui.Enabled then
                activateEquipArrow()
            end
        end)
        table.insert(stepConns, c)
    end

    -- Step 1 done: football bought/equipped
    local c1 = TutorialController.TutorialService.FootballBought:Connect(function()
        deactivateEquipArrows()
        if closeArrow then closeArrow.Visible = true end
    end)
    table.insert(stepConns, c1)

    -- Close button clicked = player is done with shop, advance
    if closeButton then
        local c2 = closeButton.MouseButton1Click:Connect(function()
            if not tutorialActive or not isFirstTimePlayer then return end
            if closeArrow then closeArrow.Visible = false end
            self:AdvanceStep()
        end)
        table.insert(stepConns, c2)
    end
end

-- ─────────────────────────────────────────────────────────────────
-- Step: Block
-- ─────────────────────────────────────────────────────────────────
function TutorialController:StartBlockRetargetLoop(step)
    local lastCheck = 0
    heartbeatConn = RunService.Heartbeat:Connect(function()
        if not tutorialActive or currentStepIndex ~= 2 then return end
        local now = tick()
        if now - lastCheck < 3 then return end
        lastCheck = now

        local currentTarget = att1 and att1.Parent  -- nil if block was destroyed
        local newBlock = findNearestBlock()
        if newBlock and newBlock ~= currentTarget then
            self:SetBeamTarget(newBlock, step.beamColor)
            self:StartBlockRetargetLoop(step) -- restarts with new heartbeat
        end
    end)
end

function TutorialController:RunBlockStep(step)
    self:SetBeamTarget(findNearestBlock(), step.beamColor)
    self:StartBlockRetargetLoop(step)

    local normalFolder = workspace:FindFirstChild("Blocks")
                     and workspace.Blocks:FindFirstChild("Normal")

    if normalFolder then
        local c = normalFolder.ChildRemoved:Connect(function()
            if not tutorialActive or not isFirstTimePlayer or currentStepIndex ~= 2 then return end
            task.delay(0.5, function()
                if tutorialActive and isFirstTimePlayer and currentStepIndex == 2 then
                    self:AdvanceStep()
                end
            end)
        end)
        table.insert(stepConns, c)
    else
        warn("[TutorialController] workspace.Blocks.Normal not found; block step won't auto-advance")
    end
end

-- ─────────────────────────────────────────────────────────────────
-- Step: Base
-- ─────────────────────────────────────────────────────────────────
function TutorialController:RunBaseStep(step)
    local basePart = findPlayerBase()
    self:SetBeamTarget(basePart, step.beamColor)

    -- Primary: server fires BrainrotPlaced when the placement is confirmed
    local c1 = TutorialController.TutorialService.BrainrotPlaced:Connect(function()
        self:FinishTutorial()
    end)
    table.insert(stepConns, c1)

    -- Fallback: watch base model for any new child (catches placement locally)
    if basePart and basePart.Parent then
        local baseModel = basePart.Parent
        local c2 = baseModel.ChildAdded:Connect(function()
            if tutorialActive and isFirstTimePlayer and currentStepIndex == 3 then
                task.delay(0.2, function()
                    self:FinishTutorial()
                end)
            end
        end)
        table.insert(stepConns, c2)
    end
end

-- ─────────────────────────────────────────────────────────────────
-- Advance / Finish
-- ─────────────────────────────────────────────────────────────────
function TutorialController:AdvanceStep()
    if not tutorialActive or not isFirstTimePlayer then return end

    if currentStepIndex < #STEPS then
        self:RunStep(currentStepIndex + 1)
    else
        self:FinishTutorial()
    end
end

function TutorialController:FinishTutorial()
    if not tutorialActive or not isFirstTimePlayer then return end
    tutorialActive = false

    self:ClearBeam()
    self:ClearStepListeners()

    if respawnConn then
        respawnConn:Disconnect()
        respawnConn = nil
    end

    -- Fade out the GUI elements
    if tutorialGui then
        for _, child in ipairs(tutorialGui:GetChildren()) do
            if child:IsA("GuiObject") then
                TweenService:Create(child, TweenInfo.new(0.5), {
                    BackgroundTransparency = 1,
                }):Play()
                for _, gc in ipairs(child:GetChildren()) do
                    if gc:IsA("TextLabel") then
                        TweenService:Create(gc, TweenInfo.new(0.5), {
                            TextTransparency = 1,
                        }):Play()
                    end
                end
            end
        end

        task.delay(0.6, function()
            if tutorialGui then
                tutorialGui:Destroy()
                tutorialGui = nil
            end
        end)
        isFirstTimePlayer = false
    end

	self.TutorialService.FinishTutorial:Fire()
    print("[TutorialController] Tutorial complete!")
end

return TutorialController