-- Rivals Full Script
-- Ragebot + AntiCheat Bypass + ESP + Wallbang + Rapid Fire
-- loadstring용

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

-------------------------------------------------
-- 설정
-------------------------------------------------
local Settings = {
    -- 메인
    Enabled = true,
    ToggleKey = Enum.KeyCode.X,

    -- 레이지봇
    Ragebot = true,
    FOV = 180,
    TeamCheck = true,
    VisibleCheck = false,
    SilentAim = true,
    AutoFire = true,

    -- 빠른 사격
    RapidFire = true,
    FireDelay = 0.008,          -- 낮을수록 더 빨리 쏨 (0.008 ~ 0.015 추천)

    -- 월뱅
    Wallbang = true,

    -- ESP
    ESP = true,
    BoxESP = true,
    NameESP = true,
    HealthESP = true,
    TracerESP = true,
    DistanceESP = true,
    ESPColor = Color3.fromRGB(255, 50, 50),
    TeamColor = Color3.fromRGB(50, 255, 50),
}

-------------------------------------------------
-- 안티치트 우회
-------------------------------------------------
local oldGetConnections = getconnections
if oldGetConnections then
    getconnections = function(signal)
        local cons = oldGetConnections(signal)
        for i = #cons, 1, -1 do
            local func = cons[i].Function
            if func then
                local info = debug.getinfo(func)
                if info and info.source then
                    local src = info.source:lower()
                    if string.find(src, "anti") or string.find(src, "detect") or string.find(src, "check") or string.find(src, "ban") then
                        pcall(function() cons[i]:Disable() end)
                    end
                end
            end
        end
        return cons
    end
end

local MT = getrawmetatable(game)
setreadonly(MT, false)

local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    -- 감지 패킷 차단
    if method == "FireServer" or method == "InvokeServer" then
        local name = tostring(self.Name):lower()
        if string.find(name, "detect") or string.find(name, "anticheat") or string.find(name, "ban") 
        or string.find(name, "kick") or string.find(name, "report") or string.find(name, "flag") 
        or string.find(name, "security") or string.find(name, "cheat") then
            return
        end
    end

    -- 월뱅
    if Settings.Enabled and Settings.Wallbang and method == "Raycast" and not checkcaller() then
        if typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
            local params = args[3]
            if params and typeof(params) == "RaycastParams" then
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {LocalPlayer.Character}
                params.IgnoreWater = true
            end
        end
    end

    return OldNamecall(self, ...)
end))

local OldIndex
OldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if checkcaller() then return OldIndex(self, key) end
    if key == "WalkSpeed" or key == "JumpPower" or key == "HipHeight" then
        local char = LocalPlayer.Character
        if char and self:IsDescendantOf(char) then
            if key == "WalkSpeed" then return 16 end
            if key == "JumpPower" then return 50 end
            if key == "HipHeight" then return 2 end
        end
    end
    return OldIndex(self, key)
end))

-------------------------------------------------
-- ESP
-------------------------------------------------
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "Rivals_" .. math.random(100000, 999999)
ESPFolder.Parent = CoreGui

local function CreateESP(player)
    if player == LocalPlayer then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "E" .. player.UserId
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3.2, 0)
    billboard.Parent = ESPFolder

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0, 18)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.TextStrokeTransparency = 0.4
    nameLabel.Parent = billboard

    local healthLabel = Instance.new("TextLabel")
    healthLabel.BackgroundTransparency = 1
    healthLabel.Size = UDim2.new(1, 0, 0, 15)
    healthLabel.Position = UDim2.new(0, 0, 0, 17)
    healthLabel.Font = Enum.Font.Gotham
    healthLabel.TextSize = 12
    healthLabel.TextStrokeTransparency = 0.4
    healthLabel.Parent = billboard

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Size = UDim2.new(1, 0, 0, 15)
    distanceLabel.Position = UDim2.new(0, 0, 0, 31)
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.TextSize = 12
    distanceLabel.TextStrokeTransparency = 0.4
    distanceLabel.Parent = billboard

    local box = Drawing.new("Square")
    box.Visible = false
    box.Thickness = 1
    box.Filled = false

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = 1

    return {
        Billboard = billboard,
        Name = nameLabel,
        Health = healthLabel,
        Distance = distanceLabel,
        Box = box,
        Tracer = tracer
    }
end

local ESPObjects = {}

local function AddPlayer(p)
    if not ESPObjects[p] then ESPObjects[p] = CreateESP(p) end
end
local function RemovePlayer(p)
    local e = ESPObjects[p]
    if e then
        if e.Billboard then e.Billboard:Destroy() end
        if e.Box then e.Box:Remove() end
        if e.Tracer then e.Tracer:Remove() end
        ESPObjects[p] = nil
    end
end

for _, p in pairs(Players:GetPlayers()) do AddPlayer(p) end
Players.PlayerAdded:Connect(AddPlayer)
Players.PlayerRemoving:Connect(RemovePlayer)

-------------------------------------------------
-- 레이지봇 타겟
-------------------------------------------------
local function GetClosestEnemy()
    local closest, shortest = nil, Settings.FOV
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    local myTeam = LocalPlayer.Team

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if Settings.TeamCheck and player.Team == myTeam then continue end
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local head = char:FindFirstChild("Head")
            if hum and hum.Health > 0 and head then
                local pos = Camera:WorldToViewportPoint(head.Position)
                local dist = (Vector2.new(pos.X, pos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                if dist < shortest then
                    shortest = dist
                    closest = head
                end
            end
        end
    end
    return closest
end

-------------------------------------------------
-- 메인 루프
-------------------------------------------------
local lastFire = 0

RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then
        for _, e in pairs(ESPObjects) do
            if e.Box then e.Box.Visible = false end
            if e.Tracer then e.Tracer.Visible = false end
            if e.Billboard then e.Billboard.Enabled = false end
        end
        return
    end

    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    -- ESP
    if Settings.ESP then
        for player, esp in pairs(ESPObjects) do
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")

            if hum and hum.Health > 0 and root and head then
                local isTeam = Settings.TeamCheck and player.Team == LocalPlayer.Team
                local color = isTeam and Settings.TeamColor or Settings.ESPColor

                esp.Billboard.Adornee = head
                esp.Billboard.Enabled = true

                esp.Name.Text = Settings.NameESP and player.Name or ""
                esp.Name.TextColor3 = color

                if Settings.HealthESP then
                    local hp = math.floor(hum.Health)
                    local max = math.floor(hum.MaxHealth)
                    esp.Health.Text = hp .. " / " .. max
                    esp.Health.TextColor3 = Color3.fromRGB(255 - (hp/max*255), hp/max*255, 0)
                else
                    esp.Health.Text = ""
                end

                if Settings.DistanceESP and myRoot then
                    esp.Distance.Text = math.floor((root.Position - myRoot.Position).Magnitude) .. "m"
                else
                    esp.Distance.Text = ""
                end

                if Settings.BoxESP then
                    local top = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local bottom = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                    local h = math.abs(top.Y - bottom.Y)
                    esp.Box.Size = Vector2.new(h/2, h)
                    esp.Box.Position = Vector2.new(top.X - h/4, top.Y)
                    esp.Box.Color = color
                    esp.Box.Visible = top.Z > 0
                else
                    esp.Box.Visible = false
                end

                if Settings.TracerESP then
                    local sp, on = Camera:WorldToViewportPoint(root.Position)
                    if on then
                        esp.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                        esp.Tracer.To = Vector2.new(sp.X, sp.Y)
                        esp.Tracer.Color = color
                        esp.Tracer.Visible = true
                    else
                        esp.Tracer.Visible = false
                    end
                else
                    esp.Tracer.Visible = false
                end
            else
                esp.Billboard.Enabled = false
                esp.Box.Visible = false
                esp.Tracer.Visible = false
            end
        end
    end

    -- 레이지봇 + 빠른 사격
    if Settings.Ragebot then
        local target = GetClosestEnemy()
        if target then
            if Settings.SilentAim then
                local sp = Camera:WorldToViewportPoint(target.Position)
                mousemoverel(sp.X - Camera.ViewportSize.X/2, sp.Y - Camera.ViewportSize.Y/2)
            else
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
            end

            if Settings.AutoFire then
                local now = tick()
                local delay = Settings.RapidFire and Settings.FireDelay or 0.05
                if now - lastFire >= delay then
                    mouse1press()
                    task.wait(0.003)
                    mouse1release()
                    lastFire = now
                end
            end
        end
    end
end)

-------------------------------------------------
-- 토글
-------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Settings.ToggleKey then
        Settings.Enabled = not Settings.Enabled
        print("[Rivals] " .. (Settings.Enabled and "ON" or "OFF"))
    end
end)

print("[Rivals] 풀세트 로드 완료")
print("기능: 레이지봇 | 안티치트우회 | ESP | 월뱅 | 빠른사격")
print("X키로 전체 켜고 끄기")
