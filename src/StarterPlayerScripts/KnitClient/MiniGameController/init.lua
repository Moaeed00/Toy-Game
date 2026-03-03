local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage.Packages.Knit)
local WallPushers = require(script:WaitForChild("WallPushers"))
local IndicatorHelperClient = require(script:WaitForChild("IndicatorHelperClient"))
local ScoringHelperClient = require(script:WaitForChild("ScoringHelperClient"))
local CharacterSize = require(script:WaitForChild("CharacterSize"))

local player: Player = Players.LocalPlayer
local camera: Camera = workspace.CurrentCamera

local PlayerScripts = player:WaitForChild("PlayerScripts")
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
local PlayerControls = PlayerModule:GetControls()

local Trove = require(ReplicatedStorage.Packages.Trove)
Trove = Trove.new()

local PlayerGui: PlayerGui = player:WaitForChild("PlayerGui")
local CountDownGui: ScreenGui = PlayerGui:WaitForChild("CountDownGui")
local CountDownValue: TextLabel = CountDownGui:WaitForChild("Main"):WaitForChild("CountDown")

local PlayerBase = workspace:WaitForChild("Bases")
local Toys = workspace:WaitForChild("Toys")

local MiniGameController = Knit.CreateController({
	Name = "MiniGameController",
})

local POWER = 90
local LIFT = 30
local CountDownTime = 3

local ScaleValue = 1.5

local CanKick = false
local GameRunning = false
local CountDownRunning = false
local GameMode

local MiniGameService
local SlotName: string
local FootBall: MeshPart
local BallSpawnReference: BasePart
local PlayerPositionReference: BasePart
local TimerGui: SurfaceGui
local TimerValue: TextLabel

function TeleportPlayersToBase()
	local SpawnPart = PlayerBase:WaitForChild(tostring(player.UserId)):WaitForChild("Spawn")
	player.Character:PivotTo(SpawnPart.CFrame)
end

function HandleBallSpawn()
	FootBall.CFrame = BallSpawnReference.CFrame
	FootBall.AssemblyLinearVelocity = Vector3.zero
	FootBall.AssemblyAngularVelocity = Vector3.zero
	FootBall.Anchored = true
	CanKick = true
end

function GetDirection(Pos: Vector2)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { player.Character, FootBall }

	local unitRay = camera:ScreenPointToRay(Pos.X, Pos.Y)
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, rayParams)

	local direction
	if result then
		direction = result.Position - FootBall.Position
	else
		direction = unitRay.Direction
	end

	direction = Vector3.new(direction.X, 0, direction.Z)

	if direction.Magnitude == 0 then
		return Vector3.new(0, 0, -1)
	end

	return direction.Unit
end

function Kick(Positions: Vector2)
	local Direction = GetDirection(Positions)

	FootBall.Anchored = false
	FootBall.AssemblyLinearVelocity = Direction.Unit * POWER + Vector3.new(0, LIFT, 0)
end

function EnableGameControls()
	local TouchDevice = UserInputService.TouchEnabled

	if TouchDevice then
		Trove:Connect(UserInputService.TouchTap, function(touchPositions, gp)
			if gp then
				return
			end

			if not CanKick then
				return
			end

			CanKick = false

			local tapPos = touchPositions[1]
			if not tapPos then
				return
			end

			Kick(tapPos)
			MiniGameService.MiniGame:Fire("BallKicked")
		end)
	else
		Trove:Connect(UserInputService.InputBegan, function(input, gp)
			if gp then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 and CanKick then
				CanKick = false

				local CursorPosition = UserInputService:GetMouseLocation()
				Kick(CursorPosition)
				MiniGameService.MiniGame:Fire("BallKicked")
			end
		end)
	end
end

function StartTimer(Time: number)
	TimerGui = Toys:WaitForChild(SlotName):WaitForChild("Timer"):WaitForChild("TimerGui")
	TimerValue = TimerGui:WaitForChild("Main"):WaitForChild("Timer")

	local RmainingTime = math.round((Time - Workspace:GetServerTimeNow()))

	if not RmainingTime then
		return
	end

	TimerGui.Enabled = true
	CountDownGui.Enabled = false

	task.spawn(function()
		while RmainingTime >= 1 and GameRunning do
			RmainingTime -= 1
			print("TimeLeftClient", RmainingTime)

			TimerValue.Text = RmainingTime
			task.wait(1)
		end
		TimerGui.Enabled = false
	end)
end

function StartCountDown()
	CountDownGui.Enabled = true
	CountDownRunning = true

	task.spawn(function()
		while CountDownTime >= 0 and CountDownRunning do
			CountDownValue.Text = CountDownTime
			task.wait(1)
			CountDownTime -= 1
		end

		CountDownGui.Enabled = false
		CountDownTime = 3
		MiniGameService.MiniGame:Fire("StartMiniGame")
	end)
end

function MiniGameController:InitializeMiniGame()
	SlotName = player:GetAttribute("MiniGameSlot")
	FootBall = workspace:WaitForChild(player.Name .. "_FootBall")
	BallSpawnReference = Toys:WaitForChild(SlotName):WaitForChild("BallSpawnReference")
	PlayerPositionReference = Toys:WaitForChild(SlotName):WaitForChild("PlayerPositionReference")

	player.Character:PivotTo(PlayerPositionReference.CFrame)

	WallPushers:AddWallPushers(SlotName)
	IndicatorHelperClient:Initialize()
	ScoringHelperClient:Initialize()
	CharacterSize:ScaleUp(player, ScaleValue)

	PlayerControls:Disable()
	StartCountDown()
end

function MiniGameController:StartMiniGame(Time)
	GameRunning = true
	ScoringHelperClient:OnStartScoring(GameMode)

	HandleBallSpawn()
	StartTimer(Time)
	EnableGameControls()
	CountDownRunning = false
end

function MiniGameController:HandleStates(State, Time, Mode)
	if Mode then
		GameMode = Mode
	end

	if State == "InitializeMiniGame" then
		self:InitializeMiniGame()
	elseif State == "StartMiniGame" then
		self:StartMiniGame(Time)
	elseif State == "EnableKick" then
		HandleBallSpawn()
	end
end

function MiniGameController:EndMiniGame()
	CountDownRunning = false
	GameRunning = false
	CanKick = false

	GameMode = nil

	if TimerGui then
		TimerGui.Enabled = false
	end
	if CountDownGui then
		CountDownGui.Enabled = false
	end

	CountDownTime = 3
	IndicatorHelperClient:CleanUp()
	ScoringHelperClient:CleanUp()
	WallPushers:CleanUp()
	CharacterSize:ScaleDown(player)
	Trove:Destroy()
	PlayerControls:Enable()
	TeleportPlayersToBase()
end

function MiniGameController:KnitInit()
	MiniGameService = Knit.GetService("MiniGameService")
end

function MiniGameController:KnitStart()
	-- print("MiniGameController Started")

	MiniGameService.MiniGame:Connect(function(State, Time, Mode)
		self:HandleStates(State, Time, Mode)
	end)

	MiniGameService.EndMiniGame:Connect(function()
		self:EndMiniGame()
	end)

	player.CharacterAdded:Connect(function(Character)
		if GameRunning then
			local HRP = Character:WaitForChild("HumanoidRootPart")
			if not HRP then
				return
			end

			player.Character:PivotTo(PlayerPositionReference.CFrame)
		end
	end)
end

return MiniGameController
