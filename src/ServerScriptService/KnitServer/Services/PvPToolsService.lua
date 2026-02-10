--!strict
--// File: src/ServerScriptService/KnitServer/Services/PvPToolsService.lua
--// PvPToolsService.lua
--// Server-authoritative Tool-based Slide + Punch bump system.
--// UPDATED (Punch ONLY):
--// - "Slap game" mechanics: server-owned physics + strong LinearVelocity + spin + short hit-window
--// - NO DAMAGE
--// - Brainrot drop stays as-is (drop in front of target)
--// NOTE: Slide code is unchanged.

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("PvPToolsConfig"))

local PvPToolsService = Knit.CreateService({
	Name = "PvPToolsService",

	Client = {
		RequestSlide = function() end,
		RequestPunch = function() end,

		--// Debug result to client
		ActionResult = Knit.CreateSignal(), -- (actionName: string, success: boolean, reason: string)
	},
})

--// Cooldowns
local lastSlideTime: { [Player]: number } = {}
local lastPunchTime: { [Player]: number } = {}

--// Debug hitbox instances per player
local slideDebugPartByPlayer: { [Player]: BasePart } = {}
local slideAdornmentByPlayer: { [Player]: BoxHandleAdornment } = {}
--// Slap ragdoll collision restore storage
local slapRestoreCollide: { [Player]: { [BasePart]: boolean } } = {}
local slapRestoreToken: { [Player]: number } = {}


function PvPToolsService:_ensureSlideDebugAdornment(player: Player, hrp: BasePart, hbSize: Vector3, offsetCF: CFrame, visible: boolean)
	--// Function: _ensureSlideDebugAdornment
	--// Creates/updates an Adornment attached to HRP. This VISUAL matches the actual hitbox.

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

function PvPToolsService:_updateSlideDebugAdornment(player: Player, hrp: BasePart, hbSize: Vector3, offsetCF: CFrame)
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

function PvPToolsService:_getOrCreateSlideDebugPart(player: Player): BasePart
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

function PvPToolsService:_setSlideDebugVisible(player: Player, hrp: BasePart, visible: boolean)
	local p = self:_getOrCreateSlideDebugPart(player)

	if visible then
		print("[SlideHitboxDebug] Visible ON for:", player.Name)
		p.Transparency = Config.DEBUG_SLIDE_HITBOX_TRANSPARENCY
	else
		print("[SlideHitboxDebug] Visible OFF for:", player.Name)
		p.Transparency = 1
	end
end

function PvPToolsService:_updateSlideDebugPart(player: Player, hrp: BasePart, hbSize: Vector3)
	local p = self:_getOrCreateSlideDebugPart(player)
	p.Size = hbSize
end

function PvPToolsService:_cleanupSlideDebugPart(player: Player)
	local p = slideDebugPartByPlayer[player]
	if p then
		print("[SlideHitboxDebug] Destroy debug part for:", player.Name)
		p:Destroy()
		slideDebugPartByPlayer[player] = nil
	end
end

--// Service refs
PvPToolsService.BrainrotCarryService = nil

local function dprint(...: any)
	if Config.DEBUG_PRINTS then
		print("[PvPToolsService]", ...)
	end
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

local function isToolEquipped(player: Player, toolName: string): boolean
	local character = player.Character
	if not character then
		return false
	end

	local tool = character:FindFirstChild(toolName)
	if tool and tool:IsA("Tool") then
		return true
	end

	return false
end

local function isBrainrotEquipped(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("IsBrainrotTool") == true then
			print("[PvPToolsService] Brainrot equipped detected:", player.Name, child.Name)
			return true
		end
	end

	return false
end

function PvPToolsService:_getPunchToolTemplate(): Tool?
	dprint("_getPunchToolTemplate() called")

	local assets = ReplicatedStorage:FindFirstChild(Config.ASSETS_FOLDER_NAME)
	if not assets or not assets:IsA("Folder") then
		warn("[PvPToolsService] Missing ReplicatedStorage/Assets folder")
		return nil
	end

	local punchesFolder = assets:FindFirstChild(Config.PUNCHES_FOLDER_NAME)
	if not punchesFolder or not punchesFolder:IsA("Folder") then
		warn("[PvPToolsService] Missing Assets/Punches folder")
		return nil
	end

	local slapHandFolder = punchesFolder:FindFirstChild(Config.SLAP_HAND_FOLDER_NAME)
	if not slapHandFolder or not slapHandFolder:IsA("Folder") then
		warn("[PvPToolsService] Missing Assets/Punches/Slap Hand folder")
		return nil
	end

	local tool = slapHandFolder:FindFirstChild(Config.PUNCH_TOOL_TEMPLATE_NAME)
	if not tool or not tool:IsA("Tool") then
		warn("[PvPToolsService] Missing Tool template:", Config.PUNCH_TOOL_TEMPLATE_NAME)
		return nil
	end

	dprint("Found punch tool template:", tool:GetFullName())
	return tool
end

function PvPToolsService:_sanitizeToolClone(tool: Tool)
	dprint("_sanitizeToolClone() called for tool:", tool.Name)

	for _, legacyName in ipairs(Config.REMOVE_LEGACY_SCRIPT_NAMES) do
		local inst = tool:FindFirstChild(legacyName, true)
		if inst and (inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript")) then
			dprint("Removing legacy script from clone:", inst:GetFullName())
			inst:Destroy()
		end
	end

	for _, desc in ipairs(tool:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.CanQuery = true
			desc.CanTouch = true
		end
	end
end

function PvPToolsService:_createSlideTool(): Tool
	dprint("_createSlideTool() creating slide tool")

	local tool = Instance.new("Tool")
	tool.Name = Config.SLIDE_TOOL_NAME
	tool.RequiresHandle = false
	tool:SetAttribute("PvPToolType", "Slide")

	return tool
end

function PvPToolsService:_ensureToolsForPlayer(player: Player)
	dprint("_ensureToolsForPlayer() called for:", player.Name)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		dprint("Backpack missing (will retry on CharacterAdded):", player.Name)
		return
	end

	local starterGear = player:FindFirstChild("StarterGear")

	local function hasTool(toolName: string): boolean
		if backpack:FindFirstChild(toolName) then
			return true
		end
		if player.Character and player.Character:FindFirstChild(toolName) then
			return true
		end
		if starterGear and starterGear:FindFirstChild(toolName) then
			return true
		end
		return false
	end

	-- Ensure Slide tool
	if not hasTool(Config.SLIDE_TOOL_NAME) then
		dprint("Giving Slide tool to:", player.Name)

		local slideTool = self:_createSlideTool()

		if Config.GIVE_TO_BACKPACK then
			slideTool:Clone().Parent = backpack
			dprint("Slide tool cloned into Backpack for:", player.Name)
		end

		if Config.GIVE_TO_STARTER_GEAR and starterGear then
			slideTool:Clone().Parent = starterGear
			dprint("Slide tool cloned into StarterGear for:", player.Name)
		end

		slideTool:Destroy()
	else
		dprint("Slide tool already exists for:", player.Name)
	end

	-- Ensure Punch tool
	if not hasTool(Config.PUNCH_TOOL_NAME) then
		dprint("Giving Punch tool to:", player.Name)

		local template = self:_getPunchToolTemplate()
		if not template then
			warn("[PvPToolsService] Punch tool template missing - cannot give tool to:", player.Name)
			return
		end

		local cloned = template:Clone()
		cloned.Name = Config.PUNCH_TOOL_NAME
		self:_sanitizeToolClone(cloned)

		if Config.GIVE_TO_BACKPACK then
			local backpackClone = cloned:Clone()
			backpackClone.Parent = backpack
			dprint("Punch tool cloned into Backpack for:", player.Name)
		end

		if Config.GIVE_TO_STARTER_GEAR and starterGear then
			local gearClone = cloned:Clone()
			gearClone.Parent = starterGear
			dprint("Punch tool cloned into StarterGear for:", player.Name)
		end

		cloned:Destroy()
	else
		dprint("Punch tool already exists for:", player.Name)
	end
end

--// ------------------------------
--// Brainrot drop helper (unchanged)
--// ------------------------------
function PvPToolsService:_tryForceDropBrainrot(targetPlayer: Player, reason: string)
	if not Config.FORCE_DROP_BRAINROT_ON_HIT then
		return
	end
	if not self.BrainrotCarryService then
		dprint("BrainrotCarryService missing -> cannot force drop for:", targetPlayer.Name)
		return
	end
	if targetPlayer:GetAttribute("IsCarryingBrainrot") ~= true then
		dprint("Target not carrying brainrot -> no drop:", targetPlayer.Name)
		return
	end

	dprint("Target carrying brainrot -> forcing drop (front):", targetPlayer.Name, "reason:", reason)

	local ok, err = pcall(function()
		self.BrainrotCarryService:DropBrainrot(targetPlayer, reason, nil)
	end)
	if not ok then
		warn("[PvPToolsService] Force drop brainrot failed:", err)
	end
end

--// =========================================================
--// NEW: SLAP GAME KNOCKBACK (Punch only)
--// =========================================================
function PvPToolsService:_applySlapKnockback(attackerHRP: BasePart, targetPlayer: Player, targetChar: Model, hitPart: BasePart?)
	local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetHRP or not targetHRP:IsA("BasePart") then return end

	-- Make sure physics is server-owned so it doesn't "stick"
	pcall(function()
		targetHRP:SetNetworkOwner(nil)
	end)

	-- Turn on ragdoll-like physics collisions
	self:_setSlapRagdoll(targetPlayer, true)
	
	--// HEIGHT CAP (max rise = characterHeight*2 + 6)
	local charHeight = targetChar:GetExtentsSize().Y
	local startY = targetHRP.Position.Y
	local maxY = startY + (charHeight * Config.SLAP_MAX_RISE_MULT) + Config.SLAP_MAX_RISE_OFFSET


	-- Direction: TRUE free angle (no D-shape, no mirroring)
	-- Always away from attacker, regardless of where attacker stands
	local dir = (targetHRP.Position - attackerHRP.Position)
	if dir.Magnitude < 0.1 then
		dir = attackerHRP.CFrame.LookVector
	end
	dir = dir.Unit

	-- Choose where to apply force (hit part if valid, else HRP)
	local impulsePart = targetHRP
	if hitPart and hitPart:IsDescendantOf(targetChar) and hitPart:IsA("BasePart") then
		impulsePart = hitPart
	end

	-- wipe horizontal so humanoid doesn't "fight" the shove
	local cur = targetHRP.AssemblyLinearVelocity
	targetHRP.AssemblyLinearVelocity = Vector3.new(0, cur.Y, 0)

	-- Apply ONE impulse (natural free-fly)
	local mass = targetHRP.AssemblyMass
	local impulse = (dir * Config.SLAP_IMPULSE + Vector3.new(0, Config.SLAP_UP_IMPULSE, 0)) * mass
	impulsePart:ApplyImpulseAtPosition(impulse, impulsePart.Position)

	-- Add spin (one-time)
	local spinAxis = Vector3.new(math.random(-100,100)/100, 1, math.random(-100,100)/100).Unit
	targetHRP:ApplyAngularImpulse(spinAxis * (Config.SLAP_ANGULAR_IMPULSE * mass))

	-- Brainrot drop remains same logic
	self:_tryForceDropBrainrot(targetPlayer, "PunchHitDrop")

	-- Restore after a short time (extend timer if slapped again)
	local token = (slapRestoreToken[targetPlayer] or 0) + 1
	slapRestoreToken[targetPlayer] = token
	
	--// While ragdolled, prevent going above maxY
	task.spawn(function()
		local t0 = os.clock()
		while slapRestoreToken[targetPlayer] == token and (os.clock() - t0) < Config.SLAP_RAGDOLL_TIME do
			if targetHRP and targetHRP.Parent then
				local pos = targetHRP.Position
				if pos.Y > maxY then
					-- kill upward movement
					local v = targetHRP.AssemblyLinearVelocity
					targetHRP.AssemblyLinearVelocity = Vector3.new(v.X, math.min(0, v.Y), v.Z)

					-- clamp position but keep rotation
					local rot = targetHRP.CFrame - targetHRP.CFrame.Position
					targetHRP.CFrame = CFrame.new(pos.X, maxY, pos.Z) * rot
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)


	task.delay(Config.SLAP_RAGDOLL_TIME, function()
		-- only restore if no newer slap happened
		if slapRestoreToken[targetPlayer] ~= token then return end
		self:_setSlapRagdoll(targetPlayer, false)

		pcall(function()
			targetHRP:SetNetworkOwnershipAuto()
		end)
	end)
end


function PvPToolsService:_setSlapRagdoll(targetPlayer: Player, enabled: boolean)
	local character = targetPlayer.Character
	if not character then return end

	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if enabled then
		-- store original collision states once per slap session
		if not slapRestoreCollide[targetPlayer] then
			local map: { [BasePart]: boolean } = {}
			for _, d in ipairs(character:GetDescendants()) do
				if d:IsA("BasePart") then
					map[d] = d.CanCollide
					d.CanCollide = true -- key: limbs collide with world
				end
			end
			slapRestoreCollide[targetPlayer] = map
		else
			-- already ragdolled: ensure collisions still on
			for part, _ in pairs(slapRestoreCollide[targetPlayer]) do
				if part and part.Parent then
					part.CanCollide = true
				end
			end
		end

		hum.AutoRotate = false
		hum.PlatformStand = true
		hum:ChangeState(Enum.HumanoidStateType.Physics)
	else
		-- restore collisions
		local map = slapRestoreCollide[targetPlayer]
		if map then
			for part, old in pairs(map) do
				if part and part.Parent then
					part.CanCollide = old
				end
			end
		end
		slapRestoreCollide[targetPlayer] = nil

		hum.PlatformStand = false
		hum.AutoRotate = true
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end


function PvPToolsService:_punchHitWindow(player: Player, attackerChar: Model, attackerHRP: BasePart): boolean
	local offsetCF = CFrame.new(0, 0, -Config.PUNCH_HITBOX_FORWARD_OFFSET)
	local hbSize = Config.PUNCH_HITBOX_SIZE

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attackerChar }
	params.RespectCanCollide = false

	local t0 = os.clock()
	while (os.clock() - t0) < Config.SLAP_HIT_WINDOW do
		if not attackerHRP or not attackerHRP.Parent then break end

		local hbCFrame = attackerHRP.CFrame * offsetCF
		local parts = workspace:GetPartBoundsInBox(hbCFrame, hbSize, params)

		-- Pick nearest valid player
		local bestPlayer: Player? = nil
		local bestChar: Model? = nil
		local bestPart: BasePart? = nil
		local bestDist = math.huge

		for _, part in ipairs(parts) do
			local otherChar = part and part:FindFirstAncestorOfClass("Model")
			if otherChar then
				local otherPlayer = Players:GetPlayerFromCharacter(otherChar)
				if otherPlayer and otherPlayer ~= player then
					local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
					if otherHRP and otherHRP:IsA("BasePart") then
						local dist = (otherHRP.Position - attackerHRP.Position).Magnitude
						if dist < bestDist then
							bestDist = dist
							bestPlayer = otherPlayer
							bestChar = otherChar
							bestPart = part
						end
					end
				end
			end
		end

		if bestPlayer and bestChar then
			self:_applySlapKnockback(attackerHRP, bestPlayer, bestChar, bestPart)
			return true
		end

		RunService.Heartbeat:Wait()
	end

	return false
end


--// ------------------------------
--// Punch action (UPDATED to slap-game mechanics)
--// ------------------------------
function PvPToolsService:_doPunch(player: Player): (boolean, string)
	dprint("_doPunch() called by:", player.Name)

	local character, humanoid, hrp = getCharacterParts(player)
	if not character or not humanoid or not hrp then
		return false, "MissingCharacter"
	end

	-- block if brainrot equipped
	if isBrainrotEquipped(player) == true then
		dprint("_doPunch() blocked -> carrying brainrot:", player.Name)
		return false, "CarryingBrainrot"
	end

	if humanoid.Health <= 0 then
		return false, "Dead"
	end

	if Config.REQUIRE_EQUIPPED_TOOL then
		if not isToolEquipped(player, Config.PUNCH_TOOL_NAME) then
			dprint("Punch blocked -> tool not equipped for:", player.Name)
			return false, "ToolNotEquipped"
		end
	end

	-- Slap-game hit window (reliable hit)
	local hit = self:_punchHitWindow(player, character, hrp)
	if not hit then
		dprint("Punch -> no target in window for:", player.Name)
		return false, "NoTarget"
	end

	return true, "OK"
end

--// ------------------------------
--// Slide bump loop + Slide action (UNCHANGED)
--// ------------------------------
function PvPToolsService:_slideBumpLoop(slider: Player, sliderCharacter: Model, sliderHRP: BasePart)
	dprint("_slideBumpLoop() START for:", slider.Name)

	if not Config.SLIDE_BUMP_ENABLED then
		dprint("_slideBumpLoop() STOP -> bump disabled")
		return
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { sliderCharacter }
	params.RespectCanCollide = false

	local bumpedUserIds: { [number]: boolean } = {}

	local offsetCF = CFrame.new(0, 0, -Config.SLIDE_BUMP_FORWARD_OFFSET)
	local hbSize = Config.SLIDE_BUMP_HITBOX_SIZE

	local SWEEP_STEP = 2
	local lastCF = sliderHRP.CFrame

	if Config.DEBUG_SHOW_SLIDE_HITBOX then
		self:_ensureSlideDebugAdornment(slider, sliderHRP, hbSize, offsetCF, true)
	end

	while slider:GetAttribute("IsSliding") == true do
		if not sliderHRP or not sliderHRP.Parent then
			dprint("_slideBumpLoop() BREAK -> HRP invalid:", slider.Name)
			break
		end

		local currentCF = sliderHRP.CFrame
		local dist = (currentCF.Position - lastCF.Position).Magnitude
		local steps = math.max(1, math.ceil(dist / SWEEP_STEP))

		for i = 1, steps do
			local alpha = i / steps
			local sampleCF = lastCF:Lerp(currentCF, alpha)
			local hbCFrame = sampleCF * offsetCF

			if Config.DEBUG_SHOW_SLIDE_HITBOX then
				self:_updateSlideDebugAdornment(slider, sliderHRP, hbSize, offsetCF)
			end

			local parts = workspace:GetPartBoundsInBox(hbCFrame, hbSize, params)

			for _, part in ipairs(parts) do
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

				if bumpedUserIds[otherPlayer.UserId] == true then
					continue
				end

				bumpedUserIds[otherPlayer.UserId] = true
				dprint("SLIDE HIT ✅ ->", slider.Name, "hit", otherPlayer.Name)

				local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
				if otherHRP and otherHRP:IsA("BasePart") then
					-- keep existing slide bump logic
					local att = Instance.new("Attachment")
					att.Name = "KnockbackAttachment"
					att.Parent = otherHRP

					local lv = Instance.new("LinearVelocity")
					lv.Name = "KnockbackLinearVelocity"
					lv.Attachment0 = att
					lv.RelativeTo = Enum.ActuatorRelativeTo.World
					lv.MaxForce = 500000
					lv.VectorVelocity = (otherHRP.Position - sliderHRP.Position).Unit * Config.SLIDE_BUMP_PUSH_POWER + Vector3.new(0, Config.SLIDE_BUMP_PUSH_UP, 0)
					lv.Parent = otherHRP

					task.delay(0.25, function()
						if lv and lv.Parent then lv:Destroy() end
						if att and att.Parent then att:Destroy() end
					end)
				end

				if self.BrainrotCarryService and otherPlayer:GetAttribute("IsCarryingBrainrot") == true then
					self.BrainrotCarryService:DropBrainrot(otherPlayer, "SlideCollisionDrop", nil)
				end
			end
		end

		lastCF = currentCF
		RunService.Heartbeat:Wait()
	end

	if Config.DEBUG_SHOW_SLIDE_HITBOX then
		self:_ensureSlideDebugAdornment(slider, sliderHRP, hbSize, offsetCF, false)
	end

	dprint("_slideBumpLoop() END for:", slider.Name)
end

function PvPToolsService:_doSlide(player: Player): (boolean, string)
	dprint("_doSlide() called by:", player.Name)

	local character, humanoid, hrp = getCharacterParts(player)
	if not character or not humanoid or not hrp then
		return false, "MissingCharacter"
	end

	if isBrainrotEquipped(player) == true then
		dprint("_doSlide() blocked -> carrying brainrot:", player.Name)
		return false, "CarryingBrainrot"
	end

	if humanoid.Health <= 0 then
		return false, "Dead"
	end

	if player:GetAttribute("IsSliding") == true then
		dprint("Slide blocked -> already sliding:", player.Name)
		return false, "AlreadySliding"
	end

	if Config.REQUIRE_EQUIPPED_TOOL then
		if not isToolEquipped(player, Config.SLIDE_TOOL_NAME) then
			dprint("Slide blocked -> tool not equipped for:", player.Name)
			return false, "ToolNotEquipped"
		end
	end

	player:SetAttribute("IsSliding", true)
	dprint("IsSliding = true for:", player.Name)

	local oldWalkSpeed = humanoid.WalkSpeed

	if Config.SLIDE_DISABLE_WALKSPEED then
		humanoid.WalkSpeed = Config.SLIDE_TEMP_WALKSPEED
		dprint("WalkSpeed temp set to:", humanoid.WalkSpeed, "for:", player.Name)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "PvPTools_SlideAttachment"
	attachment.Parent = hrp

	local lv = Instance.new("LinearVelocity")
	lv.Name = "PvPTools_SlideLinearVelocity"
	lv.Attachment0 = attachment
	lv.MaxForce = Config.SLIDE_MAX_FORCE
	lv.RelativeTo = Enum.ActuatorRelativeTo.World

	local dir = hrp.CFrame.LookVector
	lv.VectorVelocity = dir * Config.SLIDE_SPEED
	lv.Parent = hrp

	dprint("Slide LinearVelocity applied:", lv.VectorVelocity, "duration:", Config.SLIDE_DURATION, "player:", player.Name)

	task.spawn(function()
		self:_slideBumpLoop(player, character, hrp)
	end)

	task.delay(Config.SLIDE_DURATION, function()
		dprint("Slide ended -> cleanup for:", player.Name)

		if lv and lv.Parent then
			lv:Destroy()
		end
		if attachment and attachment.Parent then
			attachment:Destroy()
		end

		if Config.SLIDE_DISABLE_WALKSPEED then
			humanoid.WalkSpeed = oldWalkSpeed
			dprint("WalkSpeed restored:", oldWalkSpeed, "for:", player.Name)
		end

		player:SetAttribute("IsSliding", false)
		dprint("IsSliding = false for:", player.Name)
	end)

	return true, "OK"
end

--// ------------------------------
--// Remotes (Client -> Server)
--// ------------------------------
function PvPToolsService.Client:RequestPunch(player: Player)
	if isBrainrotEquipped(player) == true then
		dprint("RequestPunch blocked -> carrying brainrot:", player.Name)
		self.ActionResult:Fire(player, "Punch", false, "CarryingBrainrot")
		return
	end

	dprint("Client.RequestPunch from:", player.Name)

	local now = os.clock()
	local last = lastPunchTime[player] or 0
	if (now - last) < Config.PUNCH_COOLDOWN then
		dprint("Punch blocked -> cooldown for:", player.Name)
		self.ActionResult:Fire(player, "Punch", false, "Cooldown")
		return
	end

	lastPunchTime[player] = now

	local ok, reason = self.Server:_doPunch(player)
	self.ActionResult:Fire(player, "Punch", ok, reason)
end

function PvPToolsService.Client:RequestSlide(player: Player)
	if isBrainrotEquipped(player) == true then
		dprint("RequestSlide blocked -> carrying brainrot:", player.Name)
		self.ActionResult:Fire(player, "Slide", false, "CarryingBrainrot")
		return
	end

	dprint("Client.RequestSlide from:", player.Name)

	local now = os.clock()
	local last = lastSlideTime[player] or 0
	if (now - last) < Config.SLIDE_COOLDOWN then
		dprint("Slide blocked -> cooldown for:", player.Name)
		self.ActionResult:Fire(player, "Slide", false, "Cooldown")
		return
	end

	lastSlideTime[player] = now

	local ok, reason = self.Server:_doSlide(player)
	self.ActionResult:Fire(player, "Slide", ok, reason)
end

--// ------------------------------
--// Knit lifecycle
--// ------------------------------
function PvPToolsService:KnitInit()
	dprint("KnitInit() start")

	Players.PlayerAdded:Connect(function(player: Player)
		dprint("PlayerAdded:", player.Name)

		player.CharacterAdded:Connect(function()
			dprint("CharacterAdded -> ensuring tools for:", player.Name)
			task.defer(function()
				self:_ensureToolsForPlayer(player)
			end)
		end)

		task.defer(function()
			self:_ensureToolsForPlayer(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		dprint("PlayerRemoving -> cleanup:", player.Name)
		lastSlideTime[player] = nil
		lastPunchTime[player] = nil
	end)

	dprint("KnitInit() complete")
end

function PvPToolsService:KnitStart()
	dprint("KnitStart() start")

	local ok, serviceOrErr = pcall(function()
		return Knit.GetService("BrainrotCarryService")
	end)

	if ok then
		self.BrainrotCarryService = serviceOrErr
		dprint("Got BrainrotCarryService reference ✅")
	else
		warn("[PvPToolsService] BrainrotCarryService not found:", serviceOrErr)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		dprint("Ensuring tools for existing player:", player.Name)
		self:_ensureToolsForPlayer(player)
	end

	dprint("KnitStart() complete")
end

return PvPToolsService
