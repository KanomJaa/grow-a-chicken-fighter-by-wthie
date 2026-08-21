--[[
    Auto Scrap & Sell Recycler Feature Module
    หน้าที่: 
    1. ค้นหา "PitScrap" ใน Workspace -> ค้นหา "Loose" ที่ใกล้ Player ที่สุด
    2. เปิด Noclip (เดินทะลุสิ่งของ)
    3. เดินไปเก็บชิ้นที่ใกล้ที่สุดวนจนครบ 10 ชิ้น
    4. เมื่อครบ 10 ชิ้น เดินไปขายที่ "Recyclers"
    5. ทำวนซ้ำเรื่อยๆ จนกว่าจะปิด Toggle
--]]

local ScrapFarm = {}
ScrapFarm.Enabled = false
ScrapFarm.TargetCollectAmount = 10

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Movement Utility จะถูกส่งมาจาก main.lua หรือ ui.lua
local Movement = nil

function ScrapFarm.SetMovementModule(movementModule)
    Movement = movementModule
end

-- ฟังก์ชันค้นหาชิ้น Loose ใน PitScrap ที่อยู่ใกล้ Player มากที่สุด
local function GetClosestLoose()
    local character = LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local pitScrap = Workspace:FindFirstChild("PitScrap")
    if not pitScrap then
        warn("[Auto Scrap] ไม่พบโฟลเดอร์ PitScrap ใน Workspace!")
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

-- ฟังก์ชันค้นหาพิกัดตำแหน่งของ Recyclers
local function GetRecyclerPosition()
    local recyclers = Workspace:FindFirstChild("Recyclers")
    if not recyclers then
        warn("[Auto Scrap] ไม่พบ Recyclers ใน Workspace!")
        return nil
    end

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

-- ฟังก์ชันเริ่ม/หยุดการทำงาน
function ScrapFarm.Toggle(state)
    ScrapFarm.Enabled = state

    if state then
        print("[Auto Scrap] เริ่มทำงาน - เปิด Noclip และค้นหา PitScrap...")
        if Movement then Movement.EnableNoclip() end

        task.spawn(function()
            while ScrapFarm.Enabled do
                local collectedCount = 0

                -- Step 1: วนเก็บ Loose ให้ครบ 10 ชิ้น
                while ScrapFarm.Enabled and collectedCount < ScrapFarm.TargetCollectAmount do
                    local targetLoose = GetClosestLoose()

                    if targetLoose then
                        local targetPos = targetLoose:IsA("BasePart") and targetLoose.Position or targetLoose:GetPivot().Position
                        print(string.format("[Auto Scrap] กำลังเดินไปเก็บ Loose ชิ้นที่ %d/%d", collectedCount + 1, ScrapFarm.TargetCollectAmount))

                        local reached = false
                        if Movement then
                            reached = Movement.WalkTo(targetPos, 15, function() return ScrapFarm.Enabled end)
                        end

                        if not ScrapFarm.Enabled then break end

                        if reached or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and (LocalPlayer.Character.HumanoidRootPart.Position - targetPos).Magnitude <= 5) then
                            collectedCount = collectedCount + 1
                            print(string.format("[Auto Scrap] เก็บสำเร็จแล้ว (%d/%d)", collectedCount, ScrapFarm.TargetCollectAmount))
                            task.wait(0.2)
                        end
                    else
                        print("[Auto Scrap] ไม่พบชิ้น Loose ใน PitScrap... รอ 1 วินาที")
                        task.wait(1)
                    end
                end

                if not ScrapFarm.Enabled then break end

                -- Step 2: เมื่อเก็บครบ 10 ชิ้นแล้ว เดินไปขายที่ Recyclers
                print("[Auto Scrap] เก็บครบ 10 ชิ้นแล้ว! กำลังเดินทางไปที่ Recyclers...")
                local recyclerPos = GetRecyclerPosition()

                if recyclerPos then
                    if Movement then
                        Movement.WalkTo(recyclerPos, 20, function() return ScrapFarm.Enabled end)
                    end

                    if not ScrapFarm.Enabled then break end

                    print("[Auto Scrap] ถึงจุดขาย Recyclers แล้ว... กำลังทำการขาย")
                    task.wait(2.0)
                else
                    print("[Auto Scrap] ไม่พบตำแหน่ง Recyclers... รอ 2 วินาที")
                    task.wait(2)
                end

                task.wait(0.5)
            end

            if Movement then Movement.DisableNoclip() end
            print("[Auto Scrap] หยุดทำงาน และปิด Noclip เรียบร้อย")
        end)
    else
        if Movement then Movement.DisableNoclip() end
        print("[Auto Scrap] ปิดการทำงานเรียบร้อย")
    end
end

return ScrapFarm
