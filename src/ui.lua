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
        Main        = Window:AddTab({ Title = "Auto Farm", Icon = "box" }),
        AutoUpgrade = Window:AddTab({ Title = "Auto Upgrade", Icon = "arrow-up-circle" }),
        Tower       = Window:AddTab({ Title = "Tower", Icon = "layers" }),
        Settings    = Window:AddTab({ Title = "Settings", Icon = "sliders-horizontal" })
    }

    ---------------------------------------------------------------------
    -- [1] TAB: Auto Farm
    ---------------------------------------------------------------------

    -- Toggle 1: Auto Scrap & Sell Recycler
    local ScrapToggle = Tabs.Main:AddToggle("AutoScrapToggle", {
        Title = "Auto Scrap & Sell Recycler",
        Description = "Auto farm Scrap and sell at Recycler",
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
    -- [2] TAB: Auto Upgrade
    ---------------------------------------------------------------------
    Tabs.AutoUpgrade:AddParagraph({
        Title = "Auto Upgrade System",
        Content = "Configure auto upgrades for your stats and equipment here."
    })

    ---------------------------------------------------------------------
    -- [3] TAB: Tower
    ---------------------------------------------------------------------
    Tabs.Tower:AddParagraph({
        Title = "Tower System",
        Content = "Configure tower automation settings here."
    })

    ---------------------------------------------------------------------
    -- [4] TAB: Settings
    ---------------------------------------------------------------------
    Tabs.Settings:AddParagraph({
        Title = "GitHub Usage Instructions",
        Content = "After pushing to GitHub, execute using loadstring(game:HttpGet('...'))"
    })

    Window:SelectTab(1)
    return Window
end

return UIModule
