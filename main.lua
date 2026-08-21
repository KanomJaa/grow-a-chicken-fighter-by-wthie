--[[
    ========================================================================
    White Studio Games - Main Script Entry Point (ไฟล์รันหลักแบบ Modular)
    ========================================================================
    วิธีนำไปขึ้น GitHub:
    1. สร้าง Repository บน GitHub เช่น ชื่อ "MyRobloxScript"
    2. อัปโหลดโฟลเดอร์ src และไฟล์ main.lua ขึ้น GitHub
    3. เปลี่ยน USERNAME และ REPO ด้านล่างเป็นของคุณ
    4. รันใน Roblox ด้วยคำสั่ง:
       loadstring(game:HttpGet("https://raw.githubusercontent.com/USERNAME/REPO/main/main.lua"))()
    ========================================================================
--]]

local USERNAME = "YOUR_GITHUB_USERNAME"  -- ใส่ ชื่อผู้ใช้ GitHub ของคุณ
local REPO     = "YOUR_REPOSITORY_NAME"  -- ใส่ ชื่อ Repository ของคุณ
local BRANCH   = "main"                  -- ชื่อ Branch (ส่วนใหญ่คือ main หรือ master)

local BaseUrl = string.format("https://raw.githubusercontent.com/%s/%s/%s/", USERNAME, REPO, BRANCH)

-- [1] โหลด Modules ต่างๆ จาก GitHub Raw
local Movement  = loadstring(game:HttpGet(BaseUrl .. "src/utils/movement.lua"))()
local ScrapFarm = loadstring(game:HttpGet(BaseUrl .. "src/features/scrap_farm.lua"))()
local UIModule  = loadstring(game:HttpGet(BaseUrl .. "src/ui.lua"))()

-- [2] เริ่มต้นทำงาน UI และส่ง Modules เข้าไปใช้งาน
local Window = UIModule.Init(ScrapFarm, Movement)

print("[White Studio] Script Loaded Successfully from GitHub!")
