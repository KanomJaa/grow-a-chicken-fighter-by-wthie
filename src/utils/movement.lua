--[[
    Movement Utility Module
    หน้าที่: จัดการการเคลื่อนที่ของตัวละคร (WalkTo, Teleport, Noclip เดินทะลุสิ่งของ, เช็คการกดเดินเองของ Player)
--]]

local Movement = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local NoclipConnection = nil

-- ตรวจสอบว่า Player กำลังกดเดินเองหรือไม่ (คีย์บอร์ด WASD / ปุ่มลูกศร / จอยสติ๊กมือถือ)
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

    -- ตรวจสอบสำหรับ มือถือ (Mobile Touch) หรือ Gamepad
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
            -- ตรวจสอบว่าไม่ได้พิมพ์ข้อความใน Chat อยู่
            if UserInputService:GetFocusedTextBox() == nil then
                return true
            end
        end
    end

    return false
end

-- เปิดการเดินทะลุสิ่งของ (Noclip)
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

-- ปิดการเดินทะลุสิ่งของ (Disable Noclip) + คืนค่าให้กลับมาเดินชนตามปกติ
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

-- ฟังก์ชันสำหรับเดินไปยังพิกัด Vector3 หรือ CFrame (หยุดให้ Player เดินเองได้เมื่อกด WASD)
function Movement.WalkTo(targetPosition, timeout, shouldContinueCheck, stopDistance)
    timeout = timeout or 15
    stopDistance = stopDistance or 3.5

    local character = LocalPlayer.Character
    if not character then return false end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return false end
    
    if typeof(targetPosition) == "CFrame" then
        targetPosition = targetPosition.Position
    end
    
    humanoid:MoveTo(targetPosition)
    
    local startTime = tick()
    local reached = false
    local connection
    
    connection = humanoid.MoveToFinished:Connect(function(status)
        reached = true
    end)
    
    while not reached and (tick() - startTime) < timeout do
        -- เช็คว่ายังต้องการเดินต่อไหม (ถ้ากดยกเลิกใน UI ให้หยุดเดินทันที)
        if shouldContinueCheck and not shouldContinueCheck() then
            humanoid:MoveTo(hrp.Position)
            break
        end
        
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            break
        end

        -- -----------------------------------------------------------------
        -- ระบบป้องกันการแย่งกันเดิน: ถ้า Player กดเดินเอง (WASD / Joystick)
        -- ให้หยุดส่งคำสั่ง MoveTo ชั่วคราว ปล่อยให้ Player เดินได้ตามสบาย
        -- -----------------------------------------------------------------
        if Movement.IsPlayerMovingManually() then
            while (shouldContinueCheck == nil or shouldContinueCheck()) and Movement.IsPlayerMovingManually() do
                task.wait(0.1)
            end
            -- เมื่อปล่อยปุ่มเดินแล้ว ให้ส่งคำสั่งเดินไปยังเป้าหมายเดิมต่อ
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):MoveTo(targetPosition)
            end
        end

        -- เช็คระยะห่าง หากถึงระยะ stopDistance ถือว่าถึงเป้าหมายแล้ว
        if (hrp.Position - targetPosition).Magnitude <= stopDistance then
            reached = true
            break
        end
        
        task.wait(0.05)
    end
    
    if connection then
        connection:Disconnect()
    end
    
    return reached
end

-- ฟังก์ชันสำหรับวาร์ป (Teleport) ไปยังพิกัดทันที
function Movement.Teleport(targetCFrame)
    local character = LocalPlayer.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    if typeof(targetCFrame) == "Vector3" then
        targetCFrame = CFrame.new(targetCFrame)
    end
    
    hrp.CFrame = targetCFrame
    return true
end

return Movement
