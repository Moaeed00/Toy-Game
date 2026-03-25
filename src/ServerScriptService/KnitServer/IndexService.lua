local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local IndexService = Knit.CreateService {
    Name = "IndexService",
    Client = {
        -- Fired to the owning client on a brand-new unlock.
        -- Args passed to client: brainrotName (string), variantPrefix (string)
        BrainrotUnlocked = Knit.CreateSignal()
    },
    _dataHandler = nil :: any,
}

local BrainrotsData = require(ReplicatedStorage.Configuration.Brainrots.EntitiesConfiguration)
local BrainrotVariantsConfig = require(ReplicatedStorage.Configuration.Brainrots.BrainrotsVariantConfig)

local PROCESSED_DATA = BrainrotsData.Processed
local BASE_VARIANT   = "Normal"

local ALL_VARIANTS: { string } = { BASE_VARIANT }
for _, v in ipairs(BrainrotVariantsConfig.VARIANTS) do
    table.insert(ALL_VARIANTS, v.Prefix)
end

local _originalPartState: { [number]: { [BasePart]: { Color: Color3, Material: Enum.Material } } } = {}

local MULTIPLIER_TIERS = {
    { threshold = 0.10, multiplier = 0.1  },
    { threshold = 0.25, multiplier = 0.25 },
    { threshold = 0.50, multiplier = 0.5  },
    { threshold = 0.75, multiplier = 0.75 },
    { threshold = 1.00, multiplier = 1.0  },
}

local function makeAttributeKey(variantPrefix: string, brainrotName: string): string
    local sanitised = brainrotName:gsub("[ -]", "_")
    if variantPrefix == BASE_VARIANT then
        return sanitised
    else
        return variantPrefix .. "_" .. sanitised
    end
end

--- Total number of discoverable entries (base brainrots × all variants).
local function totalEntries(): number
    local n = 0
    for _ in pairs(PROCESSED_DATA) do
        n += 1
    end
    return n * #ALL_VARIANTS
end

--- Count true entries in a discovered map.
local function countUnlocked(discovered: { [string]: boolean }): number
    local n = 0
    for _, v in pairs(discovered) do
        if v then
            n += 1
        end
    end
    return n
end

--- Best multiplier tier reached.
local function calculateMultiplier(discovered: { [string]: boolean }): number
    local pct  = countUnlocked(discovered) / math.max(1, totalEntries())
    local best = 0
    for _, tier in ipairs(MULTIPLIER_TIERS) do
        if pct >= tier.threshold then
            best = tier.multiplier
        end
    end
    return best
end

-- ── AllBrainrots folder ───────────────────────────────────────────────────────
-- One attribute per (variant × brainrot) pair so LocalScripts read state
-- without a remote call — mirrors the original decompiled LocalScript pattern.
local function syncFolder(player: Player, discovered: { [string]: boolean })
    local folder = player:FindFirstChild("AllBrainrots")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "AllBrainrots"
        folder.Parent = player
    end

    for brainrotName in pairs(PROCESSED_DATA) do
        for _, variant in ipairs(ALL_VARIANTS) do
            local key = makeAttributeKey(variant, brainrotName)
            folder:SetAttribute(key, discovered[key] == true)
        end
    end
end

-- ── Internal: get the live DiscoveredBrainrots sub-table ─────────────────────
-- We mutate this table directly; ProfileStore serialises the whole Data table
-- on its own save cycle, so no extra SetPlayerData call is needed for the
-- nested table — only for top-level keys that DataHandlerService tracks.
function IndexService:_getDiscovered(player: Player): { [string]: boolean }?
    local data = self._dataHandler:GetPlayerData(player)
    if not data then
        warn(`[IndexService] No profile data for {player.Name}`)
        return nil
    end

    -- Guard against old profiles that predate this field (Reconcile only
    -- handles top-level keys, so we patch nested tables manually).
    if type(data.DiscoveredBrainrots) ~= "table" then
        data.DiscoveredBrainrots = {}
    end

    return data.DiscoveredBrainrots
end

-- ── Public server-side API ────────────────────────────────────────────────────

--- Unlock a brainrot for a player.
--- Returns true only on the first-ever discovery (caller can use this to
--- trigger fanfare, bonus cash, announcements, etc.).
function IndexService:UnlockBrainrot(player: Player, brainrotName: string, variantPrefix: string): boolean
    local discovered = self:_getDiscovered(player)
    if not discovered then
        return false
    end

    local key = makeAttributeKey(variantPrefix, brainrotName)
    if discovered[key] then
        return false
    end

    -- ── 1. Persist (mutation is reflected in the live profile table) ──────────
    discovered[key] = true

    -- Notify DataHandlerService listeners (e.g. leaderboards, other services)
    -- so they stay in sync without coupling to IndexService directly.
    self._dataHandler:SetPlayerData(player, { DiscoveredBrainrots = discovered })

    -- ── 2. Replicate to AllBrainrots folder so LocalScripts see it immediately ─
    local folder = player:FindFirstChild("AllBrainrots")
    if folder then
        folder:SetAttribute(key, true)
    end

    -- ── 3. Notify the owning client (Index UI refresh) ────────────────────────
    self.Client.BrainrotUnlocked:Fire(player, brainrotName, variantPrefix)

    -- ── 4. Recalculate and apply cash multiplier ──────────────────────────────
    local multiplier = calculateMultiplier(discovered)
    self:_applyMultiplier(player, multiplier)

    return true
end

--- Total distinct brainrots (across all variants) discovered by this player.
function IndexService:GetDiscoveredCount(player: Player): number
    local discovered = self:_getDiscovered(player)
    return discovered and countUnlocked(discovered) or 0
end

--- Full discovered map  { [attrKey]: true }.
function IndexService:GetDiscovered(player: Player): { [string]: boolean }
    return self:_getDiscovered(player) or {}
end

--- Current cash-multiplier bonus earned through the Index.
function IndexService:GetMultiplier(player: Player): number
    return calculateMultiplier(self:GetDiscovered(player))
end

-- ── Client-facing wrappers (Knit exposes as RemoteFunctions) ──────────────────
function IndexService.Client:GetDiscovered(player: Player)
    return self.Server:GetDiscovered(player)
end

function IndexService.Client:GetMultiplier(player: Player)
    return self.Server:GetMultiplier(player)
end

-- ── Multiplier application ────────────────────────────────────────────────────
-- Writes the new MoneyMultiplier into the profile so the rest of the economy
-- (CashService, leaderboards, etc.) sees it automatically.
--
-- Current model: MoneyMultiplier = base value from upgrades + index bonus.
-- Adjust the formula below if your economy uses a different stacking model
-- (e.g. multiplicative rather than additive).
function IndexService:_applyMultiplier(player: Player, indexBonus: number)
    local data = self._dataHandler:GetPlayerData(player)
    if not data then return end

    -- Strip any previously applied index bonus so we don't double-stack.
    -- If you track base multiplier separately, replace this with that value.
    local baseMultiplier = (data.MoneyMultiplier or 1) - (data.IndexMultiplierBonus or 0)

    local newBonus = indexBonus
    local newMultiplier = math.max(1, baseMultiplier + newBonus)

    -- Persist both so we can correctly strip the bonus next time.
    self._dataHandler:SetPlayerData(player, {
        MoneyMultiplier = newMultiplier,
        IndexMultiplierBonus = newBonus,
    })
end

-- ── Variant appearance config ─────────────────────────────────────────────────
local VARIANT_APPEARANCE = {
    Normal   = { Color = nil, Material = Enum.Material.SmoothPlastic },
    Gold     = { Color = Color3.fromRGB(239, 184, 56), Material = Enum.Material.SmoothPlastic },
    Diamond  = { Color = Color3.fromRGB(175, 221, 255), Material = Enum.Material.SmoothPlastic },
    Lava     = { Color = Color3.fromRGB(255,  0,  0), Material = Enum.Material.CrackedLava },
    Galaxy   = { Color = Color3.fromRGB(123,  47, 123), Material = Enum.Material.SmoothPlastic },
    Rainbow  = { Color = nil, Material = Enum.Material.SmoothPlastic },
}

local _rainbowConnections: { [number]: RBXScriptConnection } = {}
local _rainbowGridConnections: { [number]: RBXScriptConnection } = {}

local function getEnvironmentParts(player: Player): { BasePart }
    local basesFolder = workspace:FindFirstChild("Bases")
    if not basesFolder then return {} end

    local baseModel = basesFolder:FindFirstChild(tostring(player.UserId))
    if not baseModel then return {} end

    local env = baseModel:FindFirstChild("Environment")
    if not env then return {} end

    local parts = {}
    for _, desc in ipairs(env:GetDescendants()) do
        if desc:IsA("BasePart") then
            table.insert(parts, desc)
        end
    end
    return parts
end

local function getGridPlatformParts(player: Player): { BasePart }
    local basesFolder = workspace:FindFirstChild("Bases")
    if not basesFolder then return {} end

    local baseModel = basesFolder:FindFirstChild(tostring(player.UserId))
    if not baseModel then return {} end

    local grid = baseModel:FindFirstChild("Grid")
    if not grid then return {} end

    local parts = {}
    for _, slot in ipairs(grid:GetChildren()) do
        local pb = slot:FindFirstChild("PlatformBase")
        if pb and pb:IsA("BasePart") then
            table.insert(parts, pb)
        end
    end
    return parts
end

local function stopRainbow(player: Player)
    if _rainbowConnections[player.UserId] then
        _rainbowConnections[player.UserId]:Disconnect()
        _rainbowConnections[player.UserId] = nil
    end
end

local function stopRainbowGrid(player: Player)
    if _rainbowGridConnections[player.UserId] then
        _rainbowGridConnections[player.UserId]:Disconnect()
        _rainbowGridConnections[player.UserId] = nil
    end
end

local _originalStopRainbow = stopRainbow
stopRainbow = function(player: Player)
    _originalStopRainbow(player)
    stopRainbowGrid(player)
end

function applyRainbow(player: Player)
    stopRainbow(player)

    local hue = 0
    _rainbowConnections[player.UserId] = game:GetService("RunService").Heartbeat:Connect(function(dt)
        hue = (hue + dt * 0.3) % 1
        local color = Color3.fromHSV(hue, 1, 1)
        local parts = getEnvironmentParts(player)
        for _, part in ipairs(parts) do
            if part and part.Parent then
                part.Color    = color
                part.Material = Enum.Material.SmoothPlastic
            end
        end
    end)
end

function applyRainbowGrid(player: Player)
    stopRainbowGrid(player)
    local hue = 0
    _rainbowGridConnections[player.UserId] = game:GetService("RunService").Heartbeat:Connect(function(dt)
        hue = (hue + dt * 0.3) % 1
        local color = Color3.fromHSV(hue, 1, 1)
        for _, part in ipairs(getGridPlatformParts(player)) do
            if part and part.Parent then
                part.Color    = color
                part.Material = Enum.Material.Neon
            end
        end
    end)
end


function captureOriginals(player: Player)
    if _originalPartState[player.UserId] then return end
    local saved = {}

    for _, part in ipairs(getEnvironmentParts(player)) do
        saved[part] = { Color = part.Color, Material = part.Material }
    end

    for _, part in ipairs(getGridPlatformParts(player)) do
        saved[part] = { Color = part.Color, Material = part.Material }
    end
    _originalPartState[player.UserId] = saved
end

function IndexService:SetBaseColor(player: Player, variantPrefix: string)
    -- Persist the choice
    local data = self._dataHandler:GetPlayerData(player)
    if not data then
        return
    end
    data.BaseColor = data.BaseColor or {}
    data.BaseColor[player.UserId] = variantPrefix
    self._dataHandler:SetPlayerData(player, {
        BaseColor = data.BaseColor
    })

    -- Stop any running rainbow loop
    stopRainbow(player)
    captureOriginals(player)

    local appearance = VARIANT_APPEARANCE[variantPrefix]
    if not appearance then
        warn("[IndexService] Unknown variant prefix:", variantPrefix)
        return
    end

    local function allTargetParts()
        local parts = getEnvironmentParts(player)
        for _, p in ipairs(getGridPlatformParts(player)) do   -- ← NEW
            table.insert(parts, p)
        end
        return parts
    end

    if variantPrefix == "Normal" then
        local saved = _originalPartState[player.UserId]
        if saved then
            for part, state in pairs(saved) do
                if part and part.Parent then
                    part.Color    = state.Color
                    part.Material = state.Material
                end
            end
        end
        return
    end

    if variantPrefix == "Rainbow" then
        applyRainbow(player)
        applyRainbowGrid(player)
        return
    end

    -- Static color application
    for _, part in ipairs(allTargetParts()) do
        if part and part.Parent then
            part.Color    = appearance.Color
            part.Material = appearance.Material
        end
    end
end

function IndexService.Client:SetBaseColor(player: Player, variantPrefix: string)
    self.Server:SetBaseColor(player, variantPrefix)
end

function IndexService:ApplySavedBaseColor(player: Player)
    local data = self._dataHandler:GetPlayerData(player)
    if not data then return end

    local baseColorTable = data.BaseColor
    if not baseColorTable then return end

    local variantPrefix = baseColorTable[player.UserId] or "Normal"
    if not variantPrefix then return end

    self:SetBaseColor(player, variantPrefix)
end

function IndexService:KnitStart()
    -- Resolve DataHandlerService after all services have initialised.
    self._dataHandler = Knit.GetService("DataHandlerService")

    -- Sync AllBrainrots folder the moment a profile finishes loading.
    -- OnPlayerProfileLoaded fires with (player, data) — data is the full table.
    self._dataHandler.OnPlayerProfileLoaded:Connect(function(player: Player, _data)
        -- self:ApplySavedBaseColor(player)
        local discovered = self:_getDiscovered(player)
        if discovered then
            syncFolder(player, discovered)
            -- Apply whatever multiplier was already earned from a previous session.
            local multiplier = calculateMultiplier(discovered)
            if multiplier > 0 then
                self:_applyMultiplier(player, multiplier)
            end
        end
    end)

    -- Clean up the AllBrainrots folder when the session ends (kick / disconnect).
    -- ProfileStore handles the actual save, so we just remove the folder.
    self._dataHandler.OnPlayerSessionEnded:Connect(function(player: Player)
        stopRainbow(player)
        _originalPartState[player.UserId] = nil
        local folder = player:FindFirstChild("AllBrainrots")
        if folder then
            folder:Destroy()
        end
    end)
end

return IndexService