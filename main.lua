--[[
    ========================================================================
    White Studio Games - Main Script Entry Point (ไฟล์รันหลักแบบ Modular)
    ========================================================================
    สคริปต์นี้ถูกตั้งค่า GitHub URL ของคุณเรียบร้อยแล้ว:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/KanomJaa/grow-a-chicken-fighter-by-wthie/main/main.lua"))()
    ========================================================================
--]]

local USERNAME = "KanomJaa"                          -- ชื่อผู้ใช้ GitHub ของคุณ
local REPO     = "grow-a-chicken-fighter-by-wthie"  -- ชื่อ Repository ของคุณ
local BRANCH   = "main"                              -- ชื่อ Branch

local BaseUrl = string.format("https://raw.githubusercontent.com/%s/%s/%s/", USERNAME, REPO, BRANCH)

-- [1] โหลด Modules ต่างๆ จาก GitHub Raw
local Movement  = loadstring(game:HttpGet(BaseUrl .. "src/utils/movement.lua"))()
local ScrapFarm = loadstring(game:HttpGet(BaseUrl .. "src/features/scrap_farm.lua"))()
local UIModule  = loadstring(game:HttpGet(BaseUrl .. "src/ui.lua"))()

-- [2] เริ่มต้นทำงาน UI และส่ง Modules เข้าไปใช้งาน
local Window = UIModule.Init(ScrapFarm, Movement)
