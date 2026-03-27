local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local TutorialController = Knit.CreateController { Name = "TutorialController" }

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local STEPS = {
    {
        stepType     = "equip",
        handEmoji    = "👇",
        instructText = "Equip Football from your backpack!",
    },
    {
        stepType     = "click",
        side         = "Left",
        xScale       = 0.18,
        yScale       = 0.38,
        handEmoji    = "👈",
        instructText = "Click here to kick\nin this direction!",
    },
    {
        stepType     = "click",
        side         = "Right",
        xScale       = 0.82,
        yScale       = 0.38,
        handEmoji    = "👉",
        instructText = "Now kick this way!",
    },
}

local tutorialGui  : ScreenGui? = nil
local currentStep  : number     = 1
local tutorialActive : boolean  = false
local stepConnection : RBXScriptConnection? = nil

function TutorialController:KnitInit()
end

function TutorialController:KnitStart()
    TutorialController.TutorialService = Knit.GetService("TutorialService")

    TutorialController.TutorialService.BeginTutorial:Connect(function()
        self:StartTutorial()
    end)
end

function TutorialController:StartTutorial()
    if tutorialActive then
        return
    end
    print("[TutorialController] Starting tutorial...")

    tutorialActive = true
    currentStep    = 1
    tutorialGui    = self:BuildTutorialGui()

    -- Fade in overlay
    local overlay = tutorialGui:FindFirstChild("Overlay")
    if overlay then
        TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
    end

    self:ShowStep(currentStep)
    self:WireStep(currentStep)
end

function TutorialController:MakeRoundFrame(parent, name, size, anchorPoint, bgColor, transparency, zIndex, cornerRatio)
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = size
    f.AnchorPoint      = anchorPoint or Vector2.new(0.5, 0.5)
    f.BackgroundColor3 = bgColor or Color3.fromRGB(255,255,255)
    f.BackgroundTransparency = transparency or 0
    f.BorderSizePixel  = 0
    f.ZIndex           = zIndex or 1
    f.Parent           = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(cornerRatio or 0, 0)
    corner.Parent = f
    return f
end

function TutorialController:BuildTutorialGui() : ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name           = "TutorialGui"
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.Parent         = PlayerGui

    -- ── Dark overlay ──────────────────────────────────────────────────────────
    local overlay = Instance.new("Frame")
    overlay.Name                   = "Overlay"
    overlay.Size                   = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 1   -- fades in on StartTutorial
    overlay.BorderSizePixel        = 0
    overlay.ZIndex                 = 1
    overlay.Parent                 = gui

    -- ── Pointing hand label ────────────────────────────────────────────────────
    local hand = Instance.new("TextLabel")
    hand.Name                   = "Hand"
    hand.Size                   = UDim2.fromOffset(64, 64)
    hand.AnchorPoint            = Vector2.new(0.5, 0.5)
    hand.BackgroundTransparency = 1
    hand.Text                   = "👇"
    hand.TextTransparency       = 1   -- fades in per step
    hand.TextScaled             = true
    hand.Font                   = Enum.Font.GothamBold
    hand.ZIndex                 = 5
    hand.Parent                 = gui

    -- ── Instruction text card ─────────────────────────────────────────────────
    local card = self:MakeRoundFrame(gui, "Card",
        UDim2.fromOffset(240, 76), Vector2.new(0.5, 1),
        Color3.fromRGB(15, 15, 15), 1, 4, 0.2)   -- starts invisible

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft   = UDim.new(0, 12)
    padding.PaddingRight  = UDim.new(0, 12)
    padding.PaddingTop    = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent        = card

    local cardText = Instance.new("TextLabel")
    cardText.Name                   = "Text"
    cardText.Size                   = UDim2.fromScale(1, 1)
    cardText.BackgroundTransparency = 1
    cardText.Text                   = ""
    cardText.TextColor3             = Color3.fromRGB(255, 255, 255)
    cardText.TextTransparency       = 1   -- fades in per step
    cardText.Font                   = Enum.Font.GothamBold
    cardText.TextSize               = 17
    cardText.TextWrapped            = true
    cardText.ZIndex                 = 5
    cardText.Parent                 = card

    return gui
end

local activePulseTween : Tween? = nil
local activeBobTween   : Tween? = nil

function TutorialController:CancelActiveTweens()
    if activePulseTween then
        activePulseTween:Cancel()
        activePulseTween = nil
    end
    if activeBobTween then
        activeBobTween:Cancel()
        activeBobTween = nil
    end
end

function TutorialController:FadeIn(instance, props, duration)
    TweenService:Create(instance, TweenInfo.new(duration or 0.3), props):Play()
end

function TutorialController:ShowEquipStep(step)
    local hand     = tutorialGui:FindFirstChild("Hand")
    local card     = tutorialGui:FindFirstChild("Card")
    local cardText = card and card:FindFirstChild("Text")

    -- Hand points straight down toward inventory (centre-bottom area)
    hand.Position = UDim2.fromScale(0.5, 0.72)
    hand.Text     = step.handEmoji
    self:FadeIn(hand, { TextTransparency = 0 }, 0.3)

    card.Position = UDim2.new(0.5, 0, 0.72, -80)
    self:FadeIn(card, { BackgroundTransparency = 0.10 }, 0.3)
    if cardText then
        cardText.Text = step.instructText
        self:FadeIn(cardText, { TextTransparency = 0 }, 0.3)
    end

    self:CancelActiveTweens()
    activeBobTween = TweenService:Create(
        hand,
        TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Position = UDim2.new(0.5, 0, 0.72, 14) }
    )
    activeBobTween:Play()
end

function TutorialController:ShowClickStep(step)
    local hand     = tutorialGui:FindFirstChild("Hand")
    local card     = tutorialGui:FindFirstChild("Card")
    local cardText = card and card:FindFirstChild("Text")

    -- Hand sits in the centre of the target half, slightly above mid-screen
    -- Left half centre = 0.25, Right half centre = 0.75
    local halfCentreX = (step.side == "Left") and 0.3 or 0.7
    hand.Position = UDim2.fromScale(halfCentreX, 0.42)
    hand.Text     = step.handEmoji
    self:FadeIn(hand, { TextTransparency = 0 }, 0.25)

    -- Card floats above the hand
    card.Position = UDim2.new(halfCentreX, 0, 0.42, -90)
    self:FadeIn(card, { BackgroundTransparency = 0.10 }, 0.25)
    if cardText then
        cardText.Text = step.instructText
        self:FadeIn(cardText, { TextTransparency = 0 }, 0.25)
    end

    -- Bob: hand drifts left/right in the direction it's pointing
    self:CancelActiveTweens()
    local bobOffsetX = (step.side == "Left") and -14 or 14
    activeBobTween = TweenService:Create(
        hand,
        TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Position = UDim2.new(halfCentreX, bobOffsetX, 0.42, 0) }
    )
    activeBobTween:Play()
end

function TutorialController:ShowStep(stepIndex: number)
    if not tutorialGui then
        return
    end
    local step = STEPS[stepIndex]
    if not step then
        return
    end

    if step.stepType == "equip" then
        self:ShowEquipStep(step)
    else
        self:ShowClickStep(step)
    end
end

function TutorialController:WireStep(stepIndex: number)
    if stepConnection then
        stepConnection:Disconnect()
        stepConnection = nil
    end

    local step = STEPS[stepIndex]
    if not step then
        return
    end

    if step.stepType == "equip" then
        stepConnection = TutorialController.TutorialService.FootballEquipped:Connect(function()
            self:AdvanceStep()
        end)
    else
        stepConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

            local mousePos = UserInputService:GetMouseLocation()
            local screenSize = workspace.CurrentCamera.ViewportSize

            local center = screenSize.X / 2
            local margin = 30
            local isLeft = mousePos.X < (center - margin)
            local isRight = mousePos.X > (center + margin)

            if (step.side == "Left" and isLeft) or (step.side == "Right" and isRight) then
                self:AdvanceStep()
            end
        end)
    end
end

function TutorialController:FinishTutorial()
    tutorialActive = false
    self:CancelActiveTweens()

    if stepConnection then
        stepConnection:Disconnect()
        stepConnection = nil
    end

    task.delay(0.35, function()
        if not tutorialGui then return end

        -- Fade out everything
        for _, child in tutorialGui:GetChildren() do
            if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
                TweenService:Create(child, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    TweenService:Create(child, TweenInfo.new(0.55), { TextTransparency = 1 }):Play()
                end
                for _, grandchild in child:GetChildren() do
                    if grandchild:IsA("TextLabel") then
                        TweenService:Create(grandchild, TweenInfo.new(0.55), {
                            TextTransparency = 1,
                            BackgroundTransparency = 1,
                        }):Play()
                    end
                end
            end
        end

        task.delay(0.65, function()
            if tutorialGui then
                tutorialGui:Destroy()
                tutorialGui = nil
            end
        end)
    end)

    TutorialController.TutorialService:CompleteTutorial()
    print("[TutorialController] Tutorial complete!")
end

function TutorialController:AdvanceStep()
    if not tutorialActive then
        return
    end

    if stepConnection then
        stepConnection:Disconnect()
        stepConnection = nil
    end

    local hand = tutorialGui and tutorialGui:FindFirstChild("Hand")
    self:CancelActiveTweens()

    -- Brief hand bounce to signal success
    if hand then
        TweenService:Create(hand, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(80, 80),
        }):Play()
        task.delay(0.15, function()
            if hand and hand.Parent then
                TweenService:Create(hand, TweenInfo.new(0.12), {
                    Size = UDim2.fromOffset(64, 64),
                }):Play()
            end
        end)
    end

    task.delay(0.28, function()
        if not tutorialActive then
            return
        end

        if currentStep < #STEPS then
            currentStep += 1
            self:ShowStep(currentStep)
            self:WireStep(currentStep)
        else
            self:FinishTutorial()
        end
    end)
end

return TutorialController