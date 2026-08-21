--[[
    ========================================================================
    White Studio Games - Single File Version (Auto PitScrap & Recycler)
    ========================================================================
    ระบบการทำงาน:
    1. ตรวจสอบจำนวน Scrap จาก Attribute "scrapCarry" ของ Player
    2. ค้นหา "PitScrap" ใน Workspace -> หาชิ้น "Loose" ที่อยู่ใกล้ตัวละครมากที่สุด
    3. เปิด Noclip (เดินทะลุสิ่งของ) และเมื่อปิด Auto จะคืนค่าให้เดินชนได้ตามปกติ
    4. เดินไปเก็บจนกระทั่ง scrapCarry >= 10 (หรือจนกว่า Loose จะหมด)
    5. เดินไปยืนข้างหน้า "Recycler1" (ไม่ตกลงไปข้างใน) และรอจนกว่า scrapCarry == 0
    6. ทำวนซ้ำเรื่อยๆ เมื่อเปิด Toggle / หยุดทำงานและปิด Noclip ทันทีเมื่อปิด Toggle
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

-- ฟังก์ชันค้นหาพิกัดตำแหน่งข้างหน้า Recycler1 (ระยะ 4.5 studs ไม่ตกลงไปข้างใน)
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
        print("[Auto Scrap] เริ่มทำงาน - เปิด Noclip และตรวจเช็ค scrapCarry...")
        Movement.EnableNoclip()

        task.spawn(function()
            while ScrapFarm.Enabled do
                -----------------------------------------------------------------
                -- 1. เดินเก็บ Loose ใน PitScrap จนกว่าจะครบ 10 หรือไม่เหลือ Loose
                -----------------------------------------------------------------
                while ScrapFarm.Enabled and GetScrapCount() < ScrapFarm.TargetAmount do
                    local targetLoose = GetClosestLoose()

                    if targetLoose then
                        local targetPos = targetLoose:IsA("BasePart") and targetLoose.Position or targetLoose:GetPivot().Position
                        print(string.format("[Auto Scrap] เดินไปเก็บ Loose ( scrapCarry: %d/%d )", GetScrapCount(), ScrapFarm.TargetAmount))

                        local reached = Movement.WalkTo(targetPos, 15, function() return ScrapFarm.Enabled end, 3.5)

                        if not ScrapFarm.Enabled then break end
                        task.wait(0.2)
                    else
                        if GetScrapCount() > 0 then
                            print("[Auto Scrap] ไม่พบ Loose เพิ่มเติมแล้ว มีของอยู่ -> เดินไป Recycler1 ทันที!")
                            break
                        else
                            print("[Auto Scrap] ไม่พบชิ้น Loose ใน PitScrap... รอ 1 วินาที")
                            task.wait(1)
                        end
                    end
                end

                if not ScrapFarm.Enabled then break end

                -----------------------------------------------------------------
                -- 2. เดินไปยืนหน้า Recycler1 และรอจนกว่าขายสำเร็จ (scrapCarry == 0)
                -----------------------------------------------------------------
                if GetScrapCount() > 0 then
                    local retryAttempts = 0

                    while ScrapFarm.Enabled and GetScrapCount() > 0 and retryAttempts < 5 do
                        retryAttempts = retryAttempts + 1
                        print(string.format("[Auto Scrap] (ครั้งที่ %d) เดินไปหน้า Recycler1 เพื่อขาย Scrap...", retryAttempts))
                        
                        local recyclerPos = GetRecyclerPosition()

                        if recyclerPos then
                            Movement.WalkTo(recyclerPos, 20, function() return ScrapFarm.Enabled end, 4.5)

                            if not ScrapFarm.Enabled then break end

                            print("[Auto Scrap] ยืนรอให้ขาย Scrap...")
                            local sellStartTime = tick()
                            
                            while ScrapFarm.Enabled and GetScrapCount() > 0 and (tick() - sellStartTime) < 4 do
                                task.wait(0.3)
                            end

                            if GetScrapCount() == 0 then
                                print("[Auto Scrap] ขายสำเร็จแล้ว! scrapCarry = 0")
                                break
                            else
                                warn("[Auto Scrap] ยังขายไม่สำเร็จ! กำลังลองขยับไปที่ Recycler1 ใหม่...")
                                task.wait(0.5)
                            end
                        else
                            warn("[Auto Scrap] ไม่พบตำแหน่ง Recycler1... รอ 2 วินาที")
                            task.wait(2)
                        end
                    end
                end

                task.wait(0.5)
            end

            Movement.DisableNoclip()
            print("[Auto Scrap] หยุดทำงาน และปิด Noclip คืนค่าการชนเรียบร้อย")
        end)
    else
        Movement.DisableNoclip()
        print("[Auto Scrap] ปิดการทำงาน และคืนค่าการชนเรียบร้อย")
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
    Description = "ตรวจ scrapCarry -> เก็บ 10 ชิ้น -> ยืนขายหน้า Recycler1",
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
