-- CashAnimation.lua
-- ModuleScript — handles coin fly-to-wallet animation.
-- Place inside ReplicatedStorage/Libraries (or wherever your modules live).
--
-- Usage:
--   local CashAnimation = require(path.to.CashAnimation)
--   CashAnimation.init(MainGui)          -- call once on client startup
--   CashAnimation.play(prevValue, newValue) -- call whenever cash changes

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- ── Config ───────────────────────────────────────────────────────────────────
local POPUP_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LINEAR_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local COIN_DELAY = 0.06 -- seconds between staggered coin spawns
local BEZIER_STEPS = 10 -- arc smoothness
local BEZIER_SPREAD = 500 -- max control-point deviation (px)
local SPAWN_SPREAD = 0.2 -- spawn jitter as fraction of parent size
local MAX_COINS = 5 -- max coins per animation burst
local COIN_DEBRIS_TTL = 3 -- seconds before coin clone is auto-destroyed
local DELTA_PER_COIN = 50 -- every N cash gained = +1 coin (tune to your economy)

-- ── State ────────────────────────────────────────────────────────────────────
local AnimTarget = nil -- ImageLabel / Frame that coins fly toward
local CoinTemplate = nil -- ImageLabel cloned for each coin
local initialised = false

-- ── Private helpers ──────────────────────────────────────────────────────────

local function getCoinCount(delta: number): number
	if delta <= 0 then
		return 0
	end
	return math.clamp(math.ceil(delta / DELTA_PER_COIN), 1, MAX_COINS)
end

local function spawnCoinAnimations(count: number)
	local targetCenter = AnimTarget.AbsolutePosition + AnimTarget.AbsoluteSize / 2

	for i = 1, count do
		task.delay((i - 1) * COIN_DELAY, function()
			local coin = CoinTemplate:Clone()
			coin.Parent = CoinTemplate.Parent
			coin.Rotation = math.random(-15, 15)
			coin.Visible = true

			-- Jittered spawn origin
			local parentSize = CoinTemplate.Parent.AbsoluteSize
			local spawnOrigin = CoinTemplate.AbsolutePosition
			local spawnPoint = Vector2.new(
				spawnOrigin.X + (math.random() * SPAWN_SPREAD - SPAWN_SPREAD / 2) * parentSize.X,
				spawnOrigin.Y + (math.random() * SPAWN_SPREAD - SPAWN_SPREAD / 2) * parentSize.Y
			)

			-- Random bezier control point for arc variety
			local controlPoint = Vector2.new(
				spawnPoint.X + math.random(-BEZIER_SPREAD, BEZIER_SPREAD),
				spawnPoint.Y + math.random(-BEZIER_SPREAD, BEZIER_SPREAD)
			)

			-- Pre-compute quadratic bezier path
			local pathPoints = {}
			local parentAbsPos = coin.Parent.AbsolutePosition

			for step = 0, BEZIER_STEPS do
				local t = step / BEZIER_STEPS
				local u = 1 - t
				local worldPos = u * u * spawnPoint + 2 * u * t * controlPoint + t * t * targetCenter

				table.insert(pathPoints, UDim2.fromOffset(worldPos.X - parentAbsPos.X, worldPos.Y - parentAbsPos.Y))
			end

			coroutine.wrap(function()
				-- 1) Pop in
				local growTween = TweenService:Create(coin, POPUP_TWEEN_INFO, {
					Size = UDim2.fromScale(0.1, 0.1),
				})
				growTween:Play()

				-- 2) Shrink + fade once popped in
				local shrinkTween = TweenService:Create(coin, POPUP_TWEEN_INFO, {
					Size = UDim2.fromScale(0.04, 0.04),
					ImageTransparency = 1,
				})
				growTween.Completed:Once(function()
					shrinkTween:Play()
				end)

				-- 3) Fly along bezier arc
				for _, pos in ipairs(pathPoints) do
					coroutine.wrap(function()
						TweenService:Create(coin, LINEAR_TWEEN_INFO, { Position = pos }):Play()
					end)()
					task.wait(0.01)
				end

				Debris:AddItem(coin, COIN_DEBRIS_TTL)
			end)()
		end)
	end
end

-- ── Public API ───────────────────────────────────────────────────────────────
local CashAnimation = {}

--- Must be called once before play().
--- @param gui ScreenGui  The ScreenGui that contains AnimTarget and CashAnim.
function CashAnimation.init(gui: ScreenGui)
	assert(gui, "[CashAnimation] gui is nil — pass your MainGui to init()")
	AnimTarget = gui:WaitForChild("AnimTarget")
	CoinTemplate = gui:WaitForChild("CashAnim")
	initialised = true
end

--- Triggers the coin animation based on the cash delta.
--- @param prevValue number  Cash value before the change.
--- @param newValue  number  Cash value after the change.
function CashAnimation.play(prevValue: number, newValue: number)
	assert(initialised, "[CashAnimation] Call CashAnimation.init(gui) before play()")
	local delta = newValue - prevValue

	if delta <= 0 then
		return
	end
	spawnCoinAnimations(getCoinCount(delta))
end

return CashAnimation
