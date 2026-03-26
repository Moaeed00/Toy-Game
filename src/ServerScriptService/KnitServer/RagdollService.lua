-- RagdollService Module
-- Made by Dev1n @ADRENALXNE

local ServerStorage = game:GetService("ServerStorage")

local RAGDOLL_NAME = 'RagdollConstraint'
local NOCOLLIDE_NAME = 'RagdollNoCollide'

local noCollisionMap = {
	R15 = {
		Head = {'LeftUpperArm', 'LeftUpperLeg', 'LowerTorso', 'RightUpperArm', 'RightUpperLeg'},
		LeftFoot = {'LowerTorso', 'UpperTorso'},
		LeftHand = {'LowerTorso', 'UpperTorso'},
		RightFoot = {'LowerTorso', 'UpperTorso'},
		RightHand = {'LowerTorso', 'UpperTorso'},
		LeftLowerArm = {'LowerTorso', 'UpperTorso'},
		LeftLowerLeg = {'LowerTorso', 'UpperTorso'},
		LeftUpperArm = {'LeftUpperLeg', 'LowerTorso', 'UpperTorso', 'RightUpperArm', 'RightUpperLeg'},
		LeftUpperLeg = {'LowerTorso', 'UpperTorso', 'RightUpperLeg'},
		RightLowerArm = {'LowerTorso', 'UpperTorso'},
		RightLowerLeg = {'LowerTorso', 'UpperTorso'},
		RightUpperArm = {'RightUpperLeg', 'LowerTorso', 'UpperTorso', 'LeftUpperLeg'},
		RightUpperLeg = {'LowerTorso', 'UpperTorso'},
	},

	R6 = {
		Head = {'Left Arm', 'Left Leg', 'Torso', 'Right Arm', 'Right Leg'},
	}
}

local function getMotors(character : Model) : {Motor6D}
	local t : {Motor6D} = {}

	for _,part in character:GetChildren() do
		for _, descendant in part:GetChildren() do
			if descendant:IsA('Motor6D') then
				t[#t + 1] = descendant
			end
		end
	end

	return t
end

-- create NoCollisionConstraints so the character doesn't fling
local function createNoCollisionConstraints(character, rigTypeName)
	for i,subMap in noCollisionMap[rigTypeName] do
		for _,x in subMap do
			local noCollision = Instance.new('NoCollisionConstraint')
			noCollision.Name = NOCOLLIDE_NAME
			noCollision.Part0 = character[i]
			noCollision.Part1 = character[x]
			noCollision.Parent = character

		end
	end
end

-- RagdollService Module
local RagdollService = {}

-- Create joints for ragdoll
function RagdollService.CreateJoints(character : Model) : {Motor6D}
	local Rigs = ServerStorage.CharacterRigs
	if not character:IsA('Model') or not character:FindFirstChildOfClass('Humanoid') then
		return
	end

	local rigType = character.Humanoid.RigType
	local motors = getMotors(character)

	createNoCollisionConstraints(character, rigType.Name)

	for _, motor in motors do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name, a1.Name = RAGDOLL_NAME, RAGDOLL_NAME
		a0.CFrame = motor.C0
		a1.CFrame = motor.C1
		a0.Parent = motor.Part0
		a1.Parent = motor.Part1

		local name = motor.Name:gsub('Right', '')
		name = name:gsub('Left', '')
		name = name:gsub('Joint', '')
		name = name:gsub(' ', '')

		local b = (Rigs:FindFirstChild(name) or Rigs:FindFirstChild(rigType.Name).Default):Clone()
		if not b then
			return
		end

		b.Name = RAGDOLL_NAME
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Parent = motor.Part1
	end

	return motors
end

-- Remove joints for ragdoll
function RagdollService.DestroyJoints(character : Model)
	for _, descendant : Instance in character:GetDescendants() do
		-- Remove BallSockets and NoCollides, leave the additional Attachments
		if (descendant:IsA('Constraint') or descendant:IsA('WeldConstraint') or descendant:IsA('Attachment')) and descendant.Name == RAGDOLL_NAME
			or descendant:IsA("NoCollisionConstraint") and descendant.Name == NOCOLLIDE_NAME
		then
			descendant:Destroy()
		end
	end
end

-- Setup properties for RagdollService
function RagdollService.Ragdoll(character : Model)
	local rootPart: BasePart? = character.PrimaryPart
	local humanoid: Humanoid = character.Humanoid

	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	rootPart.CanCollide = false
	character.Head.CanCollide = true

	-- if not character.PrimaryPart:GetNetworkOwner() then
	-- 	if humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
	-- 		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	-- 	end
	-- end
end

-- Reset properties for ragdoll
function RagdollService.UnRagdoll(character : Model)
	local humanoid: Humanoid = character.Humanoid

	if humanoid.Health > 0 then
		humanoid.WalkSpeed = 16
		humanoid.AutoRotate = true
		character.PrimaryPart.CanCollide = true
		character.Head.CanCollide = false

		-- if not character.PrimaryPart:GetNetworkOwner() then
		-- 	if humanoid:GetState() ~= Enum.HumanoidStateType.GettingUp then
		-- 		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		-- 	end
		-- end
	end
end

-- Set motor-set enabled
function RagdollService.SetMotorsEnabled(motors : {Motor6D}, enabled : boolean)
	for _, motor in motors do
		motor.Enabled = enabled
	end
end

-- Check whether a humanoid is ragdolled or not
function RagdollService.IsRagdolled(humanoid : Humanoid) : boolean
	return humanoid:GetState() == Enum.HumanoidStateType.Physics
end

return RagdollService