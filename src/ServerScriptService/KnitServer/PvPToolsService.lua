--!strict
--// File: src/ServerScriptService/KnitServer/Services/PvPToolsService.lua
--// PvPToolsService.lua
--// FIXED:
--// - Proper ragdoll disable logic
--// - Front-left knockback
--// - GearModule + PvPToolsConfig integrated
--// - Stable-delay + safety timeout

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(
	ReplicatedStorage
		:WaitForChild("Configuration")
		:WaitForChild("PvPToolsConfig")
)

local GearModule = require(
	ReplicatedStorage:WaitForChild("GearModule")
)

--// Punch Hit Sounds
local SoundsFolder = ReplicatedStorage
	:WaitForChild("Assets")
	:WaitForChild("Sounds")

local PunchHitSound = SoundsFolder:WaitForChild("Punch")
local GoldenPunchHitSound = SoundsFolder:WaitForChild("GoldenPunch")

local PvPToolsService = Knit.CreateService({
	Name = "PvPToolsService",

	Client = {
		RequestPunch = function() end,
		ActionResult = Knit.CreateSignal(),
		PlayPunchAnimation = Knit.CreateSignal(),
	},
})

PvPToolsService.CombatMovementService = nil

local lastPunchTime: { [Player]: number } = {}
local ragdollData: { [Player]: any } = {}

local function dprint(...)
	if Config.DEBUG_PRINTS then
		print("[PvPToolsService]", ...)
	end
end

--=====================================================
-- CHARACTER HELPER
--=====================================================

local function getCharacterParts(player: Player)
	local character = player.Character
	if not character then return nil, nil, nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not hrp then
		return nil, nil, nil
	end

	return character, humanoid, hrp
end

--=====================================================
-- REAL RAGDOLL SYSTEM (MATCH SLIDE)
--=====================================================

function PvPToolsService:_enableRealRagdoll(player: Player)

	local character = player.Character
	if not character then return end
	if ragdollData[player] then return end

	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local data = {
		Motors = {},
		Constraints = {},
	}

	hum:ChangeState(Enum.HumanoidStateType.Physics)
	hum.AutoRotate = false
	hum.PlatformStand = true

	for _, joint in ipairs(character:GetDescendants()) do
		if joint:IsA("Motor6D") then

			local part0 = joint.Part0
			local part1 = joint.Part1
			if not part0 or not part1 then continue end

			local att0 = Instance.new("Attachment")
			att0.CFrame = joint.C0
			att0.Parent = part0

			local att1 = Instance.new("Attachment")
			att1.CFrame = joint.C1
			att1.Parent = part1

			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = att0
			socket.Attachment1 = att1

			--// Enable constraint limits
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true

			--// Determine if this joint is Neck
			local isNeck = joint.Name == "Neck"

			--// Apply HEAD or BODY limits (from PvPToolsConfig)
			if isNeck then
				socket.UpperAngle = Config.HEAD_UPPER_ANGLE
				socket.TwistLowerAngle = -Config.HEAD_TWIST_LIMIT
				socket.TwistUpperAngle = Config.HEAD_TWIST_LIMIT
			else
				socket.UpperAngle = Config.BODY_UPPER_ANGLE
				socket.TwistLowerAngle = -Config.BODY_TWIST_LIMIT
				socket.TwistUpperAngle = Config.BODY_TWIST_LIMIT
			end

			socket.Parent = part0

			table.insert(data.Motors, joint)
			table.insert(data.Constraints, socket)

			joint.Enabled = false
		end
	end

	ragdollData[player] = data

	dprint("🔥 RAGDOLL ENABLED:", player.Name)
end

function PvPToolsService:_disableRealRagdoll(player: Player)

	local character = player.Character
	if not character then return end

	local hum = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	local data = ragdollData[player]
	if not data then return end

	-- Hard stop velocity
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end

	hrp.Anchored = true
	RunService.Heartbeat:Wait()

	for _, motor in ipairs(data.Motors) do
		if motor and motor.Parent then
			motor.Enabled = true
		end
	end

	for _, constraint in ipairs(data.Constraints) do
		if constraint then
			local att0 = constraint.Attachment0
			local att1 = constraint.Attachment1
			if constraint.Parent then constraint:Destroy() end
			if att0 then att0:Destroy() end
			if att1 then att1:Destroy() end
		end
	end

	ragdollData[player] = nil

	hrp.Anchored = false

	hum.PlatformStand = false
	hum.AutoRotate = true
	hum:ChangeState(Enum.HumanoidStateType.GettingUp)

	dprint("🟢 RAGDOLL DISABLED:", player.Name)
end

--=====================================================
-- FRONT LEFT KNOCKBACK
--=====================================================

function PvPToolsService:_applyFrontLeftKnockback(attackerHRP, targetHRP, power, up, distance)

	local look = attackerHRP.CFrame.LookVector
	local right = attackerHRP.CFrame.RightVector

	local direction = (look - (right * Config.FRONT_LEFT_MULTIPLIER)).Unit

	local velocity = (direction * power) + Vector3.new(0, up, 0)

	local duration = distance / math.max(power, 1)

	local att = Instance.new("Attachment")
	att.Parent = targetHRP

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = 500000
	lv.VectorVelocity = velocity
	lv.Parent = targetHRP

	task.delay(duration, function()
		if lv then lv:Destroy() end
		if att then att:Destroy() end
	end)

	dprint("🚀 Knockback Applied | Duration:", duration)
end

--=====================================================
-- MONITOR RAGDOLL STOP
--=====================================================

function PvPToolsService:_monitorRagdoll(player: Player, hrp: BasePart)

	local startTime = os.clock()
	local stoppedTime = nil

	while ragdollData[player] do

		local speed = hrp.AssemblyLinearVelocity.Magnitude

		if speed <= Config.RAGDOLL_VELOCITY_THRESHOLD then

			if not stoppedTime then
				stoppedTime = os.clock()
				dprint("Velocity low, starting stable timer")
			end

			if os.clock() - stoppedTime >= Config.RAGDOLL_STABLE_DELAY then
				dprint("Stable delay reached, disabling ragdoll")
				break
			end

		else
			stoppedTime = nil
		end

		-- Emergency timeout
		if os.clock() - startTime > Config.RAGDOLL_MAX_DURATION then
			dprint("Emergency ragdoll timeout reached")
			break
		end

		RunService.Heartbeat:Wait()
	end

	self:_disableRealRagdoll(player)
end

--=====================================================
-- GET GEAR STATS
--=====================================================

function PvPToolsService:_getPunchStats(player: Player)

	local character = player.Character
	if not character then
		return Config.DEFAULT_BUMP_POWER,
		Config.DEFAULT_BUMP_UP,
		Config.DEFAULT_KNOCKBACK_DISTANCE
	end

	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("GearType") == "Punch" then

			local gearName = tool:GetAttribute("GearName")

			if gearName and GearModule[gearName] then

				local stats = GearModule[gearName].Stats

				return stats.BumpPower or Config.DEFAULT_BUMP_POWER,
				stats.BumpUp or Config.DEFAULT_BUMP_UP,
				stats.KnockbackDistance or Config.DEFAULT_KNOCKBACK_DISTANCE
			end
		end
	end

	return Config.DEFAULT_BUMP_POWER,
	Config.DEFAULT_BUMP_UP,
	Config.DEFAULT_KNOCKBACK_DISTANCE
end

--=====================================================
-- HIT DETECTION
--=====================================================

function PvPToolsService:_punchHit(player, attackerChar, attackerHRP)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attackerChar }

	local offset = CFrame.new(0, 0, -Config.PUNCH_HITBOX_FORWARD_OFFSET)

	local parts = workspace:GetPartBoundsInBox(
		attackerHRP.CFrame * offset,
		Config.PUNCH_HITBOX_SIZE,
		params
	)

	for _, part in ipairs(parts) do

		local otherChar = part:FindFirstAncestorOfClass("Model")
		if not otherChar then continue end

		local otherPlayer = Players:GetPlayerFromCharacter(otherChar)
		if not otherPlayer or otherPlayer == player then continue end

		-- prevent hitting already ragdolled players
		if self.CombatMovementService and self.CombatMovementService.slideRagdollData then
			if self.CombatMovementService.slideRagdollData[otherPlayer] then
				continue
			end
		end

		-- Prevent hitting already ragdolled players
		if ragdollData[otherPlayer] then
			dprint("Punch ignored, player already ragdolled:", otherPlayer.Name)
			continue
		end

		local targetHRP = otherChar:FindFirstChild("HumanoidRootPart")
		if not targetHRP then continue end

		local power, up, distance = self:_getPunchStats(player)

		if self.CombatMovementService then
			self.CombatMovementService:_enableRealRagdoll(otherPlayer)
		end

		--// Play punch hit sound
		local soundTemplate = PunchHitSound

		local attackerChar = player.Character
		if attackerChar then
			for _, tool in ipairs(attackerChar:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("GearType") == "Punch" then
					if tool:GetAttribute("GearName") == "Golden Punch" then
						soundTemplate = GoldenPunchHitSound
					end
				end
			end
		end

		local sound = soundTemplate:Clone()
		sound.Parent = targetHRP
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 3)

		self:_applyFrontLeftKnockback(attackerHRP, targetHRP, power, up, distance)

		if self.CombatMovementService then
			task.spawn(function()

				local char = otherPlayer.Character
				if not char then return end

				local hrp = char:FindFirstChild("HumanoidRootPart")
				if not hrp then return end

				local VELOCITY_THRESHOLD = Config.RAGDOLL_VELOCITY_THRESHOLD
				local STOP_DELAY = Config.RAGDOLL_STABLE_DELAY

				local stoppedTime = nil

				while true do
					local speed = hrp.AssemblyLinearVelocity.Magnitude

					if speed <= VELOCITY_THRESHOLD then
						if not stoppedTime then
							stoppedTime = os.clock()
						end

						if os.clock() - stoppedTime >= STOP_DELAY then
							break
						end
					else
						stoppedTime = nil
					end

					RunService.Heartbeat:Wait()
				end

				self.CombatMovementService:_disableRealRagdoll(otherPlayer)

			end)
		end

		return true
	end

	return false
end

--=====================================================
-- MAIN PUNCH
--=====================================================

function PvPToolsService:_doPunch(player: Player)

	local character, humanoid, hrp = getCharacterParts(player)
	if not character or not humanoid or not hrp then
		return false, "MissingCharacter"
	end

	self.Client.PlayPunchAnimation:Fire(player)

	local hit = self:_punchHit(player, character, hrp)

	if not hit then
		return false, "NoTarget"
	end

	return true, "OK"
end

--=====================================================
-- REMOTE
--=====================================================

function PvPToolsService.Client:RequestPunch(player: Player)

	local now = os.clock()
	local last = lastPunchTime[player] or 0

	if (now - last) < Config.PUNCH_COOLDOWN then
		self.ActionResult:Fire(player, "Punch", false, "Cooldown")
		return
	end

	lastPunchTime[player] = now

	local ok, reason = self.Server:_doPunch(player)

	self.ActionResult:Fire(player, "Punch", ok, reason)
end

function PvPToolsService:KnitInit()
	dprint("KnitInit() complete")
end

function PvPToolsService:KnitStart()

	local ok, service = pcall(function()
		return Knit.GetService("CombatMovementService")
	end)

	if ok then
		self.CombatMovementService = service
		dprint("Got CombatMovementService reference ✅")
	else
		warn("[PvPToolsService] CombatMovementService not found")
	end

	dprint("KnitStart() complete")
end

return PvPToolsService