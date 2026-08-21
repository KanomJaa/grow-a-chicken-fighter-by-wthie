--[[
    ========================================================================
    White Studio Games - Single File Version (Auto PitScrap & Recycler)
    ========================================================================
    Features:
    1. Check scrap count from Player Attribute "scrapCarry"
    2. Search "PitScrap" in Workspace -> Find nearest "Loose" item
    3. Player Manual Movement Priority: WASD/Joystick instantly pauses auto-movement
    4. Enable Noclip (pass through obstacles) and restore collisions on disable
    5. Walk to front position of "Recycler1" and wait until scrapCarry == 0
    6. English UI layout with Auto Coins placeholder toggle
    ========================================================================
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------------
-- [1] MOVEMENT UTILS
------------------------------------------------------------------------
local Movement = {}
local NoclipConnection = nil

function Movement.IsPlayerMovingManually()
    local isKeyboard = UserInputService:IsKeyDown(Enum.KeyCode.W) or
                       UserInputService:IsKeyDown(Enum.KeyCode.A) or
                       UserInputService:IsKeyDown(Enum.KeyCode.S) or
                       UserInputService:IsKeyDown(Enum.KeyCode.D) or
                       UserInputService:IsKeyDown(Enum.KeyCode.Up) or
                       UserInputService:IsKeyDown(Enum.KeyCode.Down) or
                       UserInputService:IsKeyDown(Enum.KeyCode.Left) or
                       UserInputService:IsKeyDown(Enum.KeyCode.Right)
    
    if isKeyboard then return true end

    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
            if UserInputService:GetFocusedTextBox() == nil then
                return true
            end
        end
    end

    return false
end

function Movement.EnableNoclip()
    if NoclipConnection then return end
    NoclipConnection = RunService.Stepped:Connect(function()
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

function Movement.DisableNoclip()
    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection = nil
    end

    local character = LocalPlayer.Character
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

function Movement.WalkTo(targetPosition, timeout, shouldContinueCheck, stopDistance)
    timeout = timeout or 15
    stopDistance = stopDistance or 3.5

    local character = LocalPlayer.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return false end
    
    if typeof(targetPosition) == "CFrame" then targetPosition = targetPosition.Position end
    humanoid:MoveTo(targetPosition)
    
    local startTime = tick()
    local reached = false
    local connection
    connection = humanoid.MoveToFinished:Connect(function() reached = true end)
    
    while not reached and (tick() - startTime) < timeout do
        if shouldContinueCheck and not shouldContinueCheck() then
            humanoid:MoveTo(hrp.Position)
            break
        end
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then break end
        
        if Movement.IsPlayerMovingManually() then
            while (shouldContinueCheck == nil or shouldContinueCheck()) and Movement.IsPlayerMovingManually() do
                task.wait(0.1)
            end
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):MoveTo(targetPosition)
            end
        end

        if (hrp.Position - targetPosition).Magnitude <= stopDistance then
            reached = true
            break
        end
        task.wait(0.05)
    end
    if connection then connection:Disconnect() end
    return reached
end

------------------------------------------------------------------------
-- [2] FEATURE: AUTO SCRAP & RECYCLER FARM
------------------------------------------------------------------------
local ScrapFarm = {
    Enabled = false,
    CoinsEnabled = false,
    TargetAmount = 10
}

local function GetScrapCount()
    local count = LocalPlayer:GetAttribute("scrapCarry")
    if count ~= nil then
        return tonumber(count) or 0
    end
    return 0
end

local function GetClosestLoose()
    local character = LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local pitScrap = Workspace:FindFirstChild("PitScrap")
    if not pitScrap then return nil end

    local closestItem = nil
    local shortestDistance = math.huge

    for _, item in ipairs(pitScrap:GetChildren()) do
        if item.Name == "Loose" then
            local itemPos = nil
            if item:IsA("BasePart") then
                itemPos = item.Position
            elseif item:IsA("Model") then
                itemPos = item.PrimaryPart and item.PrimaryPart.Position or item:GetPivot().Position
            end

            if itemPos then
                local distance = (hrp.Position - itemPos).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestItem = item
                end
            end
        end
    end

    return closestItem
end

local function GetRecyclerPosition()
    local recyclers = Workspace:FindFirstChild("Recyclers")
    if not recyclers then return nil end

    local recycler1 = recyclers:FindFirstChild("Recycler1") or recyclers:FindFirstChildWhichIsA("Model") or recyclers:FindFirstChildWhichIsA("BasePart")
    if not recycler1 then return nil end

    local cf = nil
    if recycler1:IsA("Model") then
        cf = recycler1.PrimaryPart and recycler1.PrimaryPart.CFrame or recycler1:GetPivot()
    elseif recycler1:IsA("BasePart") then
        cf = recycler1.CFrame
    end

    if cf then
        local frontPosition = cf.Position + (cf.LookVector * 4.5)
        return frontPosition
    end

    return nil
end

function ScrapFarm.Toggle(state)
    ScrapFarm.Enabled = state

    if state then
        Movement.EnableNoclip()

        task.spawn(function()
            while ScrapFarm.Enabled do
                -----------------------------------------------------------------
                -- 1. Collect Loose in PitScrap
                -----------------------------------------------------------------
                while ScrapFarm.Enabled and GetScrapCount() < ScrapFarm.TargetAmount do
                    local targetLoose = GetClosestLoose()

                    if targetLoose then
                        local targetPos = targetLoose:IsA("BasePart") and targetLoose.Position or targetLoose:GetPivot().Position

                        local reached = Movement.WalkTo(targetPos, 15, function() return ScrapFarm.Enabled end, 3.5)

                        if not ScrapFarm.Enabled then break end
                        task.wait(0.2)
                    else
                        if GetScrapCount() > 0 then
                            break
                        else
                            task.wait(1)
                        end
                    end
                end

                if not ScrapFarm.Enabled then break end

                -----------------------------------------------------------------
                -- 2. Walk to Recycler1 and sell
                -----------------------------------------------------------------
                if GetScrapCount() > 0 then
                    local retryAttempts = 0

                    while ScrapFarm.Enabled and GetScrapCount() > 0 and retryAttempts < 5 do
                        retryAttempts = retryAttempts + 1
                        
                        local recyclerPos = GetRecyclerPosition()

                        if recyclerPos then
                            Movement.WalkTo(recyclerPos, 20, function() return ScrapFarm.Enabled end, 4.5)

                            if not ScrapFarm.Enabled then break end

                            local sellStartTime = tick()
                            
                            while ScrapFarm.Enabled and GetScrapCount() > 0 and (tick() - sellStartTime) < 4 do
                                task.wait(0.3)
                            end

                            if GetScrapCount() == 0 then
                                break
                            else
                                task.wait(0.5)
                            end
                        else
                            task.wait(2)
                        end
                    end
                end

                task.wait(0.5)
            end

            Movement.DisableNoclip()
        end)
    else
        Movement.DisableNoclip()
    end
end

function ScrapFarm.ToggleCoins(state)
    ScrapFarm.CoinsEnabled = state
end

------------------------------------------------------------------------
-- [3] UI INITIALIZATION (Fluent Library)
------------------------------------------------------------------------
local Library = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Library:CreateWindow({
    Title = "White Studio Games",
    SubTitle = "Version 1.0.1",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main     = Window:AddTab({ Title = "Auto Farm", Icon = "box" }),
    Player   = Window:AddTab({ Title = "Player", Icon = "user" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "sliders-horizontal" })
}

Tabs.Main:AddSection("Auto Recycler Farm")

-- Toggle 1: Auto Scrap & Sell Recycler
local ScrapToggle = Tabs.Main:AddToggle("AutoScrapToggle", {
    Title = "Auto Scrap & Sell Recycler",
    Description = "Check scrapCarry -> Collect 10 items -> Sell in front of Recycler1",
    Default = false
})

ScrapToggle:OnChanged(function(Value)
    ScrapFarm.Toggle(Value)
end)

-- Toggle 2: Auto Coins & Sell Recycler
local CoinsToggle = Tabs.Main:AddToggle("AutoCoinsToggle", {
    Title = "Auto Coins & Sell Recycler",
    Description = "Auto farm coins and sell at Recycler",
    Default = false
})

CoinsToggle:OnChanged(function(Value)
    ScrapFarm.ToggleCoins(Value)
end)

-- Player Utilities
Tabs.Player:AddSection("Character Settings")

local SpeedSlider = Tabs.Player:AddSlider("WalkSpeedSlider", {
    Title = "WalkSpeed",
    Description = "Adjust character movement speed",
    Default = 16,
    Min = 16,
    Max = 200,
    Rounding = 0
})

SpeedSlider:OnChanged(function(Value)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Value
    end
end)

-- Settings Tab
Tabs.Settings:AddParagraph({
    Title = "GitHub Usage Instructions",
    Content = "After pushing to GitHub, execute using loadstring(game:HttpGet('...'))"
})

Window:SelectTab(1)
