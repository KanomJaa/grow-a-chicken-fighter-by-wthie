--[[
    ========================================================================
    White Studio Games - Single File Version (Auto PitScrap & Recycler)
    ========================================================================
    ระบบการทำงาน:
    1. ค้นหา "PitScrap" ใน Workspace -> หาชิ้น "Loose" ที่อยู่ใกล้ตัวละครมากที่สุด
    2. เปิด Noclip (เดินทะลุสิ่งของ)
    3. เดินไปเก็บ Loose ให้ครบ 10 ชิ้น
    4. เดินไปที่ "Recyclers" (workspace.Recyclers.Recycler1.Body) เพื่อทำการขาย
    5. ทำวนซ้ำเรื่อยๆ เมื่อเปิด Toggle / หยุดทำงานและปิด Noclip ทันทีเมื่อปิด Toggle
    ========================================================================
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------------
-- [1] MOVEMENT UTILS (ระบบการเดิน & Noclip ทะลุสิ่งของ)
------------------------------------------------------------------------
local Movement = {}
local NoclipConnection = nil

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
end

function Movement.WalkTo(targetPosition, timeout, shouldContinueCheck)
    timeout = timeout or 15
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
        
        if (hrp.Position - targetPosition).Magnitude <= 3.5 then
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
    TargetAmount = 10
}

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

    if recycler1:IsA("Model") then
        local body = recycler1:FindFirstChild("Body")
        if body and body:IsA("BasePart") then
            return body.Position
        end
        return recycler1:GetPivot().Position
    elseif recycler1:IsA("BasePart") then
        return recycler1.Position
    end

    return nil
end

function ScrapFarm.Toggle(state)
    ScrapFarm.Enabled = state

    if state then
        print("[Auto Scrap] เริ่มทำงาน - เปิด Noclip...")
        Movement.EnableNoclip()

        task.spawn(function()
            while ScrapFarm.Enabled do
                local collectedCount = 0

                -- 1. เดินเก็บ Loose ให้ครบ 10 ชิ้น
                while ScrapFarm.Enabled and collectedCount < ScrapFarm.TargetAmount do
                    local targetLoose = GetClosestLoose()

                    if targetLoose then
                        local targetPos = targetLoose:IsA("BasePart") and targetLoose.Position or targetLoose:GetPivot().Position
                        print(string.format("[Auto Scrap] เดินไปเก็บ Loose ชิ้นที่ %d/%d", collectedCount + 1, ScrapFarm.TargetAmount))

                        local reached = Movement.WalkTo(targetPos, 15, function() return ScrapFarm.Enabled end)

                        if not ScrapFarm.Enabled then break end

                        if reached or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and (LocalPlayer.Character.HumanoidRootPart.Position - targetPos).Magnitude <= 5) then
                            collectedCount = collectedCount + 1
                            print(string.format("[Auto Scrap] เก็บชิ้นที่ %d สำเร็จ", collectedCount))
                            task.wait(0.2)
                        end
                    else
                        print("[Auto Scrap] ไม่พบชิ้น Loose ใน PitScrap... รอ 1 วินาที")
                        task.wait(1)
                    end
                end

                if not ScrapFarm.Enabled then break end

                -- 2. เดินไปขายที่ Recyclers
                print("[Auto Scrap] เก็บครบ 10 ชิ้นแล้ว! กำลังเดินทางไปที่ Recyclers...")
                local recyclerPos = GetRecyclerPosition()

                if recyclerPos then
                    Movement.WalkTo(recyclerPos, 20, function() return ScrapFarm.Enabled end)

                    if not ScrapFarm.Enabled then break end

                    print("[Auto Scrap] ถึงจุดขาย Recyclers แล้ว... กำลังขาย")
                    task.wait(2.0)
                else
                    print("[Auto Scrap] ไม่พบตำแหน่ง Recyclers... รอ 2 วินาที")
                    task.wait(2)
                end

                task.wait(0.5)
            end

            Movement.DisableNoclip()
            print("[Auto Scrap] หยุดทำงาน และปิด Noclip เรียบร้อย")
        end)
    else
        Movement.DisableNoclip()
        print("[Auto Scrap] ปิดการทำงานเรียบร้อย")
    end
end

------------------------------------------------------------------------
-- [3] UI INITIALIZATION (Fluent Library)
------------------------------------------------------------------------
local Library = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Library:CreateWindow({
    Title = "White Studio Games",
    SubTitle = "Auto PitScrap & Recyclers",
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

-- Toggle สำหรับ Auto Scrap & Sell Recycler
local ScrapToggle = Tabs.Main:AddToggle("MyAutoToggle", {
    Title = "Auto Scap & Sell Recycler",
    Description = "ค้นหา PitScrap -> Loose 10 ชิ้น -> เดินทะลุไปขาย Recyclers",
    Default = false
})

ScrapToggle:OnChanged(function(Value)
    ScrapFarm.Toggle(Value)
end)

-- Slider ปรับความเร็วตัวละคร
local SpeedSlider = Tabs.Player:AddSlider("WalkSpeedSlider", {
    Title = "ความเร็วในการเดิน (WalkSpeed)",
    Description = "ปรับความเร็วของตัวละคร",
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

Window:SelectTab(1)
print("[White Studio] Single-file Auto Scrap Script initialized!")
