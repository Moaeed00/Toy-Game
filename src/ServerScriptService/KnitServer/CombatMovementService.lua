--!strict
--// File: src/ServerScriptService/KnitServer/Services/CombatMovementService.lua
--// CombatMovementService.lua
--// FIXED: IsSliding attribute properly cleared

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("CombatMovementConfig"))

--// Slide Shoes
local ShoesFolder = ReplicatedStorage
	:WaitForChild("Assets")
	:WaitForChild("Shoes")

local SlideShoeModel = ShoesFolder:WaitForChild("SlideShoe")
local GoldenSlideShoeModel = ShoesFolder:WaitForChild("GoldenSlideShoe")

--// Slide Hit Sounds
local SoundsFolder = ReplicatedStorage
	:WaitForChild("Assets")
	:WaitForChild("Sounds")

local SlideHitSound = SoundsFolder:WaitForChild("Slide")
local GoldenSlideHitSound = SoundsFolder:WaitForChild("GoldenSlide")


local CombatMovementService = Knit.CreateService({
	Name = "CombatMovementService",

	Client = {
		RequestSlide = function() end,
		ActionResult = Knit.CreateSignal(),
		PlaySlideAnimation = Knit.CreateSignal(),
	},
})

print("[CombatMovementService] Service created with PlaySlideAnimation signal ✅")

--// Cooldowns
local lastSlideTime: { [Player]: number } = {}
local slideRagdollData: { [Player]: any } = {}
local slideDebugPartByPlayer: { [Player]: BasePart } = {}
local slideAdornmentByPlayer: { [Player]: BoxHandleAdornment } = {}

-- [KEEP ALL YOUR EXISTING HELPER FUNCTIONS - I'm only showing the changed _doSlide function]

function CombatMovementService:_ensureSlideDebugAdornment(player: Player, hrp: BasePart, hbSize: Vector3, offsetCF: CFrame, visible: boolean)
	if not hrp or not hrp.Parent then
		return
	end

	local adorn = slideAdornmentByPlayer[player]
	if not adorn then
		adorn = Instance.new("BoxHandleAdornment")
		adorn.Name = "SlideHitboxAdornment_" .. player.UserId
		adorn.Adornee = hrp
		adorn.AlwaysOnTop = true
		adorn.ZIndex = 10
		adorn.Parent = hrp
		slideAdornmentByPlayer[player] = adorn
		print("[SlideHitboxDebug] Created BoxHandleAdornment for:", player.Name)
	end

	adorn.Size = hbSize
	adorn.CFrame = offsetCF

	if visible then
		adorn.Transparency = Config.DEBUG_SLIDE_HITBOX_TRANSPARENCY
	else
		adorn.Transparency = 1
	end
end

function CombatMovementService:_updateSlideDebugAdornment(player: Player, hrp: BasePart, hbSize: Vector3, offsetCF: CFrame)
	self:_ensureSlideDebugAdornment(player, hrp, hbSize, offsetCF, true)
end

local function getOrCreateHitboxDebugFolder(): Folder
	local folder = workspace:FindFirstChild("_DebugHitboxes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "_DebugHitboxes"
		folder.Parent = workspace
		print("[SlideHitboxDebug] Created folder:", folder:GetFullName())
	end
	return folder
end

function CombatMovementService:_getOrCreateSlideDebugPart(player: Player): BasePart
	if slideDebugPartByPlayer[player] and slideDebugPartByPlayer[player].Parent then
		return slideDebugPartByPlayer[player]
	end

	local p = Instance.new("Part")
	p.Name = "SlideHitbox_" .. player.UserId
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p.Material = Enum.Material.Neon
	p.Parent = getOrCreateHitboxDebugFolder()

	slideDebugPartByPlayer[player] = p
	print("[SlideHitboxDebug] Created:", p:GetFullName(), "for:", player.Name)

	return p
end

function CombatMovementService:_enableRealRagdoll(player: Player)

	local character = player.Character
	if not character then return end

	local hum = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	pcall(function()
		hrp:SetNetworkOwner(nil)
	end)
	if not hum then return end

	if slideRagdollData[player] then return end -- already ragdolled

	local data = {
		Motors = {},
		Constraints = {},
	}

	-- Disable humanoid control
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	hum.AutoRotate = false
	hum.PlatformStand = true

	for _, joint in ipairs(character:GetDescendants()) do
		if joint:IsA("Motor6D") then

			local part0 = joint.Part0
			local part1 = joint.Part1
			if not part0 or not part1 then continue end

			local isNeck = joint.Name == "Neck"

			-- Create attachments
			local att0 = Instance.new("Attachment")
			att0.CFrame = joint.C0
			att0.Parent = part0

			local att1 = Instance.new("Attachment")
			att1.CFrame = joint.C1
			att1.Parent = part1

			-- Create constraint
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = att0
			socket.Attachment1 = att1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true

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

	slideRagdollData[player] = data

	print("[CombatMovementService] 🔥 REAL RAGDOLL ENABLED:", player.Name)
end

function CombatMovementService:_disableRealRagdoll(player: Player)
	print("🔴 _disableRealRagdoll CALLED at:", os.clock())

	local character = player.Character
	if not character then return end

	local hum = character:FindFirstChildOfClass("Humanoid")
	hum.StateChanged:Connect(function(old, new)
		print("⚪ Humanoid state changed:", old.Name, "→", new.Name, "at", os.clock())
	end)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	pcall(function()
		hrp:SetNetworkOwner(nil)
	end)
	if not hum or not hrp then return end

	local data = slideRagdollData[player]
	if not data then return end

	-- Hard stop physics
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- Anchor for exactly one physics frame
	hrp.Anchored = true
	RunService.Heartbeat:Wait()

	-- Restore joints
	for _, motor in ipairs(data.Motors) do
		if motor and motor.Parent then
			motor.Enabled = true
		end
	end

	-- Remove constraints
	for _, constraint in ipairs(data.Constraints) do
		if constraint then
			local att0 = constraint.Attachment0
			local att1 = constraint.Attachment1
			if constraint.Parent then
				constraint:Destroy()
			end
			if att0 then
				att0:Destroy()
			end
			if att1 then
				att1:Destroy()
			end
		end
	end

	slideRagdollData[player] = nil

	-- Unanchor
	hrp.Anchored = false

	print("🟣 Restoring humanoid state at:", os.clock())

	-- Fully freeze motion
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- Ensure upright before restore
	local currentPos = hrp.Position
	hrp.CFrame = CFrame.new(currentPos)

	-- Restore joints
	for _, motor in ipairs(data.Motors) do
		if motor and motor.Parent then
			motor.Enabled = true
		end
	end

	for _, constraint in ipairs(data.Constraints) do
		if constraint then
			local att0 = constraint.Attachment0
			local att1 = constraint.Attachment1
			if constraint.Parent then
				constraint:Destroy()
			end
			if att0 then
				att0:Destroy()
			end
			if att1 then
				att1:Destroy()
			end
		end
	end

	slideRagdollData[player] = nil

	-- Restore humanoid control
	hum.PlatformStand = false
	hum.AutoRotate = true
	hum:ChangeState(Enum.HumanoidStateType.Running)
	print("🟢 Humanoid state after restore:", hum:GetState())
end

function CombatMovementService:_setSlideDebugVisible(player: Player, hrp: BasePart, visible: boolean)
	local p = self:_getOrCreateSlideDebugPart(player, hrp)

	if visible then
		print("[SlideHitboxDebug] Visible ON for:", player.Name)
		p.Transparency = Config.DEBUG_SLIDE_HITBOX_TRANSPARENCY
	else
		print("[SlideHitboxDebug] Visible OFF for:", player.Name)
		p.Transparency = 1
	end
end

function CombatMovementService:_updateSlideDebugPart(player: Player, hrp: BasePart, hbSize: Vector3)
	local p = self:_getOrCreateSlideDebugPart(player, hrp)
	p.Size = hbSize
end

function CombatMovementService:_cleanupSlideDebugPart(player: Player)
	local p = slideDebugPartByPlayer[player]
	if p then
		print("[SlideHitboxDebug] Destroy debug part for:", player.Name)
		p:Destroy()
		slideDebugPartByPlayer[player] = nil
	end
end

CombatMovementService.BrainrotCarryService = nil

local function dprint(...: any)
	if Config.DEBUG_PRINTS then
		print("[CombatMovementService]", ...)
	end
end

--=====================================================
-- SLIDE SHOES SYSTEM
--=====================================================

local equippedShoes: { [Player]: {Instance} } = {}

function CombatMovementService:_equipSlideShoes(player: Player, gearName: string)

	local character = player.Character
	if not character then return end

	local leftFoot = character:FindFirstChild("LeftFoot")
	local rightFoot = character:FindFirstChild("RightFoot")

	if not leftFoot or not rightFoot then return end

	local template = SlideShoeModel
	if gearName == "Golden Slide" then
		template = GoldenSlideShoeModel
	end

	local shoes = {}

	for _, foot in ipairs({leftFoot, rightFoot}) do

		local shoe = template:Clone()
		shoe.Parent = character

		local mesh = shoe:FindFirstChildWhichIsA("MeshPart", true)
		if not mesh then continue end

		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.Massless = true

		-- Move mesh to foot first
		mesh.CFrame = foot.CFrame * CFrame.Angles(0, math.rad(90), 0)

		-- Create weld
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = foot
		weld.Part1 = mesh
		weld.Parent = mesh

		-- Unanchor after welding
		mesh.Anchored = false

		table.insert(shoes, shoe)

	end

	equippedShoes[player] = shoes
end


function CombatMovementService:_unequipSlideShoes(player: Player)

	local shoes = equippedShoes[player]
	if not shoes then return end

	for _, shoe in ipairs(shoes) do
		if shoe and shoe.Parent then
			shoe:Destroy()
		end
	end

	equippedShoes[player] = nil
end

local function getCharacterParts(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		dprint("getCharacterParts() FAIL -> no character:", player.Name)
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		dprint("getCharacterParts() FAIL -> no humanoid:", player.Name)
		return character, nil, nil
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		dprint("getCharacterParts() FAIL -> no HRP:", player.Name)
		return character, humanoid, nil
	end

	return character, humanoid, hrp
end

function CombatMovementService:_bumpTarget(
	attackerHRP: BasePart,
	targetHRP: BasePart,
	pushPower: number,
	pushUp: number,
	knockbackDistance: number?
)

	-- Safety fallback
	local distance = knockbackDistance or 10
	local power = pushPower or 50
	local up = pushUp or 10

	local look = attackerHRP.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)

	if dir.Magnitude < 0.001 then
		dir = Vector3.new(0, 0, -1)
	end

	dir = dir.Unit

	local horizontalVelocity = power
	local knockVel = (dir * horizontalVelocity) + Vector3.new(0, up, 0)

	local duration = distance / math.max(horizontalVelocity, 1)

	local oldLV = targetHRP:FindFirstChild("KnockbackLinearVelocity")
	if oldLV then
		oldLV:Destroy()
	end

	local oldAtt = targetHRP:FindFirstChild("KnockbackAttachment")
	if oldAtt then
		oldAtt:Destroy()
	end

	local att = Instance.new("Attachment")
	att.Name = "KnockbackAttachment"
	att.Parent = targetHRP

	local lv = Instance.new("LinearVelocity")
	lv.Name = "KnockbackLinearVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = 500000
	lv.VectorVelocity = knockVel
	lv.Parent = targetHRP

	task.delay(duration, function()
		if lv and lv.Parent then
			lv:Destroy()
		end
		if att and att.Parent then
			att:Destroy()
		end
	end)

	print("🚀 KnockbackDistance:", distance, "Duration:", duration)
end

function CombatMovementService:_tryForceDropBrainrot(targetPlayer: Player, reason: string)
	if not self.BrainrotCarryService then
		dprint("_tryForceDropBrainrot() BrainrotCarryService missing")
		return
	end

	if targetPlayer:GetAttribute("IsCarryingBrainrot") ~= true then
		dprint("_tryForceDropBrainrot() target not carrying:", targetPlayer.Name)
		return
	end

	dprint("Forcing brainrot drop (front) for:", targetPlayer.Name, "reason:", reason)

	local ok, err = pcall(function()
		self.BrainrotCarryService:DropBrainrot(targetPlayer, reason, nil)
	end)

	if not ok then
		warn("[CombatMovementService] Force drop brainrot failed:", err)
	end
end

function CombatMovementService:_slideBumpLoop(
	slider: Player,
	sliderCharacter: Model,
	sliderHRP: BasePart,
	bumpPower: number?,
	bumpUp: number?
)
	dprint("_slideBumpLoop() START for:", slider.Name)

	if not Config.SLIDE_BUMP_ENABLED then
		return
	end

	local finalPower = bumpPower or Config.SLIDE_BUMP_PUSH_POWER
	local finalUp = bumpUp or Config.SLIDE_BUMP_PUSH_UP

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { sliderCharacter }
	params.RespectCanCollide = false

	local bumpedUserIds: { [number]: boolean } = {}

	local offsetCF = CFrame.new(0, 0, -Config.SLIDE_BUMP_FORWARD_OFFSET)
	local hbSize = Config.SLIDE_BUMP_HITBOX_SIZE
	local SWEEP_STEP = 2
	local lastCF = sliderHRP.CFrame

	while slider:GetAttribute("IsSliding") == true do
		if not sliderHRP or not sliderHRP.Parent then
			break
		end

		local currentCF = sliderHRP.CFrame
		local dist = (currentCF.Position - lastCF.Position).Magnitude
		local steps = math.max(1, math.ceil(dist / SWEEP_STEP))

		for i = 1, steps do
			local alpha = i / steps
			local sampleCF = lastCF:Lerp(currentCF, alpha)
			local hbCFrame = sampleCF * offsetCF

			local parts = workspace:GetPartBoundsInBox(hbCFrame, hbSize, params)

			for _, part in ipairs(parts) do
				local otherChar = part:FindFirstAncestorOfClass("Model")
				if not otherChar then continue end

				local otherPlayer = Players:GetPlayerFromCharacter(otherChar)
				if not otherPlayer or otherPlayer == slider then continue end
				if bumpedUserIds[otherPlayer.UserId] then continue end
				if slideRagdollData[otherPlayer] then continue end

				bumpedUserIds[otherPlayer.UserId] = true

				local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
				if otherHRP and otherHRP:IsA("BasePart") then
					print("[SLIDE HIT] Using Power:", finalPower, "Up:", finalUp)

					--// Play slide hit sound
					local soundTemplate = SlideHitSound

					local sliderChar = slider.Character
					if sliderChar then
						for _, tool in ipairs(sliderChar:GetChildren()) do
							if tool:IsA("Tool") and tool:GetAttribute("GearType") == "Slide" then
								if tool:GetAttribute("GearName") == "Golden Slide" then
									soundTemplate = GoldenSlideHitSound
								end
							end
						end
					end

					local sound = soundTemplate:Clone()
					sound.Parent = otherHRP
					sound:Play()
					game:GetService("Debris"):AddItem(sound, 3)

					-- Get knockback distance from GearModule
					local GearModule = require(ReplicatedStorage:WaitForChild("GearModule"))

					-- Find slider's equipped slide tool to get distance
					local sliderChar = slider.Character
					if sliderChar then
						for _, tool in ipairs(sliderChar:GetChildren()) do
							if tool:IsA("Tool") and tool:GetAttribute("GearType") == "Slide" then
								local gearName = tool:GetAttribute("GearName")
								if gearName and GearModule[gearName] then
									local knockbackDistance = GearModule[gearName].Stats.KnockbackDistance
									print("[CombatMovementService] Knockback distance:", knockbackDistance, "studs")
									break
								end
							end
						end
					end

					local knockbackDistance = 10 -- safe default

					local GearModule = require(ReplicatedStorage:WaitForChild("GearModule"))
					local sliderChar = slider.Character
					if sliderChar then
						for _, tool in ipairs(sliderChar:GetChildren()) do
							if tool:IsA("Tool") and tool:GetAttribute("GearType") == "Slide" then
								local gearName = tool:GetAttribute("GearName")
								if gearName and GearModule[gearName] then
									knockbackDistance = GearModule[gearName].Stats.KnockbackDistance or 10
									break
								end
							end
						end
					end

					self:_bumpTarget(
						sliderHRP,
						otherHRP,
						finalPower,
						finalUp,
						knockbackDistance
					)

					-- NEW: Apply ragdoll physics for slide hits
					self:_enableRealRagdoll(otherPlayer)

					task.spawn(function()

						local char = otherPlayer.Character
						if not char then return end

						local hrp = char:FindFirstChild("HumanoidRootPart")
						if not hrp then return end

						local VELOCITY_THRESHOLD = Config.RAGDOLL_VELOCITY_THRESHOLD
						local STOP_DELAY = Config.RAGDOLL_STABLE_DELAY

						local stoppedTime = nil

						print("🟡 Monitoring velocity...")

						while slideRagdollData[otherPlayer] do
							local speed = hrp.AssemblyLinearVelocity.Magnitude

							if speed <= VELOCITY_THRESHOLD then
								if not stoppedTime then
									stoppedTime = os.clock()
									print("🟢 Velocity low at:", stoppedTime)
								end

								-- Check if 1 sec passed since stopping
								if os.clock() - stoppedTime >= STOP_DELAY then
									print("🔵 1 second after stop reached")
									break
								end
							else
								-- If moving again, reset timer
								if stoppedTime then
									print("🟠 Velocity increased again, resetting timer")
								end
								stoppedTime = nil
							end

							RunService.Heartbeat:Wait()
						end

						self:_disableRealRagdoll(otherPlayer)

					end)
				end

				if self.BrainrotCarryService
					and otherPlayer:GetAttribute("IsCarryingBrainrot") == true then
					self.BrainrotCarryService:DropBrainrot(otherPlayer, "SlideCollisionDrop", nil)
				end
			end
		end

		lastCF = currentCF
		RunService.Heartbeat:Wait()
	end

	dprint("_slideBumpLoop() END for:", slider.Name)
end

--// [CRITICAL FIX] _doSlide function with proper cleanup
function CombatMovementService:_doSlide(player: Player): (boolean, string)
	dprint("_doSlide() START for:", player.Name)

	local character, humanoid, hrp = getCharacterParts(player)
	if not character or not humanoid or not hrp then
		return false, "MissingCharacter"
	end

	if humanoid.Health <= 0 then
		return false, "Dead"
	end

	--// [CRITICAL] Check if already sliding
	local currentlySliding = player:GetAttribute("IsSliding")
	print("[CombatMovementService] IsSliding attribute BEFORE:", currentlySliding)

	if currentlySliding == true then
		dprint("_doSlide() BLOCKED -> already sliding:", player.Name)
		return false, "AlreadySliding"
	end

	--// [CRITICAL] Set sliding IMMEDIATELY
	player:SetAttribute("IsSliding", true)
	print("[CombatMovementService] ✅ IsSliding = true for:", player.Name)

	local oldWalkSpeed = humanoid.WalkSpeed

	if Config.SLIDE_DISABLE_WALKSPEED then
		humanoid.WalkSpeed = Config.SLIDE_TEMP_WALKSPEED
		dprint("WalkSpeed temp set:", humanoid.WalkSpeed, "for:", player.Name)
	end

	--// Get gear stats FIRST before firing signal
	local GearModule = require(ReplicatedStorage:WaitForChild("GearModule"))
	local gearStats = {
		Speed = Config.SLIDE_SPEED,
		Duration = Config.SLIDE_DURATION,
		BumpPower = Config.SLIDE_BUMP_PUSH_POWER,
		BumpUp = Config.SLIDE_BUMP_PUSH_UP,
	}

	-- Check for equipped slide tool
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			local gearName = tool.Name

			if GearModule[gearName] and GearModule[gearName].Type == "Slide" then
				print("[CombatMovementService] 🎯 Using stats from:", gearName)

				local stats = GearModule[gearName].Stats
				gearStats.Speed = stats.Speed
				gearStats.Duration = stats.Duration
				gearStats.BumpPower = stats.BumpPower
				gearStats.BumpUp = stats.BumpUp

				print("[CombatMovementService] ⚡ Speed:", gearStats.Speed, "Duration:", gearStats.Duration)
				break
			end
		end
	end

	--// [CRITICAL] Fire animation signal AFTER calculating stats
	print("[CombatMovementService] ========================================")
	print("[CombatMovementService] 🎬 FIRING PlaySlideAnimation WITH DURATION:", gearStats.Duration)
	self.Client.PlaySlideAnimation:Fire(player, gearStats.Duration)
	print("[CombatMovementService] ✅ PlaySlideAnimation signal fired")
	print("[CombatMovementService] ========================================")


	local attachment = Instance.new("Attachment")
	attachment.Name = "Combat_SlideAttachment"
	attachment.Parent = hrp

	local lv = Instance.new("LinearVelocity")
	lv.Name = "Combat_SlideLinearVelocity"
	lv.Attachment0 = attachment
	lv.MaxForce = Config.SLIDE_MAX_FORCE
	lv.RelativeTo = Enum.ActuatorRelativeTo.World

	lv.VectorVelocity = hrp.CFrame.LookVector * gearStats.Speed
	lv.Parent = hrp

	dprint("Slide velocity applied:", lv.VectorVelocity, "duration:", Config.SLIDE_DURATION)

	task.spawn(function()
		self:_slideBumpLoop(player, character, hrp, gearStats.BumpPower, gearStats.BumpUp)
	end)

	--// [CRITICAL] Cleanup with guaranteed IsSliding reset
	task.delay(gearStats.Duration, function()
		print("[CombatMovementService] ========================================")
		print("[CombatMovementService] ⏹️ SLIDE CLEANUP STARTING for:", player.Name)

		if lv and lv.Parent then
			lv:Destroy()
			print("[CombatMovementService] ✅ LinearVelocity destroyed")
		end

		if attachment and attachment.Parent then
			attachment:Destroy()
			print("[CombatMovementService] ✅ Attachment destroyed")
		end

		if Config.SLIDE_DISABLE_WALKSPEED and humanoid and humanoid.Parent then
			humanoid.WalkSpeed = oldWalkSpeed
			print("[CombatMovementService] ✅ WalkSpeed restored:", oldWalkSpeed)
		end

		--// [CRITICAL] ALWAYS clear IsSliding
		player:SetAttribute("IsSliding", false)
		print("[CombatMovementService] ✅✅✅ IsSliding = false for:", player.Name)
		print("[CombatMovementService] IsSliding attribute NOW:", player:GetAttribute("IsSliding"))
		print("[CombatMovementService] ⏹️ SLIDE CLEANUP COMPLETE for:", player.Name)
		print("[CombatMovementService] ========================================")
	end)

	return true, "OK"
end

function CombatMovementService.Client:RequestSlide(player: Player)
	dprint("Client.RequestSlide from:", player.Name)

	local now = os.clock()
	local last = lastSlideTime[player] or 0

	if (now - last) < Config.SLIDE_COOLDOWN then
		dprint("Slide blocked -> cooldown:", player.Name)
		self.ActionResult:Fire(player, "Slide", false, "Cooldown")
		return
	end

	lastSlideTime[player] = now

	local ok, reason = self.Server:_doSlide(player)
	self.ActionResult:Fire(player, "Slide", ok, reason)
end

function CombatMovementService:KnitInit()
	dprint("KnitInit() start")

	--// [CRITICAL] Reset IsSliding on player join and character spawn
	Players.PlayerAdded:Connect(function(player: Player)
		print("[CombatMovementService] PlayerAdded -> resetting IsSliding for:", player.Name)
		player:SetAttribute("IsSliding", false)

		player.CharacterAdded:Connect(function()
			print("[CombatMovementService] CharacterAdded -> resetting IsSliding for:", player.Name)
			player:SetAttribute("IsSliding", false)
			player.CharacterAdded:Connect(function(character)
				local hum = character:WaitForChild("Humanoid")

				-- Disable Roblox auto ragdoll recovery states
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

				print("✅ Disabled FallingDown / GettingUp states for:", player.Name)
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		dprint("PlayerRemoving -> clearing cooldowns for:", player.Name)
		lastSlideTime[player] = nil
		player:SetAttribute("IsSliding", false)
	end)

	dprint("KnitInit() complete")
end

function CombatMovementService:KnitStart()
	dprint("KnitStart() start")

	Players.PlayerAdded:Connect(function(player)

		player.CharacterAdded:Connect(function(character)

			character.ChildAdded:Connect(function(child)

				if child:IsA("Tool") then

					if child.Name == "Slide" or child.Name == "Golden Slide" then
						self:_equipSlideShoes(player, child.Name)
					end

					child.Unequipped:Connect(function()
						self:_unequipSlideShoes(player)
					end)

				end

			end)

		end)

	end)

	--// [CRITICAL] Reset all existing players' IsSliding
	for _, player in ipairs(Players:GetPlayers()) do
		print("[CombatMovementService] Resetting IsSliding for existing player:", player.Name)
		player:SetAttribute("IsSliding", false)
	end

	local ok, serviceOrErr = pcall(function()
		return Knit.GetService("BrainrotCarryService")
	end)

	if ok then
		self.BrainrotCarryService = serviceOrErr
		dprint("Got BrainrotCarryService ✅")
	else
		warn("[CombatMovementService] BrainrotCarryService not found:", serviceOrErr)
	end

	dprint("KnitStart() complete")
end

return CombatMovementService