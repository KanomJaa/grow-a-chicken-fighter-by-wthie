--[[
    ========================================================================
    White Studio Games - Single File Version (Auto PitScrap, Recycler & Tower)
    ========================================================================
    Features:
    1. Check item count from Player Attribute "scrapCarry"
    2. Auto Scrap ("Loose") & Auto Coins ("Part") inside workspace.PitScrap
    3. Unified Single-Thread Loop: Prevents thread conflict when both toggles are ON
    4. Player Manual Movement Priority: WASD/Joystick instantly pauses auto-movement
    5. Enable Noclip (pass through obstacles) and restore collisions on disable
    6. Auto Tower Loop (Fixed Floor 1 Bug & Capability Error):
       - Read current floor from LocalPlayer.leaderstats.Tower.Value
       - Invoke Remote TowerElevator(currentFloor) with retry handling
       - Wait 1.5s for server state sync
       - Invoke Remote TowerStart
       - Intercept Telemetry (funnel = "towerContinue") via newcclosure hookmetamethod -> Fire TowerContinueDecline
       - Wait 10s cooldown after Decline and repeat loop
    7. Global UI Cleanup & Real-time Validation:
       - Continuous IsUIValid checks inside all while loops
       - Immediately halts all automation loops and restores collisions if UI is closed or destroyed
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
local UIValidator = nil

function ScrapFarm.SetUIValidator(validatorFunc)
    UIValidator = validatorFunc
end

local function IsUIValid()
    if UIValidator then
        local isValid = UIValidator()
        if not isValid then
            ScrapFarm.StopAll()
            return false
        end
    end
    return true
end

function ScrapFarm.StopAll()
    ScrapFarm.Enabled = false
    ScrapFarm.CoinsEnabled = false
    ScrapFarm.TowerEnabled = false
    Movement.DisableNoclip()
end

local function GetScrapCount()
    local count = LocalPlayer:GetAttribute("scrapCarry")
    if count ~= nil then
        return tonumber(count) or 0
    end
    return 0
end

local function GetTowerLevel()
    local player = LocalPlayer or Players.LocalPlayer
    if not player then return 1 end

    local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local towerObj = leaderstats:FindFirstChild("Tower") or leaderstats:WaitForChild("Tower", 5)
        if towerObj then
            local val = tonumber(towerObj.Value)
            if val and val > 0 then
                return val
            end
        end
    end
    return 1
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
    if not IsUIValid() then return false end
    return ScrapFarm.Enabled or ScrapFarm.CoinsEnabled
end

local function StartFarmLoop()
    if isLoopRunning then return end
    isLoopRunning = true

    Movement.EnableNoclip()

    task.spawn(function()
        while IsAnyFarmEnabled() and IsUIValid() do
            -----------------------------------------------------------------
            -- 1. Collect Target Items in PitScrap ("Loose" / "Part")
            -----------------------------------------------------------------
            while IsAnyFarmEnabled() and IsUIValid() and GetScrapCount() < ScrapFarm.TargetAmount do
                local targetItem = GetClosestTargetItem()

                if targetItem then
                    local targetPos = targetItem:IsA("BasePart") and targetItem.Position or targetItem:GetPivot().Position

                    local reached = Movement.WalkTo(targetPos, 15, IsAnyFarmEnabled, 3.5)

                    if not IsAnyFarmEnabled() or not IsUIValid() then break end
                    task.wait(0.2)
                else
                    if GetScrapCount() > 0 then
                        break
                    else
                        task.wait(1)
                    end
                end
            end

            if not IsAnyFarmEnabled() or not IsUIValid() then break end

            -----------------------------------------------------------------
            -- 2. Walk to Recycler1 and sell
            -----------------------------------------------------------------
            if GetScrapCount() > 0 then
                local retryAttempts = 0

                while IsAnyFarmEnabled() and IsUIValid() and GetScrapCount() > 0 and retryAttempts < 5 do
                    retryAttempts = retryAttempts + 1
                    
                    local recyclerPos = GetRecyclerPosition()

                    if recyclerPos then
                        Movement.WalkTo(recyclerPos, 20, IsAnyFarmEnabled, 4.5)

                        if not IsAnyFarmEnabled() or not IsUIValid() then break end

                        local sellStartTime = tick()
                        
                        while IsAnyFarmEnabled() and IsUIValid() and GetScrapCount() > 0 and (tick() - sellStartTime) < 4 do
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
    if state and not IsUIValid() then return end
    ScrapFarm.Enabled = state
    if state then
        StartFarmLoop()
    elseif not IsAnyFarmEnabled() then
        Movement.DisableNoclip()
    end
end

function ScrapFarm.ToggleCoins(state)
    if state and not IsUIValid() then return end
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
        
        local hookFunction = function(self, ...)
            local method = getnamecallmethod()

            if ScrapFarm.TowerEnabled and IsUIValid() and (method == "FireServer" or method == "fireServer") then
                if self and self.Name == "Telemetry" then
                    local args = {...}
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
        end

        if typeof(newcclosure) == "function" then
            hookFunction = newcclosure(hookFunction)
        end

        oldNamecall = hookmetamethod(game, "__namecall", hookFunction)
    end
end

function ScrapFarm.ToggleTower(state)
    if state and not IsUIValid() then return end
    ScrapFarm.TowerEnabled = state

    if state then
        SetupTelemetryHook()

        task.spawn(function()
            local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
            if not remotes then return end

            local towerElevator = remotes:WaitForChild("TowerElevator", 10)
            local towerStart = remotes:WaitForChild("TowerStart", 10)

            while ScrapFarm.TowerEnabled and IsUIValid() do
                lastDeclineTime = 0

                -- 1. อ่านค่าชั้นล่าสุดจาก leaderstats.Tower ก่อนเสมอ
                local currentTowerFloor = GetTowerLevel()

                -- 2. ยิง Remote TowerElevator ก่อนเสมอ
                if towerElevator then
                    local ok, _ = pcall(function()
                        if towerElevator:IsA("RemoteFunction") then
                            towerElevator:InvokeServer(currentTowerFloor)
                        elseif towerElevator:IsA("RemoteEvent") then
                            towerElevator:FireServer(currentTowerFloor)
                        end
                    end)

                    if not ok then
                        task.wait(0.5)
                        pcall(function()
                            if towerElevator:IsA("RemoteFunction") then
                                towerElevator:InvokeServer(currentTowerFloor)
                            end
                        end)
                    end
                end

                task.wait(1.5)

                if not ScrapFarm.TowerEnabled or not IsUIValid() then break end

                -- 3. ยิง Remote TowerStart ตามหลัง
                if towerStart then
                    pcall(function()
                        if towerStart:IsA("RemoteFunction") then
                            towerStart:InvokeServer()
                        elseif towerStart:IsA("RemoteEvent") then
                            towerStart:FireServer()
                        end
                    end)
                end

                -- 4. รอจนกว่า TowerContinueDecline จะถูกยิง หรือพ้นระยะ fallback
                local waitStart = tick()
                while ScrapFarm.TowerEnabled and IsUIValid() and lastDeclineTime == 0 do
                    task.wait(0.5)
                    if (tick() - waitStart) > 60 then
                        break
                    end
                end

                -- 5. รอครบ 10 วินาทีก่อนเริ่มลูปรอบถัดไป
                if ScrapFarm.TowerEnabled and IsUIValid() then
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

------------------------------------------------------------------------
-- GLOBAL CLEANUP & REAL-TIME UI VALIDATION
------------------------------------------------------------------------
local function CheckUI()
    if Library and Library.Unloaded then
        return false
    end
    if Library and Library.GUI then
        if not Library.GUI.Parent or not Library.GUI:IsDescendantOf(game) then
            return false
        end
    end
    return true
end

ScrapFarm.SetUIValidator(CheckUI)

local function OnUICclosed()
    ScrapFarm.StopAll()
end

pcall(function()
    if Window and typeof(Window.OnUnload) == "function" then
        Window:OnUnload(OnUICclosed)
    end
    if Library and typeof(Library.OnUnload) == "function" then
        Library:OnUnload(OnUICclosed)
    end
end)

task.spawn(function()
    task.wait(0.5)
    pcall(function()
        if Library and Library.GUI then
            Library.GUI.Destroying:Connect(OnUICclosed)
            Library.GUI.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    OnUICclosed()
                end
            end)
        end
    end)
end)

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
