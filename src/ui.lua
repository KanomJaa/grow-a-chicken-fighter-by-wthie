--[[
    UI Module (Fluent Library)
    Main UI Setup with English labels
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
    -- GLOBAL CLEANUP & UI VALIDATION
    ---------------------------------------------------------------------
    local function CheckUI()
        if Library and Library.Unloaded then
            return false
        end
        if Library and Library.GUI then
            if not Library.GUI.Parent or not Library.GUI:IsDescendantOf(game) then
                return false
            end
        end
        return true
    end

    if ScrapFarmModule and ScrapFarmModule.SetUIValidator then
        ScrapFarmModule.SetUIValidator(CheckUI)
    end

    local function OnUICclosed()
        if ScrapFarmModule and ScrapFarmModule.StopAll then
            ScrapFarmModule.StopAll()
        end
    end

    pcall(function()
        if Window and typeof(Window.OnUnload) == "function" then
            Window:OnUnload(OnUICclosed)
        end
        if Library and typeof(Library.OnUnload) == "function" then
            Library:OnUnload(OnUICclosed)
        end
    end)

    task.spawn(function()
        task.wait(0.5)
        pcall(function()
            if Library and Library.GUI then
                Library.GUI.Destroying:Connect(OnUICclosed)
                Library.GUI.AncestryChanged:Connect(function(_, parent)
                    if not parent then
                        OnUICclosed()
                    end
                end)
            end
        end)
    end)

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
    local TowerToggle = Tabs.Tower:AddToggle("AutoTowerToggle", {
        Title = "Auto Tower",
        Description = "Auto climb and farm Tower",
        Default = false
    })

    TowerToggle:OnChanged(function(Value)
        if ScrapFarmModule and ScrapFarmModule.ToggleTower then
            ScrapFarmModule.ToggleTower(Value)
        end
    end)

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
