--[[
    Auto Scrap & Auto Coins Farm Module
    หน้าที่: 
    1. ตรวจสอบจำนวน Scrap/Item จาก Player Attribute ("scrapCarry")
    2. รองรับ Auto Scrap ("Loose") และ Auto Coins ("Part") ใน PitScrap
    3. ถ้ารันพร้อมกันทั้งคู่ ระบบจะรวมเป็นลูปเดียวและเลือกเก็บชิ้นที่ใกล้ที่สุดก่อน (ไม่รวน/ไม่ชนกัน)
    4. เดินไปยืนหน้า "Recycler1" และขายจนกว่า scrapCarry == 0
    5. ปรับให้ Noclip ทำงานเมื่อเปิดใช้ และคืนค่า CanCollide ให้ชนปกติเมื่อปิด
--]]

local ScrapFarm = {}
ScrapFarm.Enabled = false
ScrapFarm.CoinsEnabled = false
ScrapFarm.TargetCollectAmount = 10

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Movement = nil
local isLoopRunning = false

function ScrapFarm.SetMovementModule(movementModule)
    Movement = movementModule
end

local function GetScrapCount()
    local count = LocalPlayer:GetAttribute("scrapCarry")
    if count ~= nil then
        return tonumber(count) or 0
    end
    return 0
end

-- ค้นหาชิ้นเป้าหมาย ("Loose" สำหรับ Scrap และ/หรือ "Part" สำหรับ Coins) ที่อยู่ใกล้ที่สุด
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

    if Movement then Movement.EnableNoclip() end

    task.spawn(function()
        while IsAnyFarmEnabled() do
            -----------------------------------------------------------------
            -- STEP 1: เดินเก็บ Item ("Loose" / "Part") จนกว่าจะครบ 10 ชิ้น
            -----------------------------------------------------------------
            while IsAnyFarmEnabled() and GetScrapCount() < ScrapFarm.TargetCollectAmount do
                local targetItem = GetClosestTargetItem()

                if targetItem then
                    local targetPos = targetItem:IsA("BasePart") and targetItem.Position or targetItem:GetPivot().Position

                    local reached = false
                    if Movement then
                        reached = Movement.WalkTo(targetPos, 15, IsAnyFarmEnabled, 3.5)
                    end

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
            -- STEP 2: เดินไปที่ Recycler1 และรอให้ขายสำเร็จ (scrapCarry == 0)
            -----------------------------------------------------------------
            if GetScrapCount() > 0 then
                local retryAttempts = 0

                while IsAnyFarmEnabled() and GetScrapCount() > 0 and retryAttempts < 5 do
                    retryAttempts = retryAttempts + 1
                    local recyclerPos = GetRecyclerPosition()

                    if recyclerPos then
                        if Movement then
                            Movement.WalkTo(recyclerPos, 20, IsAnyFarmEnabled, 4.5)
                        end

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
        if Movement then Movement.DisableNoclip() end
    end)
end

function ScrapFarm.Toggle(state)
    ScrapFarm.Enabled = state
    if state then
        StartFarmLoop()
    elseif not IsAnyFarmEnabled() then
        if Movement then Movement.DisableNoclip() end
    end
end

function ScrapFarm.ToggleCoins(state)
    ScrapFarm.CoinsEnabled = state
    if state then
        StartFarmLoop()
    elseif not IsAnyFarmEnabled() then
        if Movement then Movement.DisableNoclip() end
    end
end

return ScrapFarm
