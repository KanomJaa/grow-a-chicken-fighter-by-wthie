--[[
    UI Module (Fluent Library)
    หน้าที่: สร้างหน้าต่าง UI, แท็บ (Tabs), ปุ่มเปิด/ปิด (Toggles) และเชื่อมต่อกับ Feature Modules
--]]

local UIModule = {}

function UIModule.Init(ScrapFarmModule, MovementModule)
    -- ส่ง Movement Module ให้กับ ScrapFarm
    if ScrapFarmModule and ScrapFarmModule.SetMovementModule then
        ScrapFarmModule.SetMovementModule(MovementModule)
    end

    -- โหลด Fluent Library
    local Library = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

    -- สร้างหน้าต่างหลัก (Window)
    local Window = Library:CreateWindow({
        Title = "White Studio Games",
        SubTitle = "v1.0.0 - Modular Version",
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })

    -- สร้างแท็บเมนูต่างๆ (Tabs)
    local Tabs = {
        Main     = Window:AddTab({ Title = "Auto Farm", Icon = "box" }),
        Player   = Window:AddTab({ Title = "Player", Icon = "user" }),
        Settings = Window:AddTab({ Title = "Settings", Icon = "sliders-horizontal" })
    }

    ---------------------------------------------------------------------
    -- [1] TAB: Auto Farm
    ---------------------------------------------------------------------
    Tabs.Main:AddSection("Auto PitScrap & Recyclers")

    -- Toggle สำหรับ Auto Scrap & Sell
    local ScrapToggle = Tabs.Main:AddToggle("MyAutoToggle", {
        Title = "Auto Scap & Sell Recycler",
        Description = "ค้นหา PitScrap -> Loose 10 ชิ้น -> เดินทะลุไปขาย Recyclers",
        Default = false
    })

    ScrapToggle:OnChanged(function(Value)
        if ScrapFarmModule then
            ScrapFarmModule.Toggle(Value)
        end
    end)

    ---------------------------------------------------------------------
    -- [2] TAB: Player Utilities
    ---------------------------------------------------------------------
    Tabs.Player:AddSection("การตั้งค่าตัวละคร")

    -- WalkSpeed Slider
    local SpeedSlider = Tabs.Player:AddSlider("WalkSpeedSlider", {
        Title = "ความเร็วในการเดิน (WalkSpeed)",
        Description = "ปรับความเร็วของตัวละคร",
        Default = 16,
        Min = 16,
        Max = 200,
        Rounding = 0
    })

    SpeedSlider:OnChanged(function(Value)
        local lp = game:GetService("Players").LocalPlayer
        if lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") then
            lp.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Value
        end
    end)

    ---------------------------------------------------------------------
    -- [3] TAB: Settings
    ---------------------------------------------------------------------
    Tabs.Settings:AddParagraph({
        Title = "คำแนะนำการใช้งาน GitHub",
        Content = "เมื่ออัปขึ้น GitHub แล้ว คุณสามารถรันสคริปต์ผ่าน loadstring(game:HttpGet('...')) ได้ทันที"
    })

    Window:SelectTab(1)
    return Window
end

return UIModule
