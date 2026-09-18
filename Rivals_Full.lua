-- Rivals Full + UI (Fixed for Delta)
-- Ragebot + AntiCheat Bypass + ESP + Wallbang + Rapid Fire

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
    Enabled = true,
    ToggleKey = Enum.KeyCode.Insert,

    Ragebot = true,
    FOV = 200,
    TeamCheck = true,
    VisibleCheck = false,
    SilentAim = true,
    AutoFire = true,

    RapidFire = true,
    FireDelay = 0.01,

    Wallbang = true,

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
pcall(function()
    local oldGetConnections = getconnections
    if oldGetConnections then
        getconnections = function(signal)
            local cons = oldGetConnections(signal)
            for i = #cons, 1, -1 do
                local success, func = pcall(function() return cons[i].Function end)
                if success and func then
                    local info = debug.getinfo(func)
                    if info and info.source then
                        local src = tostring(info.source):lower()
                        if string.find(src, "anti") or string.find(src, "detect") or string.find(src, "check") or string.find(src, "ban") then
                            pcall(function() cons[i]:Disable() end)
                        end
                    end
                end
            end
            return cons
        end
    end
end)

pcall(function()
    local MT = getrawmetatable(game)
    setreadonly(MT, false)

    local OldNamecall
    OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "FireServer" or method == "InvokeServer" then
            local name = tostring(self.Name):lower()
            if string.find(name, "detect") or string.find(name, "anticheat") or string.find(name, "ban")
            or string.find(name, "kick") or string.find(name, "report") or string.find(name, "flag")
            or string.find(name, "security") or string.find(name, "cheat") then
                return
            end
        end

        if Settings.Enabled and Settings.Wallbang and method == "Raycast" and not checkcaller() then
            if typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
                local params = args[3]
                if params and typeof(params) == "RaycastParams" then
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    local filter = {LocalPlayer.Character}
                    if workspace:FindFirstChild("Map") then
                        table.insert(filter, workspace.Map)
                    end
                    params.FilterDescendantsInstances = filter
                    params.IgnoreWater = true
                end
            end
        end

        return OldNamecall(self, ...)
    end))
end)

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
    box.Thickness = 1.5
    box.Filled = false

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = 1.5

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
        if e.Box then pcall(function() e.Box:Remove() end) end
        if e.Tracer then pcall(function() e.Tracer:Remove() end) end
        ESPObjects[p] = nil
    end
end

for _, p in pairs(Players:GetPlayers()) do AddPlayer(p) end
Players.PlayerAdded:Connect(AddPlayer)
Players.PlayerRemoving:Connect(RemovePlayer)

-------------------------------------------------
-- 개선된 타겟 찾기
-------------------------------------------------
local function GetClosestEnemy()
    local closest = nil
    local shortest = Settings.FOV
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local myTeam = LocalPlayer.Team
    local camPos = Camera.CFrame.Position

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if Settings.TeamCheck and player.Team and player.Team == myTeam then
                continue
            end

            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local head = char:FindFirstChild("Head")
            local root = char:FindFirstChild("HumanoidRootPart")

            if hum and hum.Health > 0 and head and root then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)

                if screenPos.Z > 0 then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude

                    if dist < shortest then
                        if Settings.VisibleCheck then
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = {myChar, char}
                            local result = workspace:Raycast(camPos, (head.Position - camPos).Unit * 500, rayParams)
                            if result and result.Instance and not result.Instance:IsDescendantOf(char) then
                                continue
                            end
                        end

                        shortest = dist
                        closest = head
                    end
                end
            end
        end
    end
    return closest
end

-------------------------------------------------
-- UI
-------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RivalsUI_" .. math.random(1000,9999)
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 420, 0, 340)
Main.Position = UDim2.new(0.5, -210, 0.5, -170)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 6)
Corner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(60, 60, 70)
Stroke.Thickness = 1
Stroke.Parent = Main

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 6)
TitleCorner.Parent = TitleBar

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 10)
TitleFix.Position = UDim2.new(0, 0, 1, -10)
TitleFix.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Rivals | Fixed"
Title.TextColor3 = Color3.fromRGB(220, 220, 230)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -32, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.Parent = TitleBar

CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
end)

local TabFrame = Instance.new("Frame")
TabFrame.Size = UDim2.new(1, 0, 0, 30)
TabFrame.Position = UDim2.new(0, 0, 0, 32)
TabFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
TabFrame.BorderSizePixel = 0
TabFrame.Parent = Main

local TabButtons = {}
local Pages = {}

local function CreateTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 1, 0)
    btn.Position = UDim2.new(0, (order-1)*100, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(160, 160, 170)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Parent = TabFrame

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -20, 1, -70)
    page.Position = UDim2.new(0, 10, 0, 68)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new(0, 0, 0, 280)
    page.Visible = false
    page.Parent = Main

    TabButtons[name] = btn
    Pages[name] = page

    btn.MouseButton1Click:Connect(function()
        for n, p in pairs(Pages) do
            p.Visible = (n == name)
            TabButtons[n].TextColor3 = (n == name) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 170)
            TabButtons[n].BackgroundColor3 = (n == name) and Color3.fromRGB(30, 30, 36) or Color3.fromRGB(22, 22, 26)
        end
    end)

    return page
end

local CombatPage = CreateTab("Combat", 1)
local VisualsPage = CreateTab("Visuals", 2)
local MiscPage = CreateTab("Misc", 3)

Pages["Combat"].Visible = true
TabButtons["Combat"].TextColor3 = Color3.fromRGB(255, 255, 255)
TabButtons["Combat"].BackgroundColor3 = Color3.fromRGB(30, 30, 36)

local function CreateToggle(parent, text, default, callback, yPos)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 28)
    frame.Position = UDim2.new(0, 0, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 40, 0, 20)
    toggle.Position = UDim2.new(1, -40, 0.5, -10)
    toggle.BackgroundColor3 = default and Color3.fromRGB(80, 160, 80) or Color3.fromRGB(50, 50, 55)
    toggle.Text = ""
    toggle.Parent = frame

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 10)
    toggleCorner.Parent = toggle

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 16, 0, 16)
    circle.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    circle.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    circle.Parent = toggle

    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = circle

    local state = default
    toggle.MouseButton1Click:Connect(function()
        state = not state
        toggle.BackgroundColor3 = state and Color3.fromRGB(80, 160, 80) or Color3.fromRGB(50, 50, 55)
        circle.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        callback(state)
    end)
end

CreateToggle(CombatPage, "Ragebot", Settings.Ragebot, function(v) Settings.Ragebot = v end, 0)
CreateToggle(CombatPage, "Silent Aim", Settings.SilentAim, function(v) Settings.SilentAim = v end, 32)
CreateToggle(CombatPage, "Auto Fire", Settings.AutoFire, function(v) Settings.AutoFire = v end, 64)
CreateToggle(CombatPage, "Rapid Fire", Settings.RapidFire, function(v) Settings.RapidFire = v end, 96)
CreateToggle(CombatPage, "Wallbang", Settings.Wallbang, function(v) Settings.Wallbang = v end, 128)
CreateToggle(CombatPage, "Team Check", Settings.TeamCheck, function(v) Settings.TeamCheck = v end, 160)
CreateToggle(CombatPage, "Visible Check", Settings.VisibleCheck, function(v) Settings.VisibleCheck = v end, 192)

CreateToggle(VisualsPage, "ESP 전체", Settings.ESP, function(v) Settings.ESP = v end, 0)
CreateToggle(VisualsPage, "Box ESP", Settings.BoxESP, function(v) Settings.BoxESP = v end, 32)
CreateToggle(VisualsPage, "Name ESP", Settings.NameESP, function(v) Settings.NameESP = v end, 64)
CreateToggle(VisualsPage, "Health ESP", Settings.HealthESP, function(v) Settings.HealthESP = v end, 96)
CreateToggle(VisualsPage, "Distance ESP", Settings.DistanceESP, function(v) Settings.DistanceESP = v end, 128)
CreateToggle(VisualsPage, "Tracer ESP", Settings.TracerESP, function(v) Settings.TracerESP = v end, 160)

CreateToggle(MiscPage, "전체 켜기/끄기", Settings.Enabled, function(v) Settings.Enabled = v end, 0)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 80)
info.Position = UDim2.new(0, 0, 0, 40)
info.BackgroundTransparency = 1
info.Text = "Insert 키로 UI 열고 닫기\n드래그로 위치 이동 가능\n\nDelta 기준 최적화됨"
info.TextColor3 = Color3.fromRGB(140, 140, 150)
info.Font = Enum.Font.Gotham
info.TextSize = 12
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.Parent = MiscPage

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

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    if Settings.ESP then
        for player, esp in pairs(ESPObjects) do
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")

            if hum and hum.Health > 0 and root and head then
                local isTeam = Settings.TeamCheck and player.Team and player.Team == LocalPlayer.Team
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
                    local top = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.8, 0))
                    local bottom = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                    if top.Z > 0 then
                        local h = math.abs(top.Y - bottom.Y)
                        local w = h / 1.8
                        esp.Box.Size = Vector2.new(w, h)
                        esp.Box.Position = Vector2.new(top.X - w/2, top.Y)
                        esp.Box.Color = color
                        esp.Box.Visible = true
                    else
                        esp.Box.Visible = false
                    end
                else
                    esp.Box.Visible = false
                end

                if Settings.TracerESP then
                    local sp, onScreen = Camera:WorldToViewportPoint(root.Position)
                    if onScreen and sp.Z > 0 then
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
                if esp.Box then esp.Box.Visible = false end
                if esp.Tracer then esp.Tracer.Visible = false end
            end
        end
    else
        for _, e in pairs(ESPObjects) do
            if e.Billboard then e.Billboard.Enabled = false end
            if e.Box then e.Box.Visible = false end
            if e.Tracer then e.Tracer.Visible = false end
        end
    end

    if Settings.Ragebot then
        local target = GetClosestEnemy()
        if target then
            local targetPos = target.Position

            if Settings.SilentAim then
                local sp, onScreen = Camera:WorldToViewportPoint(targetPos)
                if onScreen then
                    local dx = sp.X - Camera.ViewportSize.X/2
                    local dy = sp.Y - Camera.ViewportSize.Y/2
                    pcall(function()
                        mousemoverel(dx * 0.65, dy * 0.65)
                    end)
                end
                pcall(function()
                    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPos), 0.4)
                end)
            else
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
            end

            if Settings.AutoFire then
                local now = tick()
                local delay = Settings.RapidFire and Settings.FireDelay or 0.06
                if now - lastFire >= delay then
                    pcall(function() mouse1press() end)
                    task.wait(0.004)
                    pcall(function() mouse1release() end)
                    lastFire = now
                end
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Settings.ToggleKey then
        Main.Visible = not Main.Visible
    end
end)

print("[Rivals] Fixed 버전 로드 완료 | Insert 키로 UI")
