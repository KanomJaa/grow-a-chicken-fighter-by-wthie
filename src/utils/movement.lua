--[[
    Movement Utility Module
    หน้าที่: จัดการการเคลื่อนที่ของตัวละคร (WalkTo, Teleport, Noclip เดินทะลุสิ่งของ)
--]]

local Movement = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local NoclipConnection = nil

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

-- ปิดการเดินทะลุสิ่งของ (Disable Noclip)
function Movement.DisableNoclip()
    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection = nil
    end
end

-- ฟังก์ชันสำหรับเดินไปยังพิกัด Vector3 หรือ CFrame (พร้อมระบบยกเลิกทันทีเมื่อหยุดทำงาน)
function Movement.WalkTo(targetPosition, timeout, shouldContinueCheck)
    timeout = timeout or 15
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
            humanoid:MoveTo(hrp.Position) -- สั่งหยุดเดินที่ตำแหน่งปัจจุบัน
            break
        end
        
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            break
        end
        
        -- เช็คระยะห่าง ถ้าใกล้เป้าหมายในระยะ 3 studs ถือว่าถึงแล้ว
        if (hrp.Position - targetPosition).Magnitude <= 3.5 then
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
