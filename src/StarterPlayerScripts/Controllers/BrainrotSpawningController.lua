local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CameraParticles = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("CamParticles"):WaitForChild("Sparkles"):WaitForChild("CameraParticles")

local PARTICLE_DISTANCE = 2
local PARTICLE_DURATION = 3
local PARTICLE_FADE_TIME = 3

local BrainrotSpawningController = Knit.CreateController { Name = "BrainrotSpawningController" }

function BrainrotSpawningController:KnitInit()
end

function BrainrotSpawningController:KnitStart()
    BrainrotSpawningController.BrainrotSpawnService = Knit.GetService("BrainrotSpawnService")

    self.BrainrotSpawnService.OnBrainrotSpawnEvent:Connect(function(_player: Player)
        self:PlayCameraParticles()
    end)
end

-- Calculates the part size needed to fill the viewport at a given depth
local function getViewportCoverSize(camera: Camera, distance: number): Vector3
    local fovY = math.rad(camera.FieldOfView)
    local aspectRatio = camera.ViewportSize.X / camera.ViewportSize.Y
    local height = 2 * distance * math.tan(fovY / 2)
    local width = height * aspectRatio
    return Vector3.new(width, height, 0.01) -- Thin so it doesn't occlude much
end

function BrainrotSpawningController:PlayCameraParticles()
    local camera   = workspace.CurrentCamera
    local part: BasePart = CameraParticles:Clone()
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CastShadow = false
    part.Transparency = 1
    for _, attachment in ipairs(part:GetChildren()) do
        if attachment:IsA("Attachment") then
            for _, emitter in ipairs(attachment:GetChildren()) do
                if emitter:IsA("ParticleEmitter") then
                    emitter.Enabled = true
                end
            end
        end
    end
    part.Parent = workspace

    -- Collect all particle emitters across every attachment
    local emitters: { ParticleEmitter } = {}
    for _, attachment: Attachment in ipairs(part:GetChildren()) do
        if attachment:IsA("Attachment") then
            for _, emitter: ParticleEmitter in ipairs(attachment:GetChildren()) do
                if emitter:IsA("ParticleEmitter") then
                    table.insert(emitters, emitter)
                end
            end
        end
    end

    part.Size = getViewportCoverSize(camera, PARTICLE_DISTANCE)
    part.CFrame = CFrame.new(camera.CFrame.Position + camera.CFrame.LookVector * -PARTICLE_DISTANCE)

    -- Update part every frame: keep it locked in front of the camera
    -- and resize it to always cover the full viewport regardless of FOV / zoom
    local renderConnection: RBXScriptConnection
    renderConnection = RunService.RenderStepped:Connect(function()
        if not part or not part.Parent then
            renderConnection:Disconnect()
            return
        end

        part.Size = getViewportCoverSize(camera, PARTICLE_DISTANCE)
        part.CFrame = camera.CFrame * CFrame.new(0, 0, -PARTICLE_DISTANCE)
    end)

    task.delay(PARTICLE_DURATION, function()
        for _, emitter in ipairs(emitters) do
            if emitter and emitter.Parent then
                emitter.Enabled = false
            end
        end

        task.delay(PARTICLE_FADE_TIME, function()
            renderConnection:Disconnect()
            if part and part.Parent then
                part:Destroy()
            end
        end)
    end)
end

return BrainrotSpawningController