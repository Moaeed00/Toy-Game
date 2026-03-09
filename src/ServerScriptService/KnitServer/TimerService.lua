local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Libraries.Signal)

local TimerService = Knit.CreateService({
	Name = "TimerService",
	Client = {},
})

function TimerService:KnitStart()
	self._oneSecond = 1
	self._accumulatedTime = 0

	self.SecondPast = Signal.new()

	self:HandleTimer()
end

function TimerService:HandleTimer()
	RunService.Heartbeat:Connect(function(delta: number)
		self._accumulatedTime += delta

		if self._accumulatedTime >= self._oneSecond then
			self.SecondPast:Fire()
			self._accumulatedTime -= self._oneSecond
		end
	end)
end

return TimerService
