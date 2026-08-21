--[[
    UI Module (Fluent Library)
    Main UI Setup with English labels and Auto Coins toggle placeholder
--]]

local UIModule = {}

function UIModule.Init(ScrapFarmModule, MovementModule)
    if ScrapFarmModule and ScrapFarmModule.SetMovementModule then
        ScrapFarmModule.SetMovementModule(MovementModule)
    end

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
        Main     = Window:AddTab({ Title = "Auto Farm", Icon = "box" }),
        Player   = Window:AddTab({ Title = "Player", Icon = "user" }),
        Settings = Window:AddTab({ Title = "Settings", Icon = "sliders-horizontal" })
    }

    ---------------------------------------------------------------------
    -- [1] TAB: Auto Farm
    ---------------------------------------------------------------------
    Tabs.Main:AddSection("Auto Recycler Farm")

    -- Toggle 1: Auto Scrap & Sell Recycler
    local ScrapToggle = Tabs.Main:AddToggle("AutoScrapToggle", {
        Title = "Auto Scrap & Sell Recycler",
        Description = "Check scrapCarry -> Collect 10 items -> Sell in front of Recycler1",
        Default = false
    })

    ScrapToggle:OnChanged(function(Value)
        if ScrapFarmModule then
            ScrapFarmModule.Toggle(Value)
        end
    end)

    -- Toggle 2: Auto Coins & Sell Recycler
    local CoinsToggle = Tabs.Main:AddToggle("AutoCoinsToggle", {
        Title = "Auto Coins & Sell Recycler",
        Description = "Auto farm coins and sell at Recycler",
        Default = false
    })

    CoinsToggle:OnChanged(function(Value)
        if ScrapFarmModule and ScrapFarmModule.ToggleCoins then
            ScrapFarmModule.ToggleCoins(Value)
        end
    end)

    ---------------------------------------------------------------------
    -- [2] TAB: Player Utilities
    ---------------------------------------------------------------------
    Tabs.Player:AddSection("Character Settings")

    local SpeedSlider = Tabs.Player:AddSlider("WalkSpeedSlider", {
        Title = "WalkSpeed",
        Description = "Adjust character movement speed",
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
        Title = "GitHub Usage Instructions",
        Content = "After pushing to GitHub, execute using loadstring(game:HttpGet('...'))"
    })

    Window:SelectTab(1)
    return Window
end

return UIModule
