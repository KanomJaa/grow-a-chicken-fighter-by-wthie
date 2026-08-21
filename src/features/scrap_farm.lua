--[[
    Auto Scrap, Auto Coins & Auto Tower Farm Module
    หน้าที่: 
    1. ตรวจสอบจำนวน Scrap/Item จาก Player Attribute ("scrapCarry")
    2. รองรับ Auto Scrap ("Loose") และ Auto Coins ("Part") ใน PitScrap
    3. ถ้ารันพร้อมกันทั้งคู่ ระบบจะรวมเป็นลูปเดียวและเลือกเก็บชิ้นที่ใกล้ที่สุดก่อน (ไม่รวน/ไม่ชนกัน)
    4. เดินไปยืนหน้า "Recycler1" และขายจนกว่า scrapCarry == 0
    5. ปรับให้ Noclip ทำงานเมื่อเปิดใช้ และคืนค่า CanCollide ให้ชนปกติเมื่อปิด
    6. Auto Tower Loop (ยิง TowerElevator สำเร็จก่อนเสมอแล้วค่อยยิง TowerStart)
    7. ระบบ StopAll & UI Validation: ตรวจสอบความคงอยู่ของ UI ในทุกรอบลูป หากปิด UI ระบบจะหยุดการทำงานทั้งหมดทันที
    8. ป้องกัน Error Thread Capability: หุ้ม hookmetamethod ด้วย newcclosure ป้องกันสคริปต์ตัวเกม (CameraModule/ControlModule) ค้าง
--]]

local ScrapFarm = {}
ScrapFarm.Enabled = false
ScrapFarm.CoinsEnabled = false
ScrapFarm.TowerEnabled = false
ScrapFarm.TargetCollectAmount = 10

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Movement = nil
local isLoopRunning = false
local isTowerHooked = false
local lastDeclineTime = 0
local UIValidator = nil

function ScrapFarm.SetMovementModule(movementModule)
    Movement = movementModule
end

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
    if Movement then
        Movement.DisableNoclip()
    end
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
    if not IsUIValid() then return false end
    return ScrapFarm.Enabled or ScrapFarm.CoinsEnabled
end

local function StartFarmLoop()
    if isLoopRunning then return end
    isLoopRunning = true

    if Movement then Movement.EnableNoclip() end

    task.spawn(function()
        while IsAnyFarmEnabled() and IsUIValid() do
            -----------------------------------------------------------------
            -- STEP 1: เดินเก็บ Item ("Loose" / "Part") จนกว่าจะครบ 10 ชิ้น
            -----------------------------------------------------------------
            while IsAnyFarmEnabled() and IsUIValid() and GetScrapCount() < ScrapFarm.TargetCollectAmount do
                local targetItem = GetClosestTargetItem()

                if targetItem then
                    local targetPos = targetItem:IsA("BasePart") and targetItem.Position or targetItem:GetPivot().Position

                    local reached = false
                    if Movement then
                        reached = Movement.WalkTo(targetPos, 15, IsAnyFarmEnabled, 3.5)
                    end

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
            -- STEP 2: เดินไปที่ Recycler1 และรอให้ขายสำเร็จ (scrapCarry == 0)
            -----------------------------------------------------------------
            if GetScrapCount() > 0 then
                local retryAttempts = 0

                while IsAnyFarmEnabled() and IsUIValid() and GetScrapCount() > 0 and retryAttempts < 5 do
                    retryAttempts = retryAttempts + 1
                    local recyclerPos = GetRecyclerPosition()

                    if recyclerPos then
                        if Movement then
                            Movement.WalkTo(recyclerPos, 20, IsAnyFarmEnabled, 4.5)
                        end

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
        if Movement then Movement.DisableNoclip() end
    end)
end

function ScrapFarm.Toggle(state)
    if state and not IsUIValid() then return end
    ScrapFarm.Enabled = state
    if state then
        StartFarmLoop()
    elseif not IsAnyFarmEnabled() then
        if Movement then Movement.DisableNoclip() end
    end
end

function ScrapFarm.ToggleCoins(state)
    if state and not IsUIValid() then return end
    ScrapFarm.CoinsEnabled = state
    if state then
        StartFarmLoop()
    elseif not IsAnyFarmEnabled() then
        if Movement then Movement.DisableNoclip() end
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

                -- 3. ยิง Remote TowerStart
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

return ScrapFarm
