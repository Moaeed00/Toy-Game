local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RagdollService = require(script.Parent.RagdollService)

local Utils: Folder = ServerScriptService:WaitForChild("Utils")
local CollisionGroupHandler: {} = require(Utils:WaitForChild("CollisionGroupHandler"))
local GlobalSounds = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Sounds")

local NPCService = Knit.CreateService {
	Name = "NPCService",
	Client = {
		ActivatePlayerRagdollEvent = Knit.CreateSignal(),
	}
}

local NPCCollisionGroup = "NPC"

local CONFIG = {
	WalkSpeed = 18,
	ChaseSpeed = 28,
	AttackRange = 13,
	AttackCooldown = 1,
	RagdollDuration = 1.5,
	FlingPower = 150,
	WanderInterval = 5,
	WanderWaitTime = 2,
	Animations = {
		Idle = "rbxassetid://80868660366700",
		Walk = "rbxassetid://132891437445360",
		Attack = "rbxassetid://92385984874297",
	}
}

type NPCData = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	HomePosition: Vector3,
	Tracks: {[string]: AnimationTrack},
	CurrentAnim: string?,
	LastAttack: number,
	IsAttacking: boolean,
	LastWander: number,
	IsWandering: boolean,
	OriginalCFrame: CFrame,
}

local npcs: {NPCData} = {}

function NPCService:KnitInit()
	print("[NPCService] Initialized")
end

function NPCService:KnitStart()
	NPCService.BrainrotCarryService = Knit.GetService("BrainrotCarryService")
	NPCService.DataHandlerService = Knit.GetService("DataHandlerService")

	for _, npc in ipairs(CollectionService:GetTagged("NPC")) do
		if npc:IsA("Model") then
			local data = self:SetupNPC(npc)
			if data then
				table.insert(npcs, data)
			end
		end
	end

	CollectionService:GetInstanceAddedSignal("NPC"):Connect(function(npc)
		if npc:IsA("Model") then
			local data = self:SetupNPC(npc)
			if data then
				table.insert(npcs, data)
			end
		end
	end)

	self.DataHandlerService.OnPlayerProfileLoaded:Connect(function(player: Player, Profile:{})
		local humanoid: Humanoid = player.Character:WaitForChild('Humanoid')
        if not humanoid then
            return
        end

		if not RagdollService.IsRagdolled(humanoid) then
			local motors = RagdollService.CreateJoints(player.Character)
			RagdollService.SetMotorsEnabled(motors, true)
		end
	end)

	RunService.Heartbeat:Connect(function()
		self:UpdateNPCs()
	end)
end

function NPCService:GetRandomWanderPoint(): Vector3?
	local SammyWanderingArea = Workspace:WaitForChild("Environment"):WaitForChild("SammyWanderingArea")
	if not SammyWanderingArea then
		return nil
	end

	local spawners = {}
	for _, child in ipairs(SammyWanderingArea:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "WanderingArea" then
			table.insert(spawners, child)
		end
	end
	if #spawners == 0 then
		return nil
	end

	local selected = spawners[math.random(1, #spawners)]
	local size = selected.Size
	local cf = selected.CFrame
	local randomX = (math.random() - 0.5) * size.X
	local randomZ = (math.random() - 0.5) * size.Z

	return (cf * CFrame.new(randomX, size.Y / 2 + 3, randomZ)).Position
end

function NPCService:ShouldChasePlayer(player: Player): boolean
	return player:GetAttribute("IsInBlocksSpawnArea") == true and player:GetAttribute("IsCarryingBrainrot") == true
end

function NPCService:ApplyFlingAndRagdoll(player: Player, character: Model, npcRoot: BasePart)
	if not npcRoot or not npcRoot.Parent then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		return
	end

	self.Client.ActivatePlayerRagdollEvent:Fire(player)

	local pushDir = rootPart.Position - npcRoot.CFrame.Position
	pushDir = Vector3.new(pushDir.X, 0, pushDir.Z)
	if pushDir.Magnitude < 0.01 then
		pushDir = npcRoot.CFrame.LookVector
	end
	local flingVector = (pushDir.Unit + Vector3.new(0, 0.4, 0)).Unit * CONFIG.FlingPower
	
	rootPart.AssemblyLinearVelocity = flingVector
end

function NPCService:PlayAnimation(npcData: NPCData, animName: string)
	if npcData.IsAttacking and animName ~= "Attack" then
		return
	end
	if npcData.CurrentAnim == animName then
		return
	end
	if npcData.CurrentAnim and npcData.Tracks[npcData.CurrentAnim] then
		npcData.Tracks[npcData.CurrentAnim]:Stop(0.2)
	end
	if npcData.Tracks[animName] then
		npcData.Tracks[animName]:Play(0.2)
	end
	npcData.CurrentAnim = animName
end

function NPCService:PerformAttack(npcData: NPCData, targetCharacter: Model, player: Player)
	local hit: Sound = GlobalSounds:WaitForChild("Sammy"):FindFirstChild("Slap")
	npcData.IsAttacking = true
	npcData.LastAttack = tick()
	npcData.Humanoid.WalkSpeed = 0
	npcData.Humanoid:MoveTo(npcData.Root.Position)

	if npcData.CurrentAnim and npcData.Tracks[npcData.CurrentAnim] then
		npcData.Tracks[npcData.CurrentAnim]:Stop()
	end
	npcData.CurrentAnim = "Attack"
	local attackTrack = npcData.Tracks["Attack"]
	if attackTrack then
		attackTrack:Play()
	end

	local hitFired = false
	local function fireHit()
		if hitFired then return end
		hitFired = true

		if hit then
			local hitSound = hit:Clone()
			hitSound.Parent = npcData.Root
			hitSound.Volume = 1
			hitSound:Play()
			Debris:AddItem(hitSound, hitSound.TimeLength + 0.5)
		end

		self.BrainrotCarryService:DropBrainrot(player)
		self:ApplyFlingAndRagdoll(player, targetCharacter, npcData.Root)
	end

	if attackTrack then
		attackTrack:GetMarkerReachedSignal("Hit"):Once(fireHit)
	end
	task.delay(0.4, fireHit)

	-- Unlock ONLY via delay — not via Stopped, which can fire prematurely
	-- task.spawn(function()
	-- 	task.wait()

	-- 	local duration = 1.5
	-- 	if attackTrack and attackTrack.Length > 0 then
	-- 		duration = attackTrack.Length + 0.15
	-- 	end

	-- 	task.wait(duration)

	-- 	npcData.IsAttacking = false
	-- 	npcData.CurrentAnim = nil
	-- 	npcData.Humanoid.WalkSpeed = CONFIG.WalkSpeed
	-- end)

	-- Unlock on animation end, with hard timeout so it can never get stuck
	local unlocked = false
	local function unlock()
		if unlocked then return end
		unlocked = true
		npcData.IsAttacking = false
		npcData.CurrentAnim = nil
		npcData.Humanoid.WalkSpeed = CONFIG.WalkSpeed
	end

	if attackTrack then
		local conn
		conn = attackTrack.Stopped:Connect(function()
			conn:Disconnect()
			unlock()
		end)
	end

	local duration = 1.5
	if attackTrack and attackTrack.Length > 0 then
		duration = attackTrack.Length + 0.1
	end
	task.delay(duration, unlock)
end

function NPCService:SetupNPC(model: Model): NPCData?
	local hum = model:FindFirstChild("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	if not hum or not root then
		return nil
	end

	root:SetNetworkOwner(nil)
	CollisionGroupHandler:AddCollisionGroup(NPCCollisionGroup, root)

	local tracks = {}
	local animator = hum:FindFirstChild("Animator") or Instance.new("Animator", hum)

	for name, id in pairs(CONFIG.Animations) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		tracks[name] = animator:LoadAnimation(anim)
	end

	local Heartbeat: Sound = GlobalSounds:FindFirstChild("Heartbeat")
	if Heartbeat then
		local heartbeatSound = Heartbeat:Clone()
		heartbeatSound.Parent = root
		heartbeatSound.Looped = true
		heartbeatSound.RollOffMaxDistance = 96
		heartbeatSound.RollOffMinDistance = 8
		heartbeatSound.Volume = 1
		heartbeatSound:Play()
	end

	local footstep: Sound = GlobalSounds:WaitForChild("Sammy"):FindFirstChild("Footstep")
	if footstep and tracks["Walk"] then
		local footstepSound: Sound = footstep:Clone()
		footstepSound.Parent = root
		footstepSound.Looped = false
		footstepSound.RollOffMaxDistance = 96
		footstepSound.RollOffMinDistance = 8
		footstepSound.Volume = 1

		tracks["Walk"]:GetMarkerReachedSignal("Step"):Connect(function()
			footstepSound:Play()
		end)
	end

	local npcData: NPCData = {
		Model = model,
		Root = root,
		Humanoid = hum,
		HomePosition = root.Position,
		Tracks = tracks,
		CurrentAnim = nil,
		LastAttack = 0,
		IsAttacking = false,
		LastWander = 0,
		IsWandering = false,
		OriginalCFrame = model:GetPivot(),
	}

	-- Respawn logic
	hum.Died:Connect(function()
		task.wait(1)

		local newModel = model:Clone()
		newModel.Parent = Workspace
		newModel:PivotTo(npcData.OriginalCFrame)

		for i, v in ipairs(npcs) do
			if v.Model == model then
				table.remove(npcs, i)
				break
			end
		end

		local newData = self:SetupNPC(newModel)
		if newData then
			table.insert(npcs, newData)
		end

		model:Destroy()
	end)

	return npcData
end

function NPCService:UpdateNPCs()
	for _, npcData in ipairs(npcs) do
		if not npcData.Model.Parent or npcData.Humanoid.Health <= 0 then
			continue
		end

		if npcData.IsAttacking then
			continue
		end

		local closestRoot: BasePart? = nil
		local closestDist = math.huge
		local targetCharacter: Model? = nil
		local targetPlayer: Player? = nil

		for _, player in ipairs(Players:GetPlayers()) do
			if self:ShouldChasePlayer(player) then
				local char = player.Character
				if char and char:FindFirstChild("HumanoidRootPart") then
					local dist = (char.HumanoidRootPart.Position - npcData.Root.Position).Magnitude
					if dist < closestDist then
						closestDist = dist
						closestRoot = char.HumanoidRootPart
						targetCharacter = char
						targetPlayer = player
					end
				end
			end
		end

		if closestRoot and targetCharacter and targetPlayer then
			npcData.IsWandering = false
			npcData.Humanoid.WalkSpeed = CONFIG.ChaseSpeed
			npcData.Humanoid:MoveTo(closestRoot.Position)

			-- In range and cooldown passed — trigger attack
			if closestDist <= CONFIG.AttackRange and (tick() - npcData.LastAttack >= CONFIG.AttackCooldown) then
				self:PerformAttack(npcData, targetCharacter, targetPlayer)
				continue -- Skip animation update below since attack is now running
			end
		else
			npcData.Humanoid.WalkSpeed = CONFIG.WalkSpeed
			if tick() - npcData.LastWander > CONFIG.WanderInterval then
				local point = self:GetRandomWanderPoint()
				if point then
					npcData.Humanoid:MoveTo(point)
					npcData.LastWander = tick()
				end
			end
		end

		if not npcData.IsAttacking then
			local speed = npcData.Root.AssemblyLinearVelocity.Magnitude
			self:PlayAnimation(npcData, speed > 1 and "Walk" or "Idle")
		end
	end
end

function NPCService.Client:EnableRagdoll(player: Player)
    local character: Model = player.Character
    if not character or not character:FindFirstChildOfClass("Humanoid") then
        return false
    end

    local canRagdoll: boolean = not RagdollService.IsRagdolled(character:WaitForChild("Humanoid"))

	if canRagdoll then
		local motors = RagdollService.CreateJoints(character)
		RagdollService.Ragdoll(character)
		RagdollService.SetMotorsEnabled(motors, false)

		task.delay(CONFIG.RagdollDuration, function()
			RagdollService.DestroyJoints(character)
			RagdollService.SetMotorsEnabled(motors, true)
			RagdollService.UnRagdoll(character)
		end)
	end

	return canRagdoll
end

return NPCService