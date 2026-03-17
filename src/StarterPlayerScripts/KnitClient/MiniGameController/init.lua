local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage.Packages.Knit)
local WallPushers = require(script:WaitForChild("WallPushers"))
local IndicatorHelperClient = require(script:WaitForChild("IndicatorHelperClient"))
local ScoringHelperClient = require(script:WaitForChild("ScoringHelperClient"))
local PlaySound = require(ReplicatedStorage.Shared.Utils.PlaySound)
local NotificationHandler = require(ReplicatedStorage.Utility.NotificationHandler)

local player: Player = Players.LocalPlayer
local camera: Camera = workspace.CurrentCamera

local PlayerScripts = player:WaitForChild("PlayerScripts")
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
local PlayerControls = PlayerModule:GetControls()

local Trove = require(ReplicatedStorage.Packages.Trove)
Trove = Trove.new()

local PlayerGui: PlayerGui = player:WaitForChild("PlayerGui")
local MainGui: ScreenGui = PlayerGui:WaitForChild("MainGui")
local CountDownGui: ScreenGui = PlayerGui:WaitForChild("CountDownGui")
local CountDownValue: TextLabel = CountDownGui:WaitForChild("Main"):WaitForChild("CountDown")
local CountDownTextUIStroke: UIStroke = CountDownValue:WaitForChild("UIStroke")
local TimerGui: ScreenGui = PlayerGui:WaitForChild("TimerGui")
local TimerValue: TextLabel = TimerGui:WaitForChild("Main"):WaitForChild("Timer")

local PlayerBase = workspace:WaitForChild("Bases")
local Toys = workspace:WaitForChild("Toys")

local MiniGameController = Knit.CreateController({
	Name = "MiniGameController",
})

local POWER = 90
local LIFT = 30
local CountDownTime = 3

local CanKick = false
local GameRunning = false
local CountDownRunning = false
local GameMode

local CameraController
local MiniGameService
local SlotName: string
local FootBall: Model
local BallSpawnReference: BasePart

function TeleportPlayersToBase()
	local SpawnPart = PlayerBase:WaitForChild(tostring(player.UserId)):WaitForChild("Spawn")
	player.Character:PivotTo(SpawnPart.CFrame)
end

function HandleBallSpawn()
	FootBall:PivotTo(BallSpawnReference.CFrame)
	local root = FootBall.PrimaryPart
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
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
		direction = result.Position - FootBall.PrimaryPart.Position
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
	local character: Model = player.Character
	local humanoid: Humanoid = character:WaitForChild("Humanoid")

	local track = MiniGameController.FootballController:PlayKickBallAnimation(humanoid)
	track:GetMarkerReachedSignal("KickMoment"):Once(function()
		local Direction = GetDirection(Positions)
		local root = FootBall.PrimaryPart

		root.Anchored = false
		root.AssemblyLinearVelocity = Direction.Unit * POWER + Vector3.new(0, LIFT, 0)
	end)
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

			if RmainingTime < 10 then
				TimerValue.Text = "00:0" .. RmainingTime
			else
				TimerValue.Text = "00:" .. RmainingTime
			end
			task.wait(1)
		end
		TimerGui.Enabled = false
	end)
end

function UnequipAllTools()
	local character = player.Character
	if not character then
		return
	end

	local humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
end

function StartCountDown()
	MainGui.Enabled = false
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	UnequipAllTools()
	CountDownGui.Enabled = true
	CountDownRunning = true

	local originalSize = CountDownValue.Size
	local biggerSize = UDim2.fromScale(originalSize.X.Scale * 1.25, originalSize.Y.Scale * 1.25)
	local growTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local shrinkTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	task.spawn(function()
		for count = CountDownTime, 1, -1 do
			if not CountDownRunning then
				break
			end

			CountDownValue.Text = tonumber(count)
			CountDownValue.Size = originalSize
			CountDownValue.TextTransparency = 0
			CountDownTextUIStroke.Transparency = 0

			local growTween = TweenService:Create(CountDownValue, growTweenInfo, { Size = biggerSize })
			growTween:Play()
			growTween.Completed:Wait()

			local shrinkTween = TweenService:Create(CountDownValue, shrinkTweenInfo, { Size = originalSize })
			shrinkTween:Play()
			shrinkTween.Completed:Wait()

			local fadeCountdownValueTween =
				TweenService:Create(CountDownValue, TweenInfo.new(0.2), { TextTransparency = 1 })
			fadeCountdownValueTween:Play()

			local fadeCountDownTextUIStrokeTween =
				TweenService:Create(CountDownTextUIStroke, TweenInfo.new(0.2), { Transparency = 1 })
			fadeCountDownTextUIStrokeTween:Play()

			fadeCountdownValueTween.Completed:Wait()
			task.wait(0.1)
		end

		CountDownGui.Enabled = false
		CountDownTime = 3
		MiniGameService.MiniGame:Fire("StartMiniGame")
	end)
end

function LockCameraRotation()
	local cameraModule = PlayerModule:GetCameras()
	CameraController = cameraModule.activeCameraController

	if CameraController then
		CameraController:Enable(false)
	end
end

function SetMiniGameCamera()
	local character = player.Character
	local head = character:WaitForChild("Head")

	local offset = Vector3.new(0, 12, 20)
	local cameraPosition = head.Position + offset
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(cameraPosition, cameraPosition + Vector3.new(0, 0, -1))
end

function UnlockCameraRotation()
	if CameraController then
		CameraController:Enable(true)
	end
end

function MiniGameController:InitializeMiniGame()
	SlotName = player:GetAttribute("MiniGameSlot")
	FootBall = workspace:WaitForChild(player.Name .. "_FootBall")
	BallSpawnReference = Toys:WaitForChild(SlotName):WaitForChild("BallSpawnReference")

	SetMiniGameCamera()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	LockCameraRotation()

	WallPushers:AddWallPushers(SlotName)
	IndicatorHelperClient:Initialize()
	ScoringHelperClient:Initialize()

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

function MiniGameController:EndMiniGame(ScoreCard)
	if ScoreCard then
		if ScoreCard.Result == "Draw" then
			NotificationHandler:DisplayNotificationMessage("It's a Tie!", "Gameplay")
		elseif ScoreCard.WinnerUserID == player.UserId then
			NotificationHandler:DisplayNotificationMessage("You Win!", "Win")
			PlaySound:Play("Victory", "Touch")
		else
			NotificationHandler:DisplayNotificationMessage("You Lose!", "Error")
		end
	end

	MiniGameService.MiniGame:Fire("ScaleDown")

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
	MainGui.Enabled = true
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)

	CountDownTime = 3
	IndicatorHelperClient:CleanUp()
	ScoringHelperClient:CleanUp()
	WallPushers:CleanUp()
	Trove:Destroy()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	UnlockCameraRotation()
	PlayerControls:Enable()
	TeleportPlayersToBase()
end

function MiniGameController:KnitInit()
	MiniGameController.FootballController = Knit.GetController("FootballController")
	MiniGameService = Knit.GetService("MiniGameService")
end

function MiniGameController:KnitStart()
	-- print("MiniGameController Started")

	MiniGameService.MiniGame:Connect(function(State, Time, Mode)
		self:HandleStates(State, Time, Mode)
	end)

	MiniGameService.EndMiniGame:Connect(function(ScoreCard)
		self:EndMiniGame(ScoreCard)
	end)
end

return MiniGameController
