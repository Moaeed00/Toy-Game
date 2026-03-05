local TweenService = game:GetService("TweenService")

local CounterTween = {}
CounterTween.__index = CounterTween

local _activeTweens: { [TextLabel]: Tween } = {}
local _activeValues: { [TextLabel]: NumberValue } = {}

type CounterTweenConfig = {
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	Formatter: ((value: number) -> string)?,
}

local DEFAULT_DURATION = 0.4
local DEFAULT_STYLE = Enum.EasingStyle.Quad
local DEFAULT_DIR = Enum.EasingDirection.Out

function CounterTween.Animate(label: TextLabel, fromValue: number, toValue: number, config: CounterTweenConfig?)
	local cfg = config or {}
	local duration = cfg.Duration or DEFAULT_DURATION
	local style = cfg.EasingStyle or DEFAULT_STYLE
	local direction = cfg.EasingDirection or DEFAULT_DIR
	local formatter = cfg.Formatter or function(v: number)
		return tostring(math.floor(v))
	end

	if _activeTweens[label] then
		_activeTweens[label]:Cancel()
		_activeTweens[label] = nil
	end

	local numVal = _activeValues[label]
	if not numVal then
		numVal = Instance.new("NumberValue")
		_activeValues[label] = numVal
	end

	numVal.Value = fromValue
	label.Text = formatter(fromValue)

	local tweenInfo = TweenInfo.new(duration, style, direction)
	local tween = TweenService:Create(numVal, tweenInfo, { Value = toValue })

	local conn: RBXScriptConnection
	conn = numVal.Changed:Connect(function(v: number)
		if label.Parent then
			label.Text = formatter(v)
		else
			conn:Disconnect()
			tween:Cancel()
		end
	end)

	tween.Completed:Connect(function()
		conn:Disconnect()
		if label.Parent then
			label.Text = formatter(toValue)
		end
		_activeTweens[label] = nil
	end)

	_activeTweens[label] = tween
	tween:Play()
end

function CounterTween.GetCurrentValue(label: TextLabel): number
	local numVal = _activeValues[label]
	return if numVal then numVal.Value else 0
end

function CounterTween.Cancel(label: TextLabel)
	if _activeTweens[label] then
		_activeTweens[label]:Cancel()
		_activeTweens[label] = nil
	end
end

function CounterTween.Cleanup(label: TextLabel)
	CounterTween.Cancel(label)
	if _activeValues[label] then
		_activeValues[label]:Destroy()
		_activeValues[label] = nil
	end
end

return CounterTween
