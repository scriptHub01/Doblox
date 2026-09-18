-- Rivals Fixed v3
-- Ragebot (Clone + TP) + Wallbang + ESP + Silent Aim + AutoFire FOV

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Settings = {
    Enabled = true,
    ToggleKey = Enum.KeyCode.Insert,

    Ragebot = false,
    FOV = 180,
    TeamCheck = true,
    SilentAim = true,
    AutoFire = true,
    RapidFire = true,
    FireDelay = 0.012,

    Wallbang = false,
    CloneTP = true,          -- 분신 + 텔포 방식

    ESP = true,
    BoxESP = true,
    NameESP = true,
    HealthESP = true,
    TracerESP = true,
    DistanceESP = true,
    ESPColor = Color3.fromRGB(255, 50, 50),
    TeamColor = Color3.fromRGB(50, 255, 50),
}

-- 안티치트 간단 우회
pcall(function()
    local oldGetConnections = getconnections
    if oldGetConnections then
        getconnections = function(signal)
            local cons = oldGetConnections(signal)
            for i = #cons, 1, -1 do
                local ok, func = pcall(function() return cons[i].Function end)
                if ok and func then
                    local info = debug.getinfo(func)
                    if info and info.source then
                        local src = tostring(info.source):lower()
                        if string.find(src, "anti") or string.find(src, "detect") or string.find(src, "ban") then
                            pcall(function() cons[i]:Disable() end)
                        end
                    end
                end
            end
            return cons
        end
    end
end)

-- 월뱅 후킹 (화면 안 멈추게 안전하게)
local oldNamecall
pcall(function()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "FireServer" or method == "InvokeServer" then
            local n = tostring(self.Name):lower()
            if string.find(n, "detect") or string.find(n, "anticheat") or string.find(n, "ban") or string.find(n, "kick") or string.find(n, "flag") then
                return
            end
        end

        -- 월뱅: Raycast 필터만 건드리고 나머지는 그대로 통과
        if Settings.Wallbang and method == "Raycast" and not checkcaller() then
            if typeof(args[3]) == "RaycastParams" then
                args[3].FilterType = Enum.RaycastFilterType.Exclude
                args[3].FilterDescendantsInstances = {LocalPlayer.Character}
                args[3].IgnoreWater = true
            end
        end

        return oldNamecall(self, unpack(args))
    end))
end)

-- ESP
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "RivalsESP_" .. math.random(10000,99999)
ESPFolder.Parent = CoreGui

local ESPObjects = {}

local function CreateESP(player)
    if player == LocalPlayer then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "E" .. player.UserId
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 180, 0, 48)
    bb.StudsOffset = Vector3.new(0, 3.1, 0)
    bb.Parent = ESPFolder

    local nameL = Instance.new("TextLabel")
    nameL.BackgroundTransparency = 1
    nameL.Size = UDim2.new(1, 0, 0, 16)
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 13
    nameL.TextStrokeTransparency = 0.4
    nameL.Parent = bb

    local hpL = Instance.new("TextLabel")
    hpL.BackgroundTransparency = 1
    hpL.Size = UDim2.new(1, 0, 0, 14)
    hpL.Position = UDim2.new(0, 0, 0, 16)
    hpL.Font = Enum.Font.Gotham
    hpL.TextSize = 11
    hpL.TextStrokeTransparency = 0.4
    hpL.Parent = bb

    local distL = Instance.new("TextLabel")
    distL.BackgroundTransparency = 1
    distL.Size = UDim2.new(1, 0, 0, 14)
    distL.Position = UDim2.new(0, 0, 0, 30)
    distL.Font = Enum.Font.Gotham
    distL.TextSize = 11
    distL.TextStrokeTransparency = 0.4
    distL.Parent = bb

    local box = Drawing.new("Square")
    box.Visible = false
    box.Thickness = 1.5
    box.Filled = false

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = 1.5

    return {Billboard = bb, Name = nameL, Health = hpL, Distance = distL, Box = box, Tracer = tracer}
end

local function AddPlayer(p)
    if not ESPObjects[p] then ESPObjects[p] = CreateESP(p) end
end
local function RemovePlayer(p)
    local e = ESPObjects[p]
    if e then
        if e.Billboard then e.Billboard:Destroy() end
        pcall(function() if e.Box then e.Box:Remove() end end)
        pcall(function() if e.Tracer then e.Tracer:Remove() end end)
        ESPObjects[p] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do AddPlayer(p) end
Players.PlayerAdded:Connect(AddPlayer)
Players.PlayerRemoving:Connect(RemovePlayer)

-- 타겟 찾기 (FOV + Z체크)
local function GetClosestEnemy()
    local closest, shortest = nil, Settings.FOV
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myTeam = LocalPlayer.Team

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if Settings.TeamCheck and player.Team and player.Team == myTeam then continue end

            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local head = char:FindFirstChild("Head")
            if hum and hum.Health > 0 and head then
                local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
                if sp.Z > 0 then
                    local dist = (Vector2.new(sp.X, sp.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    if dist < shortest then
                        shortest = dist
                        closest = head
                    end
                end
            end
        end
    end
    return closest, shortest
end

-- 분신 + 텔포 레이지봇
local clone = nil
local lastTP = 0

local function DoCloneTP(targetHead)
    if not Settings.CloneTP then return end
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end

    local now = tick()
    if now - lastTP < 0.15 then return end
    lastTP = now

    -- 상대 머리 위 살짝 위로 텔포
    local targetPos = targetHead.Position + Vector3.new(0, 4.5, 0)
    pcall(function()
        myChar.HumanoidRootPart.CFrame = CFrame.new(targetPos)
    end)
end

-- UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RivalsUI_" .. math.random(1000,9999)
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 400, 0, 360)
Main.Position = UDim2.new(0.5, -200, 0.5, -180)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 6)
local stroke = Instance.new("UIStroke", Main)
stroke.Color = Color3.fromRGB(55, 55, 65)
stroke.Thickness = 1

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 6)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -36, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Rivals | v3 Fixed"
Title.TextColor3 = Color3.fromRGB(220, 220, 230)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = TitleBar
CloseBtn.MouseButton1Click:Connect(function() Main.Visible = false end)

local TabFrame = Instance.new("Frame")
TabFrame.Size = UDim2.new(1, 0, 0, 28)
TabFrame.Position = UDim2.new(0, 0, 0, 30)
TabFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
TabFrame.BorderSizePixel = 0
TabFrame.Parent = Main

local TabButtons, Pages = {}, {}

local function CreateTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 90, 1, 0)
    btn.Position = UDim2.new(0, (order-1)*90, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(150, 150, 160)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Parent = TabFrame

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -16, 1, -66)
    page.Position = UDim2.new(0, 8, 0, 62)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new(0, 0, 0, 300)
    page.Visible = false
    page.Parent = Main

    TabButtons[name] = btn
    Pages[name] = page

    btn.MouseButton1Click:Connect(function()
        for n, p in pairs(Pages) do
            p.Visible = (n == name)
            TabButtons[n].TextColor3 = (n == name) and Color3.fromRGB(255,255,255) or Color3.fromRGB(150,150,160)
            TabButtons[n].BackgroundColor3 = (n == name) and Color3.fromRGB(32,32,38) or Color3.fromRGB(22,22,26)
        end
    end)
    return page
end

local CombatPage = CreateTab("Combat", 1)
local VisualsPage = CreateTab("Visuals", 2)
local MiscPage = CreateTab("Misc", 3)

Pages["Combat"].Visible = true
TabButtons["Combat"].TextColor3 = Color3.fromRGB(255,255,255)
TabButtons["Combat"].BackgroundColor3 = Color3.fromRGB(32,32,38)

local function CreateToggle(parent, text, default, callback, y)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 26)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -46, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 38, 0, 18)
    btn.Position = UDim2.new(1, -38, 0.5, -9)
    btn.BackgroundColor3 = default and Color3.fromRGB(70, 150, 70) or Color3.fromRGB(45, 45, 50)
    btn.Text = ""
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 9)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 14, 0, 14)
    circle.Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    circle.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    circle.Parent = btn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(70, 150, 70) or Color3.fromRGB(45, 45, 50)
        circle.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        callback(state)
    end)
end

CreateToggle(CombatPage, "Ragebot", Settings.Ragebot, function(v) Settings.Ragebot = v end, 0)
CreateToggle(CombatPage, "Clone + TP (머리위)", Settings.CloneTP, function(v) Settings.CloneTP = v end, 28)
CreateToggle(CombatPage, "Silent Aim", Settings.SilentAim, function(v) Settings.SilentAim = v end, 56)
CreateToggle(CombatPage, "Auto Fire (FOV안)", Settings.AutoFire, function(v) Settings.AutoFire = v end, 84)
CreateToggle(CombatPage, "Rapid Fire", Settings.RapidFire, function(v) Settings.RapidFire = v end, 112)
CreateToggle(CombatPage, "Wallbang", Settings.Wallbang, function(v) Settings.Wallbang = v end, 140)
CreateToggle(CombatPage, "Team Check", Settings.TeamCheck, function(v) Settings.TeamCheck = v end, 168)

CreateToggle(VisualsPage, "ESP 전체", Settings.ESP, function(v) Settings.ESP = v end, 0)
CreateToggle(VisualsPage, "Box ESP", Settings.BoxESP, function(v) Settings.BoxESP = v end, 28)
CreateToggle(VisualsPage, "Name ESP", Settings.NameESP, function(v) Settings.NameESP = v end, 56)
CreateToggle(VisualsPage, "Health ESP", Settings.HealthESP, function(v) Settings.HealthESP = v end, 84)
CreateToggle(VisualsPage, "Distance ESP", Settings.DistanceESP, function(v) Settings.DistanceESP = v end, 112)
CreateToggle(VisualsPage, "Tracer ESP", Settings.TracerESP, function(v) Settings.TracerESP = v end, 140)

CreateToggle(MiscPage, "전체 켜기/끄기", Settings.Enabled, function(v) Settings.Enabled = v end, 0)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 70)
info.Position = UDim2.new(0, 0, 0, 36)
info.BackgroundTransparency = 1
info.Text = "Insert = UI 토글\nRagebot + CloneTP = 머리 위 텔포 후 공격\nAutoFire는 FOV 안에 있을 때만 발사"
info.TextColor3 = Color3.fromRGB(130, 130, 140)
info.Font = Enum.Font.Gotham
info.TextSize = 11
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.Parent = MiscPage

-- 메인 루프
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

    -- ESP
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
                    local hp, max = math.floor(hum.Health), math.floor(hum.MaxHealth)
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
                    local top = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.7, 0))
                    local bottom = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.8, 0))
                    if top.Z > 0 then
                        local h = math.abs(top.Y - bottom.Y)
                        local w = h / 1.7
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
                    local sp, on = Camera:WorldToViewportPoint(root.Position)
                    if on and sp.Z > 0 then
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

    -- Combat
    if Settings.Ragebot then
        local target, dist = GetClosestEnemy()
        if target then
            -- Clone + TP
            if Settings.CloneTP then
                DoCloneTP(target)
            end

            -- Silent Aim (부드럽게)
            if Settings.SilentAim then
                local sp, onScreen = Camera:WorldToViewportPoint(target.Position)
                if onScreen then
                    local dx = sp.X - Camera.ViewportSize.X/2
                    local dy = sp.Y - Camera.ViewportSize.Y/2
                    pcall(function()
                        mousemoverel(dx * 0.55, dy * 0.55)
                    end)
                end
                -- 카메라도 살짝 따라가게
                pcall(function()
                    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.Position), 0.25)
                end)
            end

            -- AutoFire → FOV 안에 있을 때만
            if Settings.AutoFire and dist and dist <= Settings.FOV then
                local now = tick()
                local delay = Settings.RapidFire and Settings.FireDelay or 0.07
                if now - lastFire >= delay then
                    pcall(function() mouse1press() end)
                    task.wait(0.003)
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

print("[Rivals] v3 Fixed | Insert = UI")
