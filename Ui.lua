--[[
    ========================================================================
    White Studio Games - Single File Version (Auto PitScrap & Recycler)
    ========================================================================
    Features:
    1. Check item count from Player Attribute "scrapCarry"
    2. Auto Scrap ("Loose") & Auto Coins ("Part") inside workspace.PitScrap
    3. Unified Single-Thread Loop: Prevents thread conflict when both toggles are ON
    4. Player Manual Movement Priority: WASD/Joystick instantly pauses auto-movement
    5. Enable Noclip (pass through obstacles) and restore collisions on disable
    6. Walk to front position of "Recycler1" and wait until scrapCarry == 0
    7. Auto Tower: Invoke RemoteFunction TowerStart, intercept Telemetry funnel "towerContinue",
       fire RemoteEvent TowerContinueDecline, and wait 10s before restarting loop.
    ========================================================================
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
-- [2] FEATURE: AUTO SCRAP & AUTO COINS RECYCLER FARM
------------------------------------------------------------------------
local ScrapFarm = {
    Enabled = false,
    CoinsEnabled = false,
    TowerEnabled = false,
    TargetAmount = 10
}

local isLoopRunning = false
local isTowerHooked = false
local lastDeclineTime = 0

local function GetScrapCount()
    local count = LocalPlayer:GetAttribute("scrapCarry")
    if count ~= nil then
        return tonumber(count) or 0
    end
    return 0
end

local function GetClosestTargetItem()
    local character = LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local pitScrap = Workspace:FindFirstChild("PitScrap")
    if not pitScrap then return nil end

    local allowedNames = {}
    if ScrapFarm.Enabled then allowedNames["Loose"] = true end
    if ScrapFarm.CoinsEnabled then allowedNames["Part"] = true end

    local closestItem = nil
    local shortestDistance = math.huge

    for _, item in ipairs(pitScrap:GetChildren()) do
        if allowedNames[item.Name] then
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

local function IsAnyFarmEnabled()
    return ScrapFarm.Enabled or ScrapFarm.CoinsEnabled
end

local function StartFarmLoop()
    if isLoopRunning then return end
    isLoopRunning = true

    Movement.EnableNoclip()

    task.spawn(function()
        while IsAnyFarmEnabled() do
            -----------------------------------------------------------------
            -- 1. Collect Target Items in PitScrap ("Loose" / "Part")
            -----------------------------------------------------------------
            while IsAnyFarmEnabled() and GetScrapCount() < ScrapFarm.TargetAmount do
                local targetItem = GetClosestTargetItem()

                if targetItem then
                    local targetPos = targetItem:IsA("BasePart") and targetItem.Position or targetItem:GetPivot().Position

                    local reached = Movement.WalkTo(targetPos, 15, IsAnyFarmEnabled, 3.5)

                    if not IsAnyFarmEnabled() then break end
                    task.wait(0.2)
                else
                    if GetScrapCount() > 0 then
                        break
                    else
                        task.wait(1)
                    end
                end
            end

            if not IsAnyFarmEnabled() then break end

            -----------------------------------------------------------------
            -- 2. Walk to Recycler1 and sell
            -----------------------------------------------------------------
            if GetScrapCount() > 0 then
                local retryAttempts = 0

                while IsAnyFarmEnabled() and GetScrapCount() > 0 and retryAttempts < 5 do
                    retryAttempts = retryAttempts + 1
                    
                    local recyclerPos = GetRecyclerPosition()

                    if recyclerPos then
                        Movement.WalkTo(recyclerPos, 20, IsAnyFarmEnabled, 4.5)

                        if not IsAnyFarmEnabled() then break end

                        local sellStartTime = tick()
                        
                        while IsAnyFarmEnabled() and GetScrapCount() > 0 and (tick() - sellStartTime) < 4 do
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

        isLoopRunning = false
        Movement.DisableNoclip()
    end)
end

function ScrapFarm.Toggle(state)
    ScrapFarm.Enabled = state
    if state then
        StartFarmLoop()
    elseif not IsAnyFarmEnabled() then
        Movement.DisableNoclip()
    end
end

function ScrapFarm.ToggleCoins(state)
    ScrapFarm.CoinsEnabled = state
    if state then
        StartFarmLoop()
    elseif not IsAnyFarmEnabled() then
        Movement.DisableNoclip()
    end
end

------------------------------------------------------------------------
-- [3] AUTO TOWER FEATURE
------------------------------------------------------------------------
local function FireDeclineRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local declineRemote = remotes:FindFirstChild("TowerContinueDecline")
        if declineRemote and declineRemote:IsA("RemoteEvent") then
            declineRemote:FireServer()
            lastDeclineTime = tick()
        end
    end
end

local function SetupTelemetryHook()
    if isTowerHooked then return end
    isTowerHooked = true

    if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if ScrapFarm.TowerEnabled and (method == "FireServer" or method == "fireServer") then
                if self and self.Name == "Telemetry" then
                    if args[1] == "funnel" and typeof(args[2]) == "table" then
                        if args[2]["funnel"] == "towerContinue" then
                            task.spawn(function()
                                task.wait(0.1)
                                FireDeclineRemote()
                            end)
                        end
                    end
                end
            end

            return oldNamecall(self, ...)
        end)
    end
end

function ScrapFarm.ToggleTower(state)
    ScrapFarm.TowerEnabled = state

    if state then
        SetupTelemetryHook()

        task.spawn(function()
            local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
            if not remotes then return end

            local towerStart = remotes:WaitForChild("TowerStart", 10)

            while ScrapFarm.TowerEnabled do
                lastDeclineTime = 0

                if towerStart then
                    pcall(function()
                        if towerStart:IsA("RemoteFunction") then
                            towerStart:InvokeServer()
                        elseif towerStart:IsA("RemoteEvent") then
                            towerStart:FireServer()
                        end
                    end)
                end

                -- รอจนกว่า TowerContinueDecline จะถูกยิง หรือพ้นระยะเวลา fallback (60 วินาที)
                local waitStart = tick()
                while ScrapFarm.TowerEnabled and lastDeclineTime == 0 do
                    task.wait(0.5)
                    if (tick() - waitStart) > 60 then
                        break
                    end
                end

                -- หากยิง TowerContinueDecline เรียบร้อย ให้รอครบ 10 วินาทีก่อนเริ่มลูปใหม่
                if ScrapFarm.TowerEnabled then
                    if lastDeclineTime > 0 then
                        local timePassed = tick() - lastDeclineTime
                        if timePassed < 10 then
                            task.wait(10 - timePassed)
                        end
                    else
                        task.wait(3)
                    end
                end
            end
        end)
    end
end

------------------------------------------------------------------------
-- [4] UI INITIALIZATION (Fluent Library)
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
    Main        = Window:AddTab({ Title = "Auto Farm", Icon = "box" }),
    AutoUpgrade = Window:AddTab({ Title = "Auto Upgrade", Icon = "arrow-up-circle" }),
    Tower       = Window:AddTab({ Title = "Tower", Icon = "layers" }),
    Settings    = Window:AddTab({ Title = "Settings", Icon = "sliders-horizontal" })
}

-- [1] TAB: Auto Farm
local ScrapToggle = Tabs.Main:AddToggle("AutoScrapToggle", {
    Title = "Auto Scrap & Sell Recycler",
    Description = "Auto farm Scrap and sell at Recycler",
    Default = false
})

ScrapToggle:OnChanged(function(Value)
    ScrapFarm.Toggle(Value)
end)

local CoinsToggle = Tabs.Main:AddToggle("AutoCoinsToggle", {
    Title = "Auto Coins & Sell Recycler",
    Description = "Auto farm Coins and sell at Recycler",
    Default = false
})

CoinsToggle:OnChanged(function(Value)
    ScrapFarm.ToggleCoins(Value)
end)

-- [2] TAB: Auto Upgrade
Tabs.AutoUpgrade:AddParagraph({
    Title = "Auto Upgrade System",
    Content = "Configure auto upgrades for your stats and equipment here."
})

-- [3] TAB: Tower
local TowerToggle = Tabs.Tower:AddToggle("AutoTowerToggle", {
    Title = "Auto Tower",
    Description = "Auto climb and farm Tower",
    Default = false
})

TowerToggle:OnChanged(function(Value)
    ScrapFarm.ToggleTower(Value)
end)

-- [4] TAB: Settings
Tabs.Settings:AddParagraph({
    Title = "GitHub Usage Instructions",
    Content = "After pushing to GitHub, execute using loadstring(game:HttpGet('...'))"
})

Window:SelectTab(1)
