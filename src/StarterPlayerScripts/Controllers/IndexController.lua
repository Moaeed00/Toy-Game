local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)

local BrainrotsData = require(ReplicatedStorage.Configuration.Brainrots.EntitiesConfiguration)
local BrainrotVariantsConfig = require(ReplicatedStorage.Configuration.Brainrots.BrainrotsVariantConfig)
local PlayerGui = Player:WaitForChild("PlayerGui")
local IndexGui: ScreenGui = PlayerGui:WaitForChild("IndexGui")
local IndexFrame: Frame = IndexGui:WaitForChild("IndexFrame")
local BasesFrame: Frame = IndexFrame:WaitForChild("Bases")
local CloseButton: ImageButton = IndexFrame:WaitForChild("CloseButton")
local Gradients = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Gradients")

local PROCESSED_DATA = BrainrotsData.Processed
local BASE_VARIANT = "Normal"

local ORDERED_VARIANTS: { { Prefix: string, Color: Color3 } } = {
    { Prefix = BASE_VARIANT, Color = Color3.fromRGB(180, 180, 180) },
}
for _, v in ipairs(BrainrotVariantsConfig.VARIANTS) do
	if v.Prefix ~= BASE_VARIANT then
		table.insert(ORDERED_VARIANTS, { Prefix = v.Prefix, Color = v.Color })
	end
end

local MULTIPLIER_TIERS = {
    { threshold = 0.10, multiplier = 0.1  },
    { threshold = 0.25, multiplier = 0.25 },
    { threshold = 0.50, multiplier = 0.5  },
    { threshold = 0.75, multiplier = 0.75 },
    { threshold = 1.00, multiplier = 1.0  },
}

local TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function makeAttributeKey(variantPrefix: string, brainrotName: string): string
    local sanitised = brainrotName:gsub("[ -]", "_")
    if variantPrefix == BASE_VARIANT then
        return sanitised
    else
        return variantPrefix .. "_" .. sanitised
    end
end

--- Derive the display name from an attrKey by stripping the variant prefix.
---   "Golden_Trippi_Troppi" → "Trippi Troppi"
---   "Trippi_Troppi"        → "Trippi Troppi"
local function attributeKeyToDisplay(attrKey: string): string
    local result = attrKey
    for _, v in ipairs(ORDERED_VARIANTS) do
        if v.Prefix ~= BASE_VARIANT then
            result = result:gsub("^" .. v.Prefix .. "_", "")
            break
        end
    end
    return result:gsub("_", " ")
end

local function nextTier(pct: number): { threshold: number, multiplier: number }?
    for _, tier in ipairs(MULTIPLIER_TIERS) do
        if pct < tier.threshold then return tier end
    end
    return nil
end

local IndexController = Knit.CreateController { Name = "IndexController" }

IndexController._frame          = nil :: Frame?
-- { [attrKey]: Frame }  —  the card clone for each brainrot×variant entry
IndexController._cards          = {} :: { [string]: Frame }
-- { [variantPrefix]: Frame }  —  the variant scroll frame for tab switching
IndexController._variantFrames  = {} :: { [string]: Frame }
-- { [variantPrefix]: TextButton | ImageButton }
IndexController._tabs           = {} :: { [string]: GuiButton }
IndexController._activeVariant  = BASE_VARIANT
IndexController._unlocked       = {} :: { [string]: boolean }
IndexController._indexService   = nil

-- ── Cached UI references (set in _buildUI) ────────────────────────────────────
IndexController._discoveredLabel = nil :: TextLabel?
IndexController._completionLabel = nil :: TextLabel?
IndexController._progressFill    = nil :: Frame?
IndexController._progressLabel   = nil :: TextLabel?
IndexController._progressInfo    = nil :: Instance?
IndexController._brainrotsFolder = nil

function IndexController:KnitStart()
    self._indexService = Knit.GetService("IndexService")
    IndexController.LobbyHud = Knit.GetController("Hud")
    self._indexService:GetDiscovered():andThen(function(discovered: {})
       self._unlocked = discovered
    end)

    self:_buildUI()
    self:ConnectCloseButton()

    -- Real-time unlock pushed from the server
    self._indexService.BrainrotUnlocked:Connect(function(brainrotName: string, variantPrefix: string)
        local key = makeAttributeKey(variantPrefix, brainrotName)
        self._unlocked[key] = true
        self:_refreshCard(key)
        self:_refreshStats()
    end)

    -- Fallback: AllBrainrots AttributeChanged (covers any other unlock paths)
    self._brainrotsFolder.AttributeChanged:Connect(function(attrKey: string)
        local value = self._brainrotsFolder:GetAttribute(attrKey)
        self._unlocked[attrKey] = value == true or nil
        self:_refreshCard(attrKey)
        self:_refreshStats()
    end)
end

function IndexController:ConnectCloseButton()
    CloseButton.Activated:Connect(function()
        self.LobbyHud:OpenContainer("MainGui")
    end)
end

function IndexController:_buildUI()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local gui = playerGui:WaitForChild("IndexGui")
    local frame = gui:WaitForChild("IndexFrame")
    self._frame = frame

    local normalFrame = frame:WaitForChild("Normal")
    local temp = normalFrame:WaitForChild("Temp")
    local tabsFrame = frame:WaitForChild("Tabs")
    local labelFrame = frame:WaitForChild("Label")
    local progressFrame = frame:WaitForChild("Progress")
    local progressInfo = frame:WaitForChild("ProgressInfo")

    temp.Visible = false

    -- Cache stat labels
    self._brainrotsFolder = Players.LocalPlayer:WaitForChild("AllBrainrots")
    self._discoveredLabel = labelFrame:WaitForChild("Discovered")
    self._completionLabel = labelFrame:WaitForChild("Completion")
    self._progressFill = progressFrame:WaitForChild("Frame")
    self._progressLabel = progressFrame:WaitForChild("TextLabel")
    self._progressInfo = progressInfo

    -- ── Build variant frames ────────────────────────────────────────────────
    -- Normal already exists. Clone it for every other variant, then parent
    -- the clone directly under IndexFrame (matching original decompile).
    self._variantFrames[BASE_VARIANT] = normalFrame

    for _, variantInfo in ipairs(ORDERED_VARIANTS) do
        local prefix = variantInfo.Prefix
        if prefix == BASE_VARIANT then continue end

        -- Re-use an existing clone if a previous run already created it
        local existing = frame:FindFirstChild(prefix)
        if existing then
            self._variantFrames[prefix] = existing
            existing.Visible = false
            -- Hide its Temp too
            local t = existing:FindFirstChild("Temp")
            if t then
                t.Visible = false
            end
        else
            local clone = normalFrame:Clone()
            clone.Name    = prefix
            clone.Visible = false
            clone.Parent  = frame

            -- Clear cards that were duplicated from Normal's children
            for _, child in ipairs(clone:GetChildren()) do
                if child.Name ~= "UIGridLayout"
                    and child.Name ~= "UIPadding"
                    and child.Name ~= "UIAspectRatioConstraint"
                    and child.Name ~= "Hover"
                    and child.Name ~= "Temp" then
                    child:Destroy()
                end
            end

            local clonedTemp = clone:FindFirstChild("Temp")
            if clonedTemp then
                clonedTemp.Visible = false
            end

            self._variantFrames[prefix] = clone
        end
    end

    -- ── Wire tab buttons ───────────────────────────────────────────────────
    -- Tabs frame contains pre-built buttons. Match them to variant prefixes
    -- by Name. The button Name must equal the variant Prefix (e.g. "Golden").
    for _, variantInfo in ipairs(ORDERED_VARIANTS) do
        local prefix = variantInfo.Prefix
        local btn = tabsFrame:FindFirstChild(prefix) :: GuiButton

        if btn and (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
            self._tabs[prefix] = btn
            btn.MouseButton1Click:Connect(function()
                self:_switchVariant(prefix)
            end)
        end
    end

    -- ── Populate cards ─────────────────────────────────────────────────────
    -- One card per (brainrot × variant) pair.
    for brainrotName, data in pairs(PROCESSED_DATA) do
        for _, variantInfo in ipairs(ORDERED_VARIANTS) do
            local prefix = variantInfo.Prefix
            local key = makeAttributeKey(prefix, brainrotName)
            local targetFrame = self._variantFrames[prefix]
            if not targetFrame then
                continue
            end

            local templateInFrame = targetFrame:FindFirstChild("Temp") or temp
            local card = templateInFrame:Clone()
            card.Name = key
            card.Visible = true
            card.LayoutOrder = tonumber(data.CashPerSecond)

            local cardInner = card:WaitForChild("Frame")
            local imgLabel = cardInner:WaitForChild("Frame"):WaitForChild("ImageLabel")
            local itemName = cardInner:WaitForChild("ItemName")
            local itemRarity = cardInner:WaitForChild("ItemRarity")

            imgLabel.Image = data.Icon[prefix] or data.Icon["Normal"]
            itemRarity.Text = data.RarityType or "Common"

            if data.RarityType then
                local gradient = Gradients:FindFirstChild(data.RarityType)
                if gradient then
                    gradient:Clone().Parent = cardInner
                    gradient:Clone().Parent = cardInner:WaitForChild("Frame")
                end
            end
            card.Parent = targetFrame

            self._cards[key] = card
            self:_applyCardState(imgLabel, itemName, key)
        end
    end

    self:_switchVariant(BASE_VARIANT)
    self:_refreshStats()
end

function IndexController:SetEnabled(enabled: boolean)
	IndexGui.Enabled = enabled
    if enabled == true then
        self:_refreshStats()
    end
end

function IndexController:_applyCardState(imgLabel: ImageLabel, itemName: TextLabel, attrKey: string)
    local isUnlocked = self._brainrotsFolder:GetAttribute(attrKey) == true

    if isUnlocked then
        imgLabel.ImageColor3 = Color3.new(1, 1, 1)
        itemName.Text = attributeKeyToDisplay(attrKey)
    else
        imgLabel.ImageColor3 = Color3.new(0, 0, 0)
        itemName.Text = "???"
    end
end

--- Re-apply card state when an unlock arrives. Navigates the stored card Frame
--- to retrieve its inner elements without storing extra references per card.
function IndexController:_refreshCard(attrKey: string)
    local card = self._cards[attrKey]
    if not card then return end

    local cardInner = card:FindFirstChild("Frame")
    if not cardInner then return end

    local imgLabel = cardInner:FindFirstChild("Frame") and cardInner.Frame:FindFirstChild("ImageLabel")
    local itemName = cardInner:FindFirstChild("ItemName")

    if imgLabel and itemName then
        self:_applyCardState(imgLabel, itemName, attrKey)
    end
end

function IndexController:_refreshStats()
    local totalAll, foundAll = 0, 0
    local totalVar, foundVar = 0, 0

    for brainrotName in pairs(PROCESSED_DATA) do
        for _, variantInfo in ipairs(ORDERED_VARIANTS) do
            local key = makeAttributeKey(variantInfo.Prefix, brainrotName)
            totalAll += 1
            if self._unlocked[key] then
                foundAll += 1
            end

            if variantInfo.Prefix == self._activeVariant then
                totalVar += 1
                if self._unlocked[key] then
                    foundVar += 1
                end
            end
        end
    end

    -- Label frame → Discovered / Completion
    local globalPct = totalAll > 0 and (foundAll / totalAll) or 0
    if self._discoveredLabel then
        self._discoveredLabel.Text = foundAll .. " / " .. totalAll .. " discovered"
    end
    if self._completionLabel then
        self._completionLabel.Text = math.floor(globalPct * 100) .. "% complete"
    end

    -- Progress frame → TextLabel (count) + Frame (fill bar)
    if self._progressLabel then
        self._progressLabel.Text = foundVar .. " / " .. totalVar
    end
    if self._progressFill then
        local fillPct = totalVar > 0 and math.clamp(1 - foundVar / totalVar, 0, 1) or 0
        TweenService:Create(self._progressFill, TWEEN_INFO, {
            Size = UDim2.fromScale(fillPct, 1),
        }):Play()
    end

    -- ProgressInfo → multiplier banner text
    if self._progressInfo then
        local next = nextTier(globalPct)
        local banner: string
        if next then
            banner = string.format("Collect %d%% for +%.2gx Cash", math.floor(next.threshold * 100), next.multiplier)
        else
            banner = "Max index multiplier reached!"
        end

        if self._progressInfo:IsA("TextLabel") then
            self._progressInfo.Text = banner
        else
            local label = self._progressInfo:FindFirstChildWhichIsA("TextLabel")
            if label then
                label.Text = banner
            end
        end
    end

    self:_refreshBaseButtons()
end

function IndexController:_refreshBaseButtons()
    if not BasesFrame then
        return
    end

    local anyCompleted = false
    for _, variantInfo in ipairs(ORDERED_VARIANTS) do
        local prefix = variantInfo.Prefix
        local button: ImageButton = BasesFrame:FindFirstChild(prefix)
        if not button then
            continue
        end

        -- Count how many of this variant the player has found
        local total, found = 0, 0
        for brainrotName in pairs(PROCESSED_DATA) do
            local key = makeAttributeKey(prefix, brainrotName)
            total += 1
            if self._unlocked[key] then
                found += 1
            end
        end

        local completed = total > 0 and found >= total
        if completed then
            anyCompleted = true
        end

        button.Active = completed
        button.AutoButtonColor = completed
        button.Visible = completed
        BasesFrame.Visible = anyCompleted

        button.MouseButton1Click:Connect(function()
            print("Variant", prefix)
            self._indexService:SetBaseColor(prefix)
        end)
    end
end

function IndexController:_switchVariant(prefix: string)
    self._activeVariant = prefix

    -- Show only the active variant frame
    for variantPrefix, variantFrame in pairs(self._variantFrames) do
        variantFrame.Visible = (variantPrefix == prefix)
    end

    -- Highlight active tab; dim others
    for tabPrefix, btn in pairs(self._tabs) do
        btn.BackgroundTransparency = (tabPrefix == prefix) and 0 or 0.45
    end

    self:_refreshStats()
end

return IndexController