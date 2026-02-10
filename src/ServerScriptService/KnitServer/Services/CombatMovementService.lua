--!strict
--// File: src/ServerScriptService/KnitServer/Services/CombatMovementService.lua
--// CombatMovementService.lua
--// Task 12 (LEGACY): Slide + Punch actions.
--// UPDATED:
--// - NO DAMAGE on Punch
--// - Slide/Punch bump targets
--// - If target is carrying Brainrot -> force drop IN FRONT of target (not collision point)

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("CombatMovementConfig"))

local CombatMovementService = Knit.CreateService({
	Name = "CombatMovementService",

	Client = {
		RequestSlide = function() end,
		RequestPunch = function() end,
		ActionResult = Knit.CreateSignal(), -- (actionName: string, success: boolean, reason: string)
	},
})

--// Cooldowns
local lastSlideTime: { [Player]: number } = {}
local lastPunchTime: { [Player]: number } = {}
--// Debug hitbox instances per player
local slideDebugPartByPlayer: { [Player]: BasePart } = {}

local slideAdornmentByPlayer: { [Player]: BoxHandleAdornment } = {}

function CombatMovementService:_ensureSlideDebugAdornment(player: Player, hrp: BasePart, hbSize: Vector3, offsetCF: CFrame, visible: boolean)
	--// Function: _ensureSlideDebugAdornment
	--// Creates/updates an Adornment attached to HRP. This VISUAL matches the actual hitbox.

	--// IF: missing hrp
	if not hrp or not hrp.Parent then
		return
	end

	local adorn = slideAdornmentByPlayer[player]
	--// IF: create new
	if not adorn then
		adorn = Instance.new("BoxHandleAdornment")
		adorn.Name = "SlideHitboxAdornment_" .. player.UserId
		adorn.Adornee = hrp
		adorn.AlwaysOnTop = true
		adorn.ZIndex = 10
		adorn.Parent = hrp -- parent anywhere; HRP keeps it with character
		slideAdornmentByPlayer[player] = adorn
		print("[SlideHitboxDebug] Created BoxHandleAdornment for:", player.Name)
	end

	--// IMPORTANT: match actual size + offset
	adorn.Size = hbSize
	adorn.CFrame = offsetCF

	--// IF: visible
	if visible then
		adorn.Transparency = Config.DEBUG_SLIDE_HITBOX_TRANSPARENCY
	else
		adorn.Transparency = 1
	end
end

function CombatMovementService:_updateSlideDebugAdornment(player: Player, hrp: BasePart, hbSize: Vector3, offsetCF: CFrame)
	--// Function: _updateSlideDebugAdornment
	--// Keeps visual synced to the same size/offset used by actual hitbox.

	self:_ensureSlideDebugAdornment(player, hrp, hbSize, offsetCF, true)
end


local function getOrCreateHitboxDebugFolder(): Folder
	--// Function: getOrCreateHitboxDebugFolder
	--// Ensures a folder exists in Workspace for debug visuals.

	local folder = workspace:FindFirstChild("_DebugHitboxes")
	--// IF: folder missing
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "_DebugHitboxes"
		folder.Parent = workspace
		print("[SlideHitboxDebug] Created folder:", folder:GetFullName())
	end
	return folder
end

function CombatMovementService:_getOrCreateSlideDebugPart(player: Player): BasePart
	--// Function: _getOrCreateSlideDebugPart
	--// Creates debug part (anchored). We manually set CFrame = hbCFrame each tick.

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



function CombatMovementService:_setSlideDebugVisible(player: Player, hrp: BasePart, visible: boolean)
	--// Function: _setSlideDebugVisible
	--// Shows/hides welded debug hitbox.

	local p = self:_getOrCreateSlideDebugPart(player, hrp)

	--// [IF] visible
	if visible then
		--// [DEBUG]
		print("[SlideHitboxDebug] Visible ON for:", player.Name)
		p.Transparency = Config.DEBUG_SLIDE_HITBOX_TRANSPARENCY
	else
		--// [DEBUG]
		print("[SlideHitboxDebug] Visible OFF for:", player.Name)
		p.Transparency = 1
	end
end


function CombatMovementService:_updateSlideDebugPart(player: Player, hrp: BasePart, hbSize: Vector3)
	--// Function: _updateSlideDebugPart
	--// Updates size of welded debug box (position follows HRP automatically).

	local p = self:_getOrCreateSlideDebugPart(player, hrp)
	p.Size = hbSize
end


function CombatMovementService:_cleanupSlideDebugPart(player: Player)
	--// Function: _cleanupSlideDebugPart
	--// Destroys debug part on cleanup (optional).

	local p = slideDebugPartByPlayer[player]
	if p then
		print("[SlideHitboxDebug] Destroy debug part for:", player.Name)
		p:Destroy()
		slideDebugPartByPlayer[player] = nil
	end
end


--// Reference to BrainrotCarryService
CombatMovementService.BrainrotCarryService = nil

local function dprint(...: any)
	--// Function: dprint
	--// Debug print helper.

	--// IF: debug enabled
	if Config.DEBUG_PRINTS then
		print("[CombatMovementService]", ...)
	end
end

local function getCharacterParts(player: Player): (Model?, Humanoid?, BasePart?)
	--// Function: getCharacterParts
	--// Returns character, humanoid, hrp.

	local character = player.Character
	--// IF: no character
	if not character then
		dprint("getCharacterParts() FAIL -> no character:", player.Name)
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	--// IF: no humanoid
	if not humanoid then
		dprint("getCharacterParts() FAIL -> no humanoid:", player.Name)
		return character, nil, nil
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	--// IF: no HRP
	if not hrp or not hrp:IsA("BasePart") then
		dprint("getCharacterParts() FAIL -> no HRP:", player.Name)
		return character, humanoid, nil
	end

	return character, humanoid, hrp
end

function CombatMovementService:_bumpTarget(attackerHRP: BasePart, targetHRP: BasePart, pushPower: number, pushUp: number)
	--// Function: _bumpTarget
	--// Strong knockback using LinearVelocity (reliable for characters).

	--// [DEBUG] Print bump info
	dprint("_bumpTarget() called -> attacker:", attackerHRP:GetFullName(), "target:", targetHRP:GetFullName())

	--// [IMPORTANT] Get attacker forward on XZ plane (ignore Y)
	local look = attackerHRP.CFrame.LookVector
	local lookXZ = Vector3.new(look.X, 0, look.Z)

	--// [IF] fallback if lookXZ is too small
	if lookXZ.Magnitude < 0.001 then
		--// [DEBUG] lookXZ fallback
		dprint("_bumpTarget() lookXZ too small -> fallback (0,0,-1)")
		lookXZ = Vector3.new(0, 0, -1)
	end
	lookXZ = lookXZ.Unit

	--// [IMPORTANT] Direction from attacker -> target on XZ plane
	local toTarget = (targetHRP.Position - attackerHRP.Position)
	local toTargetXZ = Vector3.new(toTarget.X, 0, toTarget.Z)

	--// [IF] fallback if too close
	if toTargetXZ.Magnitude < 0.001 then
		--// [DEBUG] toTargetXZ fallback to lookXZ
		dprint("_bumpTarget() toTargetXZ too small -> using lookXZ")
		toTargetXZ = lookXZ
	end

	local dir = toTargetXZ.Unit

	--// [IMPORTANT] Enforce D-shape (front 180°):
	--// If the target direction is behind attacker, mirror it to front.
	local dot = dir:Dot(lookXZ)

	--// [IF] behind attacker -> reflect to front
	if dot < 0 then
		--// [DEBUG] Target behind -> reflecting into front hemisphere
		dprint("_bumpTarget() target behind -> reflect, dot:", dot)

		--// Reflection across plane with normal lookXZ: v' = v - 2*(v·n)*n
		dir = (dir - 2 * dot * lookXZ).Unit
	end

	--// [IMPORTANT] Strong final velocity (mostly horizontal + some up)
	local knockVel = (dir * pushPower) + Vector3.new(0, pushUp, 0)
	dprint("_bumpTarget() knockVel:", knockVel, "dot:", dot)

	--// [IMPORTANT] Clear old knockback objects if any
	local oldLV = targetHRP:FindFirstChild("KnockbackLinearVelocity")
	if oldLV then
		--// [DEBUG] old LV cleanup
		dprint("_bumpTarget() removing old KnockbackLinearVelocity")
		oldLV:Destroy()
	end

	local oldAtt = targetHRP:FindFirstChild("KnockbackAttachment")
	if oldAtt then
		--// [DEBUG] old attachment cleanup
		dprint("_bumpTarget() removing old KnockbackAttachment")
		oldAtt:Destroy()
	end

	--// [IMPORTANT] Reduce friction from humanoid control by wiping horizontal velocity
	local currentVel = targetHRP.AssemblyLinearVelocity
	targetHRP.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0)

	--// [IMPORTANT] Create attachment
	local att = Instance.new("Attachment")
	att.Name = "KnockbackAttachment"
	att.Parent = targetHRP

	--// [IMPORTANT] Create LinearVelocity for reliable push
	local lv = Instance.new("LinearVelocity")
	lv.Name = "KnockbackLinearVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = 500000 -- stronger than before
	lv.VectorVelocity = knockVel
	lv.Parent = targetHRP

	--// [DEBUG] Confirm applied
	dprint("_bumpTarget() LinearVelocity applied")

	--// [IMPORTANT] Cleanup after a bit (longer so it actually moves far)
	task.delay(0.25, function()
		--// [EVENT] cleanup knockback
		dprint("_bumpTarget() cleanup knockback")
		if lv and lv.Parent then lv:Destroy() end
		if att and att.Parent then att:Destroy() end
	end)
end



function CombatMovementService:_tryForceDropBrainrot(targetPlayer: Player, reason: string)
	--// Function: _tryForceDropBrainrot
	--// Forces brainrot drop in FRONT of target player.

	--// IF: no service
	if not self.BrainrotCarryService then
		dprint("_tryForceDropBrainrot() BrainrotCarryService missing")
		return
	end

	--// IF: not carrying
	if targetPlayer:GetAttribute("IsCarryingBrainrot") ~= true then
		dprint("_tryForceDropBrainrot() target not carrying:", targetPlayer.Name)
		return
	end

	dprint("Forcing brainrot drop (front) for:", targetPlayer.Name, "reason:", reason)

	--// IMPORTANT: call DropBrainrot with nil position => drop in front
	local ok, err = pcall(function()
		self.BrainrotCarryService:DropBrainrot(targetPlayer, reason, nil)
	end)

	--// IF: failed
	if not ok then
		warn("[CombatMovementService] Force drop brainrot failed:", err)
	end
end

function CombatMovementService:_slideBumpLoop(slider: Player, sliderCharacter: Model, sliderHRP: BasePart)
	--// Function: _slideBumpLoop
	--// Heartbeat + swept hitbox so the ACTUAL hitbox behaves like attached and never skips.

	dprint("_slideBumpLoop() START for:", slider.Name)

	--// IF: bump disabled
	if not Config.SLIDE_BUMP_ENABLED then
		dprint("_slideBumpLoop() STOP -> bump disabled")
		return
	end

	--// IMPORTANT: exclude slider
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { sliderCharacter }
	params.RespectCanCollide = false

	--// IMPORTANT: track who we already bumped
	local bumpedUserIds: { [number]: boolean } = {}

	--// IMPORTANT: one source of truth for offset and size
	local offsetCF = CFrame.new(0, 0, -Config.SLIDE_BUMP_FORWARD_OFFSET)
	local hbSize = Config.SLIDE_BUMP_HITBOX_SIZE

	--// IMPORTANT: sweep step to avoid tunneling (lower = more accurate)
	local SWEEP_STEP = 2

	--// IMPORTANT: last frame position
	local lastCF = sliderHRP.CFrame

	--// IF: debug -> show box (visual)
	if Config.DEBUG_SHOW_SLIDE_HITBOX then
		self:_ensureSlideDebugAdornment(slider, sliderHRP, hbSize, offsetCF, true)
	end

	while slider:GetAttribute("IsSliding") == true do
		--// Loop: every Heartbeat

		--// IF: HRP invalid
		if not sliderHRP or not sliderHRP.Parent then
			dprint("_slideBumpLoop() BREAK -> HRP invalid:", slider.Name)
			break
		end

		local currentCF = sliderHRP.CFrame
		local dist = (currentCF.Position - lastCF.Position).Magnitude

		--// IMPORTANT: sweep samples count
		local steps = math.max(1, math.ceil(dist / SWEEP_STEP))

		--// LOOP: sweep along movement so we don't miss fast collisions
		for i = 1, steps do
			--// Loop: sweep sample
			local alpha = i / steps
			local sampleCF = lastCF:Lerp(currentCF, alpha)

			--// IMPORTANT: ACTUAL hitbox CFrame (this is your real collision box)
			local hbCFrame = sampleCF * offsetCF

			--// IF: debug -> move the same visual to the same box (optional)
			if Config.DEBUG_SHOW_SLIDE_HITBOX then
				self:_updateSlideDebugAdornment(slider, sliderHRP, hbSize, offsetCF)
			end

			--// IMPORTANT: ACTUAL collision query
			local parts = workspace:GetPartBoundsInBox(hbCFrame, hbSize, params)

			--// LOOP: overlapped parts
			for _, part in ipairs(parts) do
				--// Loop: part
				if not part or not part.Parent then
					continue
				end

				local otherChar = part:FindFirstAncestorOfClass("Model")
				if not otherChar then
					continue
				end

				local otherPlayer = Players:GetPlayerFromCharacter(otherChar)
				if not otherPlayer or otherPlayer == slider then
					continue
				end

				--// IF: already bumped this slide
				if bumpedUserIds[otherPlayer.UserId] == true then
					continue
				end

				bumpedUserIds[otherPlayer.UserId] = true
				dprint("SLIDE HIT ✅ ->", slider.Name, "hit", otherPlayer.Name)

				local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
				if otherHRP and otherHRP:IsA("BasePart") then
					--// IMPORTANT: bump target
					self:_bumpTarget(sliderHRP, otherHRP, Config.SLIDE_BUMP_PUSH_POWER, Config.SLIDE_BUMP_PUSH_UP)
				end

				--// IMPORTANT: brainrot drop if needed
				if self.BrainrotCarryService and otherPlayer:GetAttribute("IsCarryingBrainrot") == true then
					self.BrainrotCarryService:DropBrainrot(otherPlayer, "SlideCollisionDrop", nil)
				end
			end
		end

		lastCF = currentCF
		RunService.Heartbeat:Wait()
	end

	--// IF: debug -> hide box
	if Config.DEBUG_SHOW_SLIDE_HITBOX then
		self:_ensureSlideDebugAdornment(slider, sliderHRP, hbSize, offsetCF, false)
	end

	dprint("_slideBumpLoop() END for:", slider.Name)
end



function CombatMovementService:_doSlide(player: Player): (boolean, string)
	--// Function: _doSlide
	--// Executes slide on server.

	dprint("_doSlide() START for:", player.Name)

	local character, humanoid, hrp = getCharacterParts(player)
	--// IF: missing parts
	if not character or not humanoid or not hrp then
		return false, "MissingCharacter"
	end

	--// IF: dead
	if humanoid.Health <= 0 then
		return false, "Dead"
	end

	--// IF: already sliding
	if player:GetAttribute("IsSliding") == true then
		dprint("_doSlide() BLOCKED -> already sliding:", player.Name)
		return false, "AlreadySliding"
	end

	--// IMPORTANT: set sliding attribute
	player:SetAttribute("IsSliding", true)
	dprint("IsSliding = true for:", player.Name)

	--// IMPORTANT: save walkspeed
	local oldWalkSpeed = humanoid.WalkSpeed

	--// IF: disable walkspeed
	if Config.SLIDE_DISABLE_WALKSPEED then
		humanoid.WalkSpeed = Config.SLIDE_TEMP_WALKSPEED
		dprint("WalkSpeed temp set:", humanoid.WalkSpeed, "for:", player.Name)
	end

	--// IMPORTANT: create attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "Combat_SlideAttachment"
	attachment.Parent = hrp

	--// IMPORTANT: linear velocity
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Combat_SlideLinearVelocity"
	lv.Attachment0 = attachment
	lv.MaxForce = Config.SLIDE_MAX_FORCE
	lv.RelativeTo = Enum.ActuatorRelativeTo.World

	--// IMPORTANT: set forward velocity
	lv.VectorVelocity = hrp.CFrame.LookVector * Config.SLIDE_SPEED
	lv.Parent = hrp

	dprint("Slide velocity applied:", lv.VectorVelocity, "duration:", Config.SLIDE_DURATION)

	--// Spawn: bump loop
	task.spawn(function()
		--// Event: spawn bump loop
		self:_slideBumpLoop(player, character, hrp)
	end)

	--// Delay: cleanup after duration
	task.delay(Config.SLIDE_DURATION, function()
		--// Event: delayed cleanup
		dprint("Slide cleanup for:", player.Name)

		--// IF: lv exists
		if lv and lv.Parent then
			lv:Destroy()
		end

		--// IF: attachment exists
		if attachment and attachment.Parent then
			attachment:Destroy()
		end

		--// IF: restore walkspeed
		if Config.SLIDE_DISABLE_WALKSPEED then
			humanoid.WalkSpeed = oldWalkSpeed
			dprint("WalkSpeed restored:", oldWalkSpeed, "for:", player.Name)
		end

		--// IMPORTANT: clear attribute
		player:SetAttribute("IsSliding", false)
		dprint("IsSliding = false for:", player.Name)
	end)

	return true, "OK"
end

function CombatMovementService:_doPunch(player: Player): (boolean, string)
	--// Function: _doPunch
	--// Executes punch (NO DAMAGE) on server.

	dprint("_doPunch() START for:", player.Name)

	local character, humanoid, hrp = getCharacterParts(player)
	--// IF: missing parts
	if not character or not humanoid or not hrp then
		return false, "MissingCharacter"
	end

	--// IF: dead
	if humanoid.Health <= 0 then
		return false, "Dead"
	end

	--// IF: already punching
	if player:GetAttribute("IsPunching") == true then
		dprint("_doPunch() BLOCKED -> already punching:", player.Name)
		return false, "AlreadyPunching"
	end

	--// IMPORTANT: set punching
	player:SetAttribute("IsPunching", true)
	dprint("IsPunching = true for:", player.Name)

	--// IMPORTANT: build hitbox in front
	local hbCFrame = hrp.CFrame * CFrame.new(0, 0, -Config.PUNCH_HITBOX_FORWARD_OFFSET)
	local hbSize = Config.PUNCH_HITBOX_SIZE

	--// IMPORTANT: exclude attacker
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = false

	local parts = workspace:GetPartBoundsInBox(hbCFrame, hbSize, params)

	--// Choose closest target
	local bestPlayer: Player? = nil
	local bestHRP: BasePart? = nil
	local bestDist = math.huge

	--// LOOP: parts
	for _, part in ipairs(parts) do
		--// Loop: part
		if not part or not part.Parent then
			continue
		end

		local otherChar = part:FindFirstAncestorOfClass("Model")
		--// IF: no model
		if not otherChar then
			continue
		end

		local otherPlayer = Players:GetPlayerFromCharacter(otherChar)
		--// IF: not a player or self
		if not otherPlayer or otherPlayer == player then
			continue
		end

		local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
		--// IF: missing HRP
		if not otherHRP or not otherHRP:IsA("BasePart") then
			continue
		end

		local dist = (otherHRP.Position - hrp.Position).Magnitude
		--// IF: closer
		if dist < bestDist then
			bestDist = dist
			bestPlayer = otherPlayer
			bestHRP = otherHRP
		end
	end

	--// IF: found target
	if bestPlayer and bestHRP then
		dprint("PUNCH HIT -> attacker:", player.Name, "target:", bestPlayer.Name, "dist:", bestDist)

		--// IMPORTANT: bump target (NO DAMAGE)
		self:_bumpTarget(hrp, bestHRP, Config.PUNCH_BUMP_PUSH_POWER, Config.PUNCH_BUMP_PUSH_UP)

		--// IMPORTANT: force drop brainrot in front (if carrying)
		self:_tryForceDropBrainrot(bestPlayer, "PunchHitDrop")
	else
		dprint("PUNCH -> no target hit for:", player.Name)
	end

	--// Delay: clear punching state
	task.delay(0.35, function()
		--// Event: delayed clear
		player:SetAttribute("IsPunching", false)
		dprint("IsPunching = false for:", player.Name)
	end)

	return true, "OK"
end

function CombatMovementService.Client:RequestSlide(player: Player)
	--// Function: Client.RequestSlide
	--// Client requests slide; server checks cooldown.

	dprint("Client.RequestSlide from:", player.Name)

	local now = os.clock()
	local last = lastSlideTime[player] or 0

	--// IF: cooldown
	if (now - last) < Config.SLIDE_COOLDOWN then
		dprint("Slide blocked -> cooldown:", player.Name)
		self.ActionResult:Fire(player, "Slide", false, "Cooldown")
		return
	end

	--// IMPORTANT: set cooldown
	lastSlideTime[player] = now

	local ok, reason = self.Server:_doSlide(player)
	self.ActionResult:Fire(player, "Slide", ok, reason)
end

function CombatMovementService.Client:RequestPunch(player: Player)
	--// Function: Client.RequestPunch
	--// Client requests punch; server checks cooldown.

	dprint("Client.RequestPunch from:", player.Name)

	local now = os.clock()
	local last = lastPunchTime[player] or 0

	--// IF: cooldown
	if (now - last) < Config.PUNCH_COOLDOWN then
		dprint("Punch blocked -> cooldown:", player.Name)
		self.ActionResult:Fire(player, "Punch", false, "Cooldown")
		return
	end

	--// IMPORTANT: set cooldown
	lastPunchTime[player] = now

	local ok, reason = self.Server:_doPunch(player)
	self.ActionResult:Fire(player, "Punch", ok, reason)
end

function CombatMovementService:KnitInit()
	--// Function: KnitInit
	--// Cleanup cooldown tables.

	dprint("KnitInit() start")

	Players.PlayerRemoving:Connect(function(player: Player)
		--// Event: PlayerRemoving
		dprint("PlayerRemoving -> clearing cooldowns for:", player.Name)
		lastSlideTime[player] = nil
		lastPunchTime[player] = nil
	end)

	dprint("KnitInit() complete")
end

function CombatMovementService:KnitStart()
	--// Function: KnitStart
	--// Get BrainrotCarryService reference.

	dprint("KnitStart() start")

	local ok, serviceOrErr = pcall(function()
		--// Important: GetService
		return Knit.GetService("BrainrotCarryService")
	end)

	--// IF: got service
	if ok then
		self.BrainrotCarryService = serviceOrErr
		dprint("Got BrainrotCarryService ✅")
	else
		warn("[CombatMovementService] BrainrotCarryService not found:", serviceOrErr)
	end

	dprint("KnitStart() complete")
end

return CombatMovementService
