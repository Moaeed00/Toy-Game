local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "Rainbow"
local RAINBOW_PERIOD = 6
local UPDATE_HZ = 20
local UPDATE_DT = 1 / UPDATE_HZ

local trackedSAs: {[Instance]: boolean} = {}
local connsByRoot: {[Instance]: {RBXScriptConnection}} = {}

local function isMesh(inst: Instance)
	return inst:IsA("MeshPart") or inst:IsA("SkinnedMeshPart")
end

local function ensureSA(mesh: Instance): SurfaceAppearance
	local sa = mesh:FindFirstChildOfClass("SurfaceAppearance")
	if not sa then
		sa = Instance.new("SurfaceAppearance")
		sa.Name = "AutoRainbowSA"
		sa.Parent = mesh
	end
	return sa
end

local function trackSA(sa: SurfaceAppearance)
	trackedSAs[sa] = true
	if not connsByRoot[sa] then connsByRoot[sa] = {} end
	table.insert(connsByRoot[sa], sa.AncestryChanged:Connect(function(_, parent)
		if not parent then
			trackedSAs[sa] = nil
			for _, c in ipairs(connsByRoot[sa]) do pcall(function() c:Disconnect() end) end
			connsByRoot[sa] = nil
		end
	end))
end

local function addMesh(mesh: Instance)
	if not isMesh(mesh) then return end
	local sa = ensureSA(mesh)
	trackSA(sa)
end

local function startForModel(model: Model)
	for _, inst in ipairs(model:GetDescendants()) do
		if isMesh(inst) then addMesh(inst) end
	end
	if not connsByRoot[model] then connsByRoot[model] = {} end
	table.insert(connsByRoot[model], model.DescendantAdded:Connect(function(inst)
		if isMesh(inst) then addMesh(inst) end
	end))
	table.insert(connsByRoot[model], model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			for _, c in ipairs(connsByRoot[model] or {}) do pcall(function() c:Disconnect() end) end
			connsByRoot[model] = nil
		end
	end))
end

local function stopForRoot(root: Instance)
	for _, c in ipairs(connsByRoot[root] or {}) do pcall(function() c:Disconnect() end) end
	connsByRoot[root] = nil
	if root:IsA("SurfaceAppearance") then
		trackedSAs[root] = nil
	end
end

for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
	if inst:IsA("Model") then
		startForModel(inst)
	elseif isMesh(inst) then
		addMesh(inst)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
	if inst:IsA("Model") then
		startForModel(inst)
	elseif isMesh(inst) then
		addMesh(inst)
	end
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
	stopForRoot(inst)
end)

task.spawn(function()
	local acc = 0
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < UPDATE_DT then return end
		t += acc
		acc = 0
		local h = (t / RAINBOW_PERIOD) % 1
		local tint = Color3.fromHSV(h, 1, 1)
		for sa in pairs(trackedSAs) do
			if sa.Parent then
				sa.Color = tint
			else
				trackedSAs[sa] = nil
			end
		end
	end)
end)
