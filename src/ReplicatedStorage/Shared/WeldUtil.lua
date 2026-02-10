--!strict

--// WeldUtil.lua
--// Small helper for creating/removing Welds in a consistent way.

local WeldUtil = {}

--// [FUNCTION] Creates a Weld (supports offset via C0)
function WeldUtil.CreateWeld(part0: BasePart, part1: BasePart, c0: CFrame, weldName: string?): Weld
	--// [DEBUG] Print inputs
	print("[WeldUtil.CreateWeld] Creating weld:", part0:GetFullName(), "->", part1:GetFullName())

	--// [IMPORTANT] Create weld instance
	local weld = Instance.new("Weld")
	weld.Name = weldName or "WeldUtil_Weld"

	--// [IMPORTANT] Assign parts
	weld.Part0 = part0
	weld.Part1 = part1

	--// [IMPORTANT] Apply offset
	weld.C0 = c0

	--// [IMPORTANT] Parent weld to Part0 for stability
	weld.Parent = part0

	--// [DEBUG] Confirm weld created
	print("[WeldUtil.CreateWeld] Weld created:", weld:GetFullName())

	return weld
end

--// [FUNCTION] Destroys a weld safely
function WeldUtil.DestroyWeld(weld: Instance?)
	--// [IF] Validate weld
	if not weld then
		--// [DEBUG] Nothing to destroy
		print("[WeldUtil.DestroyWeld] No weld provided (nil).")
		return
	end

	--// [IF] Check instance type
	if not weld:IsA("Weld") then
		--// [DEBUG] Wrong instance type
		print("[WeldUtil.DestroyWeld] Instance is not a Weld:", weld.ClassName, weld:GetFullName())
		return
	end

	--// [DEBUG] Destroying weld
	print("[WeldUtil.DestroyWeld] Destroying weld:", weld:GetFullName())
	weld:Destroy()
end

return WeldUtil
