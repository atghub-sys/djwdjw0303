-- SendEmbedOnce_WithPlayers.lua
-- Client-side script: ทำงานครั้งเดียวเมื่อรัน (LocalScript / Executor)
-- รองรับ: syn.request, request, http_request, http.request, HttpService:PostAsync
-- เพิ่ม field "Players" แสดงรูปแบบ current/max (เช่น 3/6)

local WEBHOOK_URL = "https://discord.com/api/webhooks/1432280942134820904/ExVKTvLfFjkbQ-1gR1BNimUY7wDNVey3Okh3C96ZDi09peBKdUzeVrYaaj8094NO1Ygl"
local SERVER_IMAGE_URL = "https://img5.pic.in.th/file/secure-sv1/remix-77797a08-72e9-4e05-aa86-5bccff462ee2-removebg-preview912aeb8810af98ca.png"
local THUMB_URL = "https://tr.rbxcdn.com/180DAY-5d6682eeb67b22411bc887ece1d4ec8f/256/256/Image/Webp/noFilter"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ---------- Helpers สำหรับเรียก HTTP ในหลาย environment ----------
local function hasHttpServiceEnabled()
    local ok, val = pcall(function() return HttpService.HttpEnabled end)
    return ok and val
end

local function tryExecutorRequest(req)
    -- คืน table { ok = bool, status = number?, body = string?, err = string? }
    local ok, res
    if type(syn) == "table" and type(syn.request) == "function" then
        ok, res = pcall(function() return syn.request(req) end)
        if ok and res then return { ok = true, status = res.StatusCode or res.status, body = res.Body or res.body } end
        return { ok = false, err = tostring(res) }
    end

    if type(request) == "function" then
        ok, res = pcall(function() return request(req) end)
        if ok and res then return { ok = true, status = res.StatusCode or res.status, body = res.Body or res.body } end
        return { ok = false, err = tostring(res) }
    end

    if type(http_request) == "function" then
        ok, res = pcall(function() return http_request(req) end)
        if ok and res then return { ok = true, status = res.StatusCode or res.status, body = res.Body or res.body } end
        return { ok = false, err = tostring(res) }
    end

    if type(http) == "table" and type(http.request) == "function" then
        ok, res = pcall(function() return http.request(req) end)
        if ok and res then return { ok = true, status = res.StatusCode or res.status, body = res.Body or res.body } end
        return { ok = false, err = tostring(res) }
    end

    return { ok = false, err = "No executor HTTP function found" }
end

local function httpPostJson(url, luaTable)
    local body = HttpService:JSONEncode(luaTable)

    -- try executor first (most common in exploit environments)
    local execRes = tryExecutorRequest({
        Url = url,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "Roblox-Embed-Script"
        },
        Body = body
    })
    if execRes.ok then return true, execRes end

    -- fallback to HttpService if enabled
    if hasHttpServiceEnabled() then
        local ok, resp = pcall(function()
            return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
        end)
        if ok then
            return true, { ok = true, status = 200, body = resp }
        else
            return false, { ok = false, err = tostring(resp) }
        end
    end

    return false, { ok = false, err = "No available HTTP method (executor/httpservice disabled)" }
end

-- ---------- Helpers สำหรับความยาวข้อความ (Discord limits) ----------
local function truncate(s, maxLen)
    if not s then return "" end
    if #s <= maxLen then return s end
    return string.sub(s, 1, maxLen - 3) .. "..."
end

-- ---------- ค้นหา Label ที่ต้องการ (รอถ้ายังไม่ปรากฏ) ----------
local function findHalloweenLabel(timeout)
    timeout = timeout or 6
    local start = tick()
    while tick() - start <= timeout do
        local ok, lbl = pcall(function()
            local tycoons = workspace:FindFirstChild("Tycoons")
            if not tycoons then return nil end
            local map = tycoons:FindFirstChild("Map")
            if not map then return nil end
            local hw = map:FindFirstChild("HalloweenWeather")
            if not hw then return nil end
            local ui = hw:FindFirstChild("UI")
            if not ui then return nil end
            local bar = ui:FindFirstChild("Bar")
            if not bar then return nil end
            local label = bar:FindFirstChild("Label")
            return label
        end)
        if ok and lbl then return lbl end
        task.wait(0.2)
    end
    return nil
end

-- ---------- สร้าง Embed (Witch Cauldron เป็น field, Job ID ครอบด้วย backticks, เพิ่ม Players field) ----------
local function buildEmbed(textValue, jobId, playerName, playersField)
    local safeText = tostring(textValue or "Unknown")
    local safeJob = tostring(jobId or "Unknown")
    local safePlayer = tostring(playerName or "Unknown")
    local safePlayersField = tostring(playersField or "-")

    local embed = {
        title = truncate("Raise Animals", 256),
        -- คำอธิบายสั้น ๆ (ปรับข้อความได้ตามต้องการ)
        description = truncate("Raise Animals Notify By ATG Hub Request In <#1427270174498885632>", 1024),
        color = 1247221, -- สีที่คุณเลือก (จาก RGB(19,7,245))
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        thumbnail = { url = THUMB_URL },
        fields = {
            {
                name = "Witch Cauldron",
                value = ("`%s`"):format(truncate(safeText, 1024)),
                ["inline"] = false
            },
            {
                name = "Players",
                value = ("`%s`"):format(truncate(safePlayersField, 1024)), -- ครอบด้วย backticks เช่น `3/6`
                ["inline"] = false
            },
            {
                name = "Job ID",
                value = ("`%s`"):format(truncate(safeJob, 1024)),
                ["inline"] = false
            }
        },
        footer = {
            text = "Notify ATG Hub",
            icon_url = SERVER_IMAGE_URL or ""
        }
    }

    return embed
end

-- ---------- Main: ทำงานครั้งเดียว ----------
local function main()
    -- รอ LocalPlayer (client) สั้น ๆ
    local player = Players.LocalPlayer
    local waitStart = tick()
    while not player and tick() - waitStart < 10 do
        Players.PlayerAdded:Wait()
        player = Players.LocalPlayer
    end
    if not player then
        warn("[Embed] ไม่พบ LocalPlayer")
        return
    end

    -- หา Label
    local label = findHalloweenLabel(6)
    if not label then
        return
    end

    -- อ่านค่า text จาก Label (รองรับ TextLabel, TextBox, StringValue หรือ property Text)
    local textValue = ""
    if typeof(label) == "Instance" then
        if label:IsA("TextLabel") or label:IsA("TextBox") or label:IsA("TextButton") then
            textValue = label.Text
        elseif label:IsA("StringValue") then
            textValue = label.Value
        else
            local ok, val = pcall(function() return label.Text end)
            if ok and val then textValue = val else textValue = tostring(label) end
        end
    else
        textValue = tostring(label)
    end

    -- ดึงจำนวนผู้เล่นปัจจุบันและจำนวนสูงสุดของเซิร์ฟเวอร์
    local currentPlayers = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers or 0
    -- ถ้า MaxPlayers = 0 หรือไม่ถูกกำหนด ให้ใช้ "-" แทน หรือแสดงเป็น current/unknown
    local playersFieldValue
    if type(maxPlayers) == "number" and maxPlayers > 0 then
        playersFieldValue = tostring(currentPlayers) .. "/" .. tostring(maxPlayers)
    else
        playersFieldValue = tostring(currentPlayers) .. "/?"
    end

    local jobId = tostring(game.JobId or "Unknown")
    local playerName = player.Name or "Unknown"

    -- สร้าง embed โดย Witch Cauldron เป็น field และ Job ID มี backticks, เพิ่ม Players field
    local embed = buildEmbed(textValue, jobId, playerName, playersFieldValue)
    local payload = { embeds = { embed } }

    -- ส่ง HTTP
    local ok, res = httpPostJson(WEBHOOK_URL, payload)
    if ok then
    else
    end
end

-- Run: เรียก main ถ้าเป็น client
if RunService:IsClient() then
    task.spawn(function()
        -- รอเกม/character เตรียมตัวสั้น ๆ
        task.wait(0.5)
        pcall(main)
    end)
else
    warn("[Embed] สคริปต์นี้ออกแบบมาสำหรับ client-side (LocalScript / executor), ไม่ใช่ server-side")
end
