-- Full script with fixed intro

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Player = Players.LocalPlayer

-- INTRO
local introGui = Instance.new("ScreenGui", Player.PlayerGui)
local introImage = Instance.new("ImageLabel", introGui)
introImage.Size = UDim2.new(1,0,1,0)
introImage.BackgroundTransparency = 1
introImage.Image = "rbxassetid://94837141679663" -- replace with your real image asset ID
introImage.ImageTransparency = 0

local introSound = Instance.new("Sound", SoundService)
introSound.SoundId = "rbxassetid://8455439420"
introSound.Volume = 0.8
introSound:Play()

task.delay(2, function()
    introGui:Destroy()
end)

-- Main script
local Config = {
    AutoSteal = true,
    STEAL_RADIUS = 59,
    STEAL_DURATION = 1.3
}

local isStealing = false
local stealStartTime = nil
local progressConnection = nil
local StealData = {}
local Connections = {}

local ProgressBarFill, ProgressLabel, ProgressPercentLabel
local fpsLabel = nil
local fpsUpdateConnection = nil

local DISCORD_TEXT = "Vxiolence"

local function getDiscordProgress(percent)
    local totalChars = #DISCORD_TEXT
    local adjustedPercent = math.min(percent * 1.5, 100)
    local charsToShow = math.floor((adjustedPercent / 100) * totalChars)
    if charsToShow == 0 and percent > 0 then charsToShow = 1 end
    return string.sub(DISCORD_TEXT, 1, charsToShow)
end

local function isMyPlotByName(pn)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(pn)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") then
            return yb.Enabled == true
        end
    end
    return false
end

local function findNearestPrompt()
    local char = Player.Character
    local h = char and char:FindFirstChild("HumanoidRootPart")
    if not h then return nil end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local nearestPrompt, nearestDist, nearestName = nil, math.huge, nil
    for _, plot in ipairs(plots:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if not podiums then continue end
        for _, pod in ipairs(podiums:GetChildren()) do
            pcall(function()
                local base = pod:FindFirstChild("Base")
                local spawn = base and base:FindFirstChild("Spawn")
                if spawn then
                    local dist = (spawn.Position - h.Position).Magnitude
                    if dist < nearestDist and dist <= Config.STEAL_RADIUS then
                        local att = spawn:FindFirstChild("PromptAttachment")
                        if att then
                            for _, ch in ipairs(att:GetChildren()) do
                                if ch:IsA("ProximityPrompt") then
                                    nearestPrompt, nearestDist, nearestName = ch, dist, pod.Name
                                    break
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
    return nearestPrompt, nearestDist, nearestName
end

local function ResetProgressBar()
    if ProgressLabel then ProgressLabel.Text = "READY" end
    if ProgressPercentLabel then ProgressPercentLabel.Text = "" end
    if ProgressBarFill then ProgressBarFill.Size = UDim2.new(0, 0, 1, 0) end
end

local function executeSteal(prompt, name)
    if isStealing then return end
    if not StealData[prompt] then
        StealData[prompt] = {hold = {}, trigger = {}, ready = true}
        pcall(function()
            if getconnections then
                for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                    if c.Function then table.insert(StealData[prompt].hold, c.Function) end
                end
                for _, c in ipairs(getconnections(prompt.Triggered)) do
                    if c.Function then table.insert(StealData[prompt].trigger, c.Function) end
                end
            end
        end)
    end
    local data = StealData[prompt]
    if not data.ready then return end
    data.ready = false
    isStealing = true
    stealStartTime = tick()
    if ProgressLabel then ProgressLabel.Text = name or "STEALING..." end
    if progressConnection then progressConnection:Disconnect() end
    progressConnection = RunService.Heartbeat:Connect(function()
        if not isStealing then progressConnection:Disconnect() return end
        local prog = math.clamp((tick() - stealStartTime) / Config.STEAL_DURATION, 0, 1)
        if ProgressBarFill then ProgressBarFill.Size = UDim2.new(prog, 0, 1, 0) end
        if ProgressPercentLabel then 
            local percent = math.floor(prog * 100)
            ProgressPercentLabel.Text = getDiscordProgress(percent)
        end
    end)
    task.spawn(function()
        for _, f in ipairs(data.hold) do task.spawn(f) end
        task.wait(Config.STEAL_DURATION)
        for _, f in ipairs(data.trigger) do task.spawn(f) end
        if progressConnection then progressConnection:Disconnect() end
        ResetProgressBar()
        data.ready = true
        isStealing = false
    end)
end

local function startAutoSteal()
    if Connections.autoSteal then return end
    Connections.autoSteal = RunService.Heartbeat:Connect(function()
        if not Config.AutoSteal or isStealing then return end
        local prompt, _, name = findNearestPrompt()
        if prompt then executeSteal(prompt, name) end
    end)
end

local function stopAutoSteal()
    if Connections.autoSteal then
        Connections.autoSteal:Disconnect()
        Connections.autoSteal = nil
    end
    isStealing = false
    ResetProgressBar()
end

local function startFPS()
    local frameCount = 0
    local lastTime = tick()
    fpsUpdateConnection = RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local currentTime = tick()
        local delta = currentTime - lastTime
        if delta >= 0.5 then
            local fps = math.floor(frameCount / delta)
            frameCount = 0
            lastTime = currentTime
            if fpsLabel then
                local color = fps >= 60 and Color3.fromRGB(0, 255, 100) or (fps >= 30 and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(255, 50, 50))
                fpsLabel.Text = "FPS: " .. fps
                fpsLabel.TextColor3 = color
            end
        end
    end)
end

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local guiScale = isMobile and 0.55 or 0.85

local Colors = {
    bg = Color3.fromRGB(0, 0, 0),
    border = Color3.fromRGB(255, 255, 255),
    red = Color3.fromRGB(255, 40, 40),
    text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(200, 200, 200)
}

local sg = Instance.new("ScreenGui")
sg.Name = "ALV"
sg.ResetOnSpawn = false
sg.Parent = Player.PlayerGui
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function playClickSound()
    pcall(function()
        local s = Instance.new("Sound", SoundService)
        s.SoundId = "rbxassetid://6895079813"
        s.Volume = 0.25
        s:Play()
        game:GetService("Debris"):AddItem(s, 1)
    end)
end

local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 280 * guiScale, 0, 130 * guiScale)
main.Position = UDim2.new(1, -295 * guiScale, 0, 10 * guiScale)
main.BackgroundColor3 = Colors.bg
main.BackgroundTransparency = 0.4
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.ClipsDescendants = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12 * guiScale)

local mainStroke = Instance.new("UIStroke", main)
mainStroke.Thickness = 2
mainStroke.Color = Colors.border

local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, 0, 0, 38 * guiScale)
header.BackgroundTransparency = 1

local titleLabel = Instance.new("TextLabel", header)
titleLabel.Size = UDim2.new(0.65, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 12 * guiScale, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "ESEW"
titleLabel.TextColor3 = Colors.text
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 14 * guiScale
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

fpsLabel = Instance.new("TextLabel", header)
fpsLabel.Size = UDim2.new(0, 60 * guiScale, 1, 0)
fpsLabel.Position = UDim2.new(0.65, 0, 0, 0)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "FPS: --"
fpsLabel.TextColor3 = Colors.textDim
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 11 * guiScale
fpsLabel.TextXAlignment = Enum.TextXAlignment.Right

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0, 26 * guiScale, 0, 26 * guiScale)
closeBtn.Position = UDim2.new(1, -30 * guiScale, 0.5, -13 * guiScale)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Colors.textDim
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14 * guiScale
closeBtn.MouseButton1Click:Connect(function() 
    playClickSound()
    sg:Destroy() 
    if fpsUpdateConnection then fpsUpdateConnection:Disconnect() end
end)

local separator = Instance.new("Frame", main)
separator.Size = UDim2.new(0.9, 0, 0, 1)
separator.Position = UDim2.new(0.05, 0, 0, 38 * guiScale)
separator.BackgroundColor3 = Colors.border
separator.BackgroundTransparency = 0.5

local toggleRow = Instance.new("Frame", main)
toggleRow.Size = UDim2.new(1, -20 * guiScale, 0, 42 * guiScale)
toggleRow.Position = UDim2.new(0, 10 * guiScale, 0, 46 * guiScale)
toggleRow.BackgroundTransparency = 1

local toggleLabel = Instance.new("TextLabel", toggleRow)
toggleLabel.Size = UDim2.new(0.55, 0, 1, 0)
toggleLabel.Position = UDim2.new(0, 8 * guiScale, 0, 0)
toggleLabel.BackgroundTransparency = 1
toggleLabel.Text = "AGARRE"
toggleLabel.TextColor3 = Colors.text
toggleLabel.Font = Enum.Font.GothamBold
toggleLabel.TextSize = 14 * guiScale
toggleLabel.TextXAlignment = Enum.TextXAlignment.Left

local toggleBg = Instance.new("Frame", toggleRow)
toggleBg.Size = UDim2.new(0, 48 * guiScale, 0, 24 * guiScale)
toggleBg.Position = UDim2.new(1, -56 * guiScale, 0.5, -12 * guiScale)
toggleBg.BackgroundColor3 = Colors.red
Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1, 0)

local toggleCircle = Instance.new("Frame", toggleBg)
toggleCircle.Size = UDim2.new(0, 19 * guiScale, 0, 19 * guiScale)
toggleCircle.Position = UDim2.new(1, -21 * guiScale, 0.5, -9.5 * guiScale)
toggleCircle.BackgroundColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", toggleCircle).CornerRadius = UDim.new(1, 0)

local toggleBtn = Instance.new("TextButton", toggleRow)
toggleBtn.Size = UDim2.new(1, 0, 1, 0)
toggleBtn.BackgroundTransparency = 1
toggleBtn.Text = ""

local autoStealOn = true
toggleBtn.MouseButton1Click:Connect(function()
    playClickSound()
    autoStealOn = not autoStealOn
    Config.AutoSteal = autoStealOn
    TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = autoStealOn and Colors.red or Color3.fromRGB(30, 30, 30)}):Play()
    TweenService:Create(toggleCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position = autoStealOn and UDim2.new(1, -21 * guiScale, 0.5, -9.5 * guiScale) or UDim2.new(0, 3 * guiScale, 0.5, -9.5 * guiScale)}):Play()
    if autoStealOn then startAutoSteal() else stopAutoSteal() end
end)

local infoRow = Instance.new("Frame", main)
infoRow.Size = UDim2.new(1, -20 * guiScale, 0, 28 * guiScale)
infoRow.Position = UDim2.new(0, 10 * guiScale, 0, 94 * guiScale)
infoRow.BackgroundTransparency = 1

local infoLabel = Instance.new("TextLabel", infoRow)
infoLabel.Size = UDim2.new(1, 0, 1, 0)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "ESE MORRO CHAT"
infoLabel.TextColor3 = Colors.red
infoLabel.Font = Enum.Font.GothamBold
infoLabel.TextSize = 11 * guiScale
infoLabel.TextXAlignment = Enum.TextXAlignment.Center

local progressContainer = Instance.new("Frame", sg)
progressContainer.Size = UDim2.new(0, 380 * guiScale, 0, 52 * guiScale)
progressContainer.Position = UDim2.new(0.5, -190 * guiScale, 1, -65 * guiScale)
progressContainer.BackgroundColor3 = Colors.bg
progressContainer.BackgroundTransparency = 0.4
progressContainer.Active = true
progressContainer.Draggable = true
progressContainer.ClipsDescendants = true
Instance.new("UICorner", progressContainer).CornerRadius = UDim.new(0, 10 * guiScale)

local progStroke = Instance.new("UIStroke", progressContainer)
progStroke.Thickness = 2
progStroke.Color = Colors.border

ProgressLabel = Instance.new("TextLabel", progressContainer)
ProgressLabel.Size = UDim2.new(0.35, 0, 0.5, 0)
ProgressLabel.Position = UDim2.new(0, 12 * guiScale, 0, 0)
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Text = "READY"
ProgressLabel.TextColor3 = Colors.text
ProgressLabel.Font = Enum.Font.GothamBold
ProgressLabel.TextSize = 12 * guiScale
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left

ProgressPercentLabel = Instance.new("TextLabel", progressContainer)
ProgressPercentLabel.Size = UDim2.new(0.6, 0, 0.5, 0)
ProgressPercentLabel.Position = UDim2.new(0.35, 0, 0, 0)
ProgressPercentLabel.BackgroundTransparency = 1
ProgressPercentLabel.Text = ""
ProgressPercentLabel.TextColor3 = Colors.red
ProgressPercentLabel.Font = Enum.Font.GothamBlack
ProgressPercentLabel.TextSize = 14 * guiScale
ProgressPercentLabel.TextXAlignment = Enum.TextXAlignment.Center

local progTrack = Instance.new("Frame", progressContainer)
progTrack.Size = UDim2.new(0.96, 0, 0, 6 * guiScale)
progTrack.Position = UDim2.new(0.02, 0, 1, -12 * guiScale)
progTrack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Instance.new("UICorner", progTrack).CornerRadius = UDim.new(1, 0)

ProgressBarFill = Instance.new("Frame", progTrack)
ProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
ProgressBarFill.BackgroundColor3 = Colors.red
Instance.new("UICorner", ProgressBarFill).CornerRadius = UDim.new(1, 0)

local progClose = Instance.new("TextButton", progressContainer)
progClose.Size = UDim2.new(0, 22 * guiScale, 0, 22 * guiScale)
progClose.Position = UDim2.new(1, -28 * guiScale, 0.5, -11 * guiScale)
progClose.BackgroundTransparency = 1
progClose.Text = "✕"
progClose.TextColor3 = Colors.textDim
progClose.Font = Enum.Font.GothamBold
progClose.TextSize = 12 * guiScale
progClose.MouseButton1Click:Connect(function() 
    playClickSound()
    sg:Destroy()
    if fpsUpdateConnection then fpsUpdateConnection:Disconnect() end
end)

startFPS()
startAutoSteal()
