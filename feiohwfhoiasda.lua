-- Get ชื่อแมพ
local MarketplaceService = game:GetService("MarketplaceService")

local success, info = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)

local WEBHOOK_URL = "https://discord.com/api/webhooks/1425983248416378954/flB6KwhZsV_n2lxArd2DXZTH8uGf8bFeo71JRCyqidwPHFzZxp3X7lrICHHkOT73J76E"
local MAP_NAME = info.Name

-- SERVICES
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- UTIL: ฟังก์ชันเรียก HTTP ให้รองรับหลาย executor
local function doRequest(req)
    -- synapse
    if syn and syn.request then
        return syn.request(req)
    end
    -- old http
    if http and http.request then
        return http.request(req)
    end
    -- request
    if request then
        return request(req)
    end
    -- Roblox HttpService fallback (ต้องเปิด HttpRequests และมักบน server เท่านั้น)
    if HttpService and HttpService.RequestAsync then
        return HttpService:RequestAsync({
            Url = req.Url,
            Method = req.Method,
            Headers = req.Headers,
            Body = req.Body
        })
    end
end

-- UTIL: ตรวจหา executor name (พยายามหลายวิธี)
local function detectExecutor()
    -- ถ้ามีฟังก์ชัน identifyexecutor (บาง executor ให้มา)
    local ok, res = pcall(function() return (identifyexecutor and identifyexecutor()) or (identifyexecutor and identifyexecutor) end)
    if ok and type(res) == "string" and res ~= "" then
        return res
    end

    -- บาง executor มี global flags
    if syn then return "Synapse X" end
    if KRNL_LOADED or Krnl then return "Krnl" end
    if getexecutorname then
        local ok2, name = pcall(getexecutorname)
        if ok2 and type(name) == "string" then return name end
    end

    -- fallback
    return "Unknown Executor"
end

-- UTIL: อ่าน HWID จาก executor (เรียก gethwid ถ้ามี)
local function getHWID()
    -- พยายามเรียกชื่อฟังก์ชันต่าง ๆ ที่ executor อาจมี
    local hwid
    local tryFns = {
        function() if gethwid then return gethwid() end end,
        function() if getHwId then return getHwId() end end,
        function() if syn and syn.get_hwid then return syn.get_hwid() end end,
        function() if identifyhwid then return identifyhwid() end end,
        function() if getexecutorhwid then return getexecutorhwid() end end,
    }

    for _, fn in ipairs(tryFns) do
        local ok, res = pcall(fn)
        if ok and res and type(res) == "string" and #res > 5 then
            hwid = res
            break
        end
    end

    if not hwid then
        -- ถ้าไม่มีฟังก์ชันจริง ให้ลองหาใน getgenv หรือ _G
        if getgenv and type(getgenv().hwid) == "string" then
            hwid = getgenv().hwid
        elseif _G and type(_G.hwid) == "string" then
            hwid = _G.hwid
        else
            hwid = "UnknownHWID"
        end
    end

    return hwid
end

-- UTIL: persistent counter (ใช้ writefile/readfile ถ้ามี) เก็บไฟล์ใน path 'executor_exec_count.txt'
local COUNTER_FILE = "executor_exec_count.txt"
local function readCounter()
    if isfile and isfile(COUNTER_FILE) and readfile then
        local ok, data = pcall(function() return readfile(COUNTER_FILE) end)
        if ok and data then
            local n = tonumber(data)
            if n then return n end
        end
    end
    -- fallback: เก็บใน getgenv
    if getgenv then
        return getgenv().__executor_exec_count or 0
    end
    return 0
end

local function writeCounter(n)
    if writefile and isfile then
        pcall(function() writefile(COUNTER_FILE, tostring(n)) end)
    elseif writefile then
        pcall(function() writefile(COUNTER_FILE, tostring(n)) end)
    else
        if getgenv then
            getgenv().__executor_exec_count = n
        end
    end
end

-- เพิ่ม counter 1 ครั้งเมื่อรัน
local function incrementCounter()
    local cur = readCounter()
    local nextv = cur + 1
    writeCounter(nextv)
    return nextv
end

-- ส่ง webhook (รองรับ 429 retry)
local function sendWebhookPayload(payload)
    local body = HttpService:JSONEncode(payload)
    local req = {
        Url = WEBHOOK_URL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "Roblox-Executor-Webhook-Client"
        },
        Body = body
    }

    local ok, resp = pcall(function() return doRequest(req) end)
    if not ok then
        warn("Webhook request failed:", resp)
        return false, resp
    end

    -- normalize status
    local status = resp.StatusCode or resp.status or resp.Status or (resp.success and 200) or 0
    local respBody = resp.Body or resp.body or resp.Content or ""

    if tostring(status) == "204" or tostring(status) == "200" then
        return true, resp
    end

    if tostring(status) == "429" then
        -- อ่าน retry_after ถ้าเป็น JSON
        local decoded
        local ok2, dec = pcall(function() return HttpService:JSONDecode(respBody) end)
        if ok2 then decoded = dec end
        local retry_after = decoded and decoded.retry_after or decoded and decoded["retry_after"] or 2000
        local waitSeconds = tonumber(retry_after) and (tonumber(retry_after) > 10 and tonumber(retry_after)/1000 or tonumber(retry_after)) or 2
        warn("Rate limited. Waiting " .. tostring(waitSeconds) .. "s then retrying...")
        wait(waitSeconds)
        return sendWebhookPayload(payload)
    end

    warn("Webhook returned non-OK status:", status, respBody)
    return false, resp
end

-- สร้าง embed ตามฟอร์แมต
local function buildAndSendEmbed()
    -- ข้อมูลผู้เล่นปัจจุบัน
    local localPlayer = Players.LocalPlayer
    local playerName = "@Unknown"
    local playerUserId = "N/A"
    if localPlayer then
        playerName = "@" .. tostring(localPlayer.Name or "Unknown")
        playerUserId = tostring(localPlayer.UserId or "N/A")
    end

    -- ข้อมูลอื่น ๆ
    local jobId = tostring(game.JobId or "N/A")
    local executorName = detectExecutor()
    local hwid = getHWID()
    local execCount = incrementCounter()

    -- BUILD EMBED
    local embed = {
        title = "User executed!",
        description = "มีคนรันสคริปต์ฟรีว่ะ! **น้องน้ำ** **น้องแหลม** และนี่ก็คือรายระเอียดข้อมูลของคนรันสคริปต์ฟรีของเรา ATG Hub 😎",
        color = 0x00AAFF, -- decimal  (Discord accepts decimal; keep within 0..16777215)
        fields = {
            { name = "Status", value = "User executed!", inline = true },
            { name = "Total Executions", value = tostring(execCount) .. " ครั้ง", inline = true },
            { name = "HWID", value = "||" .. tostring(hwid) .. "||", inline = false },
            { name = "Executor", value = executorName, inline = true },
            { name = "Roblox Name", value = playerName .. " (UserId: " .. playerUserId .. ")", inline = false },
            { name = "Job ID", value = jobId, inline = false },
            { name = "Script / Map", value = MAP_NAME, inline = false },
            { name = "Timestamp (UTC)", value = os.date("!%Y-%m-%dT%H:%M:%SZ"), inline = false },
        },
        footer = {
            text = "ATG Hub Webhook Production"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local payload = {
        username = "ATG Hub",
        avatar_url = "https://img5.pic.in.th/file/secure-sv1/remix-77797a08-72e9-4e05-aa86-5bccff462ee2-removebg-preview912aeb8810af98ca.png",
        embeds = { embed }
    }

    local ok, res = sendWebhookPayload(payload)
end

pcall(buildAndSendEmbed)
