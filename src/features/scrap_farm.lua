--[[
    Auto Scrap & Sell Recycler Feature Module
    หน้าที่: 
    1. ตรวจสอบจำนวน Scrap จาก Player Attribute ("scrapCarry")
    2. ค้นหา "PitScrap" ใน Workspace -> ค้นหา "Loose" ที่ใกล้ Player ที่สุด
    3. เดินไปเก็บจนกระทั่ง scrapCarry >= 10 (หรือจนกว่า Loose จะหมด)
    4. เดินไปหน้า "Recycler1" (ยืนข้างหน้า ไม่ตกลงไปข้างใน)
    5. ทำระบบเช็คความปลอดภัย: รอจนกว่า scrapCarry == 0 ถึงจะกลับไปฟาร์มต่อ
    6. คืนค่า CanCollide (เดินชนปกติ) ทันทีเมื่อปิด Toggle
--]]

local ScrapFarm = {}
ScrapFarm.Enabled = false
ScrapFarm.CoinsEnabled = false
ScrapFarm.TargetCollectAmount = 10

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Movement Utility จะถูกส่งมาจาก main.lua หรือ ui.lua
local Movement = nil

function ScrapFarm.SetMovementModule(movementModule)
    Movement = movementModule
end

-- ฟังก์ชันอ่านค่าจำนวน Scrap จาก Attribute "scrapCarry" ของ Player
local function GetScrapCount()
    local count = LocalPlayer:GetAttribute("scrapCarry")
    if count ~= nil then
        return tonumber(count) or 0
    end
    return 0
end

-- ฟังก์ชันค้นหาชิ้น Loose ใน PitScrap ที่อยู่ใกล้ Player มากที่สุด
local function GetClosestLoose()
    local character = LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local pitScrap = Workspace:FindFirstChild("PitScrap")
    if not pitScrap then
        return nil
    end

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

-- ฟังก์ชันค้นหาพิกัดตำแหน่งข้างหน้า Recycler1 (ถอยออกมาก่อน 4.5 studs ไม่ตกลงไปข้างใน)
local function GetRecyclerPosition()
    local recyclers = Workspace:FindFirstChild("Recyclers")
    if not recyclers then
        return nil
    end

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

-- ฟังก์ชันเริ่ม/หยุดการทำงาน Auto Scrap & Sell
function ScrapFarm.Toggle(state)
    ScrapFarm.Enabled = state

    if state then
        if Movement then Movement.EnableNoclip() end

        task.spawn(function()
            while ScrapFarm.Enabled do
                -----------------------------------------------------------------
                -- STEP 1: เดินเก็บ Scrap ใน PitScrap จนกว่าจะครบ 10 หรือไม่เหลือ Loose
                -----------------------------------------------------------------
                while ScrapFarm.Enabled and GetScrapCount() < ScrapFarm.TargetCollectAmount do
                    local targetLoose = GetClosestLoose()

                    if targetLoose then
                        local targetPos = targetLoose:IsA("BasePart") and targetLoose.Position or targetLoose:GetPivot().Position

                        local reached = false
                        if Movement then
                            reached = Movement.WalkTo(targetPos, 15, function() return ScrapFarm.Enabled end, 3.5)
                        end

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
                -- STEP 2: เดินไปที่ Recycler1 และรอให้ขายสำเร็จ (scrapCarry == 0)
                -----------------------------------------------------------------
                if GetScrapCount() > 0 then
                    local retryAttempts = 0

                    while ScrapFarm.Enabled and GetScrapCount() > 0 and retryAttempts < 5 do
                        retryAttempts = retryAttempts + 1
                        local recyclerPos = GetRecyclerPosition()

                        if recyclerPos then
                            if Movement then
                                Movement.WalkTo(recyclerPos, 20, function() return ScrapFarm.Enabled end, 4.5)
                            end

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

            if Movement then Movement.DisableNoclip() end
        end)
    else
        if Movement then Movement.DisableNoclip() end
    end
end

-- ฟังก์ชันสำหรับ Auto Coins & Sell Recycler (เตรียมพร้อมสำหรับใส่ระบบเมื่อต้องการ)
function ScrapFarm.ToggleCoins(state)
    ScrapFarm.CoinsEnabled = state
end

return ScrapFarm
