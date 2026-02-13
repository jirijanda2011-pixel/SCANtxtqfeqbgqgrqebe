--[[
Server-authoritative targeting + debug skeleton ESP (for your own Roblox game only).
This does NOT teleport bullets or bypass game security.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FireRequest = Instance.new("RemoteEvent")
FireRequest.Name = "FireRequest"
FireRequest.Parent = ReplicatedStorage

local MAX_RANGE = 400
local HIT_RADIUS = 2.5
local FIRE_COOLDOWN = 0.08

local lastShotAt = {}

local function canFire(player)
    local now = os.clock()
    local last = lastShotAt[player] or 0
    if now - last < FIRE_COOLDOWN then
        return false
    end
    lastShotAt[player] = now
    return true
end

local function getCharacterRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isVisible(fromPos, targetCharacter, shooterCharacter)
    local targetRoot = getCharacterRoot(targetCharacter)
    if not targetRoot then
        return false
    end

    local direction = targetRoot.Position - fromPos
    if direction.Magnitude > MAX_RANGE then
        return false
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {shooterCharacter}
    params.IgnoreWater = true

    local result = Workspace:Raycast(fromPos, direction, params)
    if not result then
        return true
    end

    return result.Instance and result.Instance:IsDescendantOf(targetCharacter)
end

local function findBestTarget(shooter)
    local shooterChar = shooter.Character
    local shooterRoot = getCharacterRoot(shooterChar)
    if not shooterRoot then
        return nil
    end

    local bestTarget, bestDist = nil, math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= shooter and p.Team ~= shooter.Team then
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = getCharacterRoot(char)
            if hum and hum.Health > 0 and root then
                local dist = (root.Position - shooterRoot.Position).Magnitude
                if dist < bestDist and dist <= MAX_RANGE and isVisible(shooterRoot.Position, char, shooterChar) then
                    bestTarget = p
                    bestDist = dist
                end
            end
        end
    end

    return bestTarget
end

local function applyDamageIfHit(shooter, target)
    local shooterRoot = getCharacterRoot(shooter.Character)
    local targetChar = target.Character
    local targetRoot = getCharacterRoot(targetChar)
    local hum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
    if not (shooterRoot and targetRoot and hum and hum.Health > 0) then
        return
    end

    local dist = (targetRoot.Position - shooterRoot.Position).Magnitude
    if dist <= MAX_RANGE + HIT_RADIUS and isVisible(shooterRoot.Position, targetChar, shooter.Character) then
        hum:TakeDamage(20)
    end
end

FireRequest.OnServerEvent:Connect(function(player)
    if not canFire(player) then
        return
    end

    local target = findBestTarget(player)
    if target then
        applyDamageIfHit(player, target)
    end
end)

-- Debug skeleton ESP for developers/admins only.
local function makeAdornment(name, part0, part1)
    local a = Instance.new("LineHandleAdornment")
    a.Name = name
    a.Adornee = part0
    a.CFrame = CFrame.new()
    a.Length = (part1.Position - part0.Position).Magnitude
    a.Thickness = 2
    a.Color3 = Color3.fromRGB(0, 255, 170)
    a.AlwaysOnTop = true
    a.ZIndex = 10
    a.Parent = part0
    return a
end

local skeletonPairs = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local function attachSkeletonEsp(character)
    local container = Instance.new("Folder")
    container.Name = "DebugSkeletonESP"
    container.Parent = character

    for _, pair in ipairs(skeletonPairs) do
        local p0 = character:FindFirstChild(pair[1])
        local p1 = character:FindFirstChild(pair[2])
        if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
            local line = makeAdornment(pair[1] .. "_to_" .. pair[2], p0, p1)
            line.Parent = container
        end
    end

    local hb
    hb = RunService.Heartbeat:Connect(function()
        if not character.Parent then
            if hb then hb:Disconnect() end
            return
        end

        for _, line in ipairs(container:GetChildren()) do
            if line:IsA("LineHandleAdornment") then
                local names = string.split(line.Name, "_to_")
                local from = character:FindFirstChild(names[1])
                local to = character:FindFirstChild(names[2])
                if from and to then
                    line.Adornee = from
                    line.Length = (to.Position - from.Position).Magnitude
                end
            end
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        -- Toggle this based on your own admin checks.
        attachSkeletonEsp(character)
    end)
end)
