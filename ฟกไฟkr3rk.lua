

-- ATG Secure Loader
-- ID: 17255d6d1515d65b
-- ⚠️ This script is protected and can only be executed through Roblox executors

local function checkEnvironment()
    if not game then error("Security: Invalid environment", 0) end
    if not game.HttpGet or not game.GetService then error("Security: Executor required", 0) end
    return true
end

if not pcall(checkEnvironment) then return end

local function decrypt()
    -- ATG Key System - Auto Verify with script_key variable
    -- รองรับการตรวจสอบ script_key อัตโนมัติ
    
    local ATGKeySystem = {}
    
    -- Config
    ATGKeySystem.API_URL = "https://atghub-getkey.atgofficial.net/api/keys"
    ATGKeySystem.WEB_URL = "https://atghub.atgofficial.net/getkey"
    ATGKeySystem.LOGO_URL = "https://img5.pic.in.th/file/secure-sv1/ChatGPT-Image-9-..-2568-00_55_34.png"
    ATGKeySystem.SAVE_FILENAME = "atg_key.txt"
    
    local HttpService = game:GetService("HttpService")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    
    -- Animation Presets
    local ANIMS = {
        fadeIn = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
        slideIn = TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        buttonHover = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        success = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
        shake = TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
    }
    
    -- Helper Functions
    local function createTween(object, tweenInfo, properties)
        local tween = TweenService:Create(object, tweenInfo, properties)
        tween:Play()
        return tween
    end
    
    local function addHoverEffect(button, normalColor, hoverColor, scaleAmount)
        scaleAmount = scaleAmount or UDim2.new(0, 6, 0, 3)
        local originalSize = button.Size
        
        button.MouseEnter:Connect(function()
            createTween(button, ANIMS.buttonHover, {BackgroundColor3 = hoverColor})
            createTween(button, ANIMS.buttonHover, {Size = originalSize + scaleAmount})
        end)
        
        button.MouseLeave:Connect(function()
            createTween(button, ANIMS.buttonHover, {BackgroundColor3 = normalColor})
            createTween(button, ANIMS.buttonHover, {Size = originalSize})
        end)
    end
    
    local function shakeElement(element)
        local originalPos = element.Position
        for i = 1, 4 do
            createTween(element, ANIMS.shake, {Position = originalPos + UDim2.new(0, math.random(-8, 8), 0, 0)})
            wait(0.08)
        end
        createTween(element, ANIMS.shake, {Position = originalPos})
    end
    
    -- ฟังก์ชันดึง script_key จาก environment
    local function getScriptKey()
        -- ลำดับการตรวจสอบ: getgenv > _G > shared
        if getgenv and getgenv().script_key then
            return tostring(getgenv().script_key)
        end
        if _G and _G.script_key then
            return tostring(_G.script_key)
        end
        if shared and shared.script_key then
            return tostring(shared.script_key)
        end
        return nil
    end
    
    -- Executor Detection
    local function detect_executor()
        if syn and syn.request then return "Synapse" end
        if KRNL_LOADED or (typeof(request) == "function" and not syn) then return "KRNL" end
        if fluxus and fluxus.request then return "Fluxus" end
        return "Unknown"
    end
    
    local EXECUTOR = detect_executor()
    
    local function http_request(opts)
        local ok, res
        if syn and syn.request then
            ok, res = pcall(syn.request, opts)
            if ok and res then return res end
        end
        if request then
            ok, res = pcall(request, opts)
            if ok and res then return res end
        end
        if http_request then
            ok, res = pcall(http_request, opts)
            if ok and res then return res end
        end
        if fluxus and fluxus.request then
            ok, res = pcall(fluxus.request, opts)
            if ok and res then return res end
        end
        if (type(http) == "table" and http.request) then
            ok, res = pcall(http.request, opts)
            if ok and res then return res end
        end
        error("No supported HTTP request function found")
    end
    
    local function request_json(method, url, payload)
        local body = nil
        if payload then
            local ok_enc, enc = pcall(function() return HttpService:JSONEncode(payload) end)
            body = ok_enc and enc or tostring(payload)
        end
    
        local req = {
            Url = url,
            Method = method or "GET",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "ATGKeySystem-Client"
            },
            Body = body
        }
    
        local ok, res = pcall(http_request, req)
        if not ok or not res then
            return nil, "HTTP request failed"
        end
    
        local resBody = res.Body or res.body or res[1] or tostring(res)
        local decoded, err = pcall(function() return HttpService:JSONDecode(resBody) end)
        if decoded then
            return HttpService:JSONDecode(resBody)
        else
            return nil, "Failed to decode JSON"
        end
    end
    
    -- HWID Helper
    function ATGKeySystem:GetHWID()
        if (syn and syn.get_hwid) then
            local ok, hw = pcall(syn.get_hwid)
            if ok and hw then return tostring(hw) end
        end
        if gethwid then
            local ok, hw = pcall(gethwid)
            if ok and hw then return tostring(hw) end
        end
        local ok, clientId = pcall(function()
            return game:GetService("RbxAnalyticsService"):GetClientId()
        end)
        if ok and clientId then return tostring(clientId) end
        
        local generated = HttpService:GenerateGUID(false)
        if writefile and isfile then
            pcall(function()
                if not isfile("atg_hwid.txt") then
                    writefile("atg_hwid.txt", generated)
                end
            end)
            local ok, saved = pcall(readfile, "atg_hwid.txt")
            if ok and saved then return tostring(saved) end
        end
        return tostring(generated)
    end
    
    function ATGKeySystem:VerifyKey(key)
        local hwid = self:GetHWID()
        local payload = { key = key, hwid = hwid }
        local res, err = request_json("POST", self.API_URL .. "/verify", payload)
        if not res then
            return { valid = false, message = err or "No response" }
        end
        return res
    end
    
    -- Premium UI Creation with Blur
    function ATGKeySystem:CreateUI()
        -- Remove existing UI if it exists
        local existingUI = game.CoreGui:FindFirstChild("ATGKeySystem")
        if existingUI then
            pcall(function() existingUI:Destroy() end)
            wait(0.1)
        end
    
        local parentGui = game:GetService("CoreGui")
    
        -- Main ScreenGui
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "ATGKeySystem"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.Parent = parentGui
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
        -- Blur Effect using CoreGui
        local BlurEffect = Instance.new("BlurEffect")
        BlurEffect.Size = 0
        BlurEffect.Parent = game:GetService("Lighting")
    
        -- Dark Overlay
        local Overlay = Instance.new("Frame", ScreenGui)
        Overlay.Name = "DarkOverlay"
        Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Overlay.BackgroundTransparency = 1
        Overlay.Size = UDim2.new(1, 0, 1, 0)
        Overlay.ZIndex = 1
    
        -- Main Container
        local MainFrame = Instance.new("Frame", ScreenGui)
        MainFrame.Name = "MainContainer"
        MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        MainFrame.BorderSizePixel = 0
        MainFrame.Position = UDim2.new(0.5, -240, 0.5, -200)
        MainFrame.Size = UDim2.new(0, 480, 0, 400)
        MainFrame.ClipsDescendants = true
        MainFrame.ZIndex = 2
    
        local MainCorner = Instance.new("UICorner", MainFrame)
        MainCorner.CornerRadius = UDim.new(0, 20)
    
        local MainStroke = Instance.new("UIStroke", MainFrame)
        MainStroke.Color = Color3.fromRGB(139, 92, 246)
        MainStroke.Thickness = 1.5
        MainStroke.Transparency = 0.5
    
        -- Animated Gradient Border
        local BorderGradient = Instance.new("Frame", MainFrame)
        BorderGradient.Name = "BorderGlow"
        BorderGradient.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
        BorderGradient.BorderSizePixel = 0
        BorderGradient.Size = UDim2.new(1, 0, 0, 3)
        BorderGradient.ZIndex = 3
    
        local BorderGradientColor = Instance.new("UIGradient", BorderGradient)
        BorderGradientColor.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(139, 92, 246)),
            ColorSequenceKeypoint.new(0.3, Color3.fromRGB(59, 130, 246)),
            ColorSequenceKeypoint.new(0.6, Color3.fromRGB(236, 72, 153)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 92, 246))
        }
    
        -- Header with Logo
        local Header = Instance.new("Frame", MainFrame)
        Header.Name = "Header"
        Header.BackgroundTransparency = 1
        Header.Position = UDim2.new(0, 0, 0, 25)
        Header.Size = UDim2.new(1, 0, 0, 100)
        Header.ZIndex = 3
    
        -- Logo Image
        local LogoImage = Instance.new("ImageLabel", Header)
        LogoImage.BackgroundTransparency = 1
        LogoImage.Position = UDim2.new(0.5, -45, 0, 0)
        LogoImage.Size = UDim2.new(0, 90, 0, 90)
        LogoImage.Image = self.LOGO_URL
        LogoImage.ZIndex = 4
    
        local LogoCorner = Instance.new("UICorner", LogoImage)
        LogoCorner.CornerRadius = UDim.new(0, 16)
    
        -- Title Section
        local TitleContainer = Instance.new("Frame", MainFrame)
        TitleContainer.BackgroundTransparency = 1
        TitleContainer.Position = UDim2.new(0, 0, 0, 135)
        TitleContainer.Size = UDim2.new(1, 0, 0, 60)
        TitleContainer.ZIndex = 3
    
        local Title = Instance.new("TextLabel", TitleContainer)
        Title.BackgroundTransparency = 1
        Title.Size = UDim2.new(1, 0, 0, 28)
        Title.Font = Enum.Font.GothamBold
        Title.Text = "ATG HUB KEY SYSTEM"
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.TextSize = 22
        Title.ZIndex = 3
    
        local Subtitle = Instance.new("TextLabel", TitleContainer)
        Subtitle.BackgroundTransparency = 1
        Subtitle.Position = UDim2.new(0, 0, 0, 32)
        Subtitle.Size = UDim2.new(1, 0, 0, 22)
        Subtitle.Font = Enum.Font.Gotham
        Subtitle.Text = "Enter your Freemium key"
        Subtitle.TextColor3 = Color3.fromRGB(160, 160, 170)
        Subtitle.TextSize = 13
        Subtitle.ZIndex = 3
    
        -- Key Input Section
        local InputContainer = Instance.new("Frame", MainFrame)
        InputContainer.Name = "InputContainer"
        InputContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
        InputContainer.BorderSizePixel = 0
        InputContainer.Position = UDim2.new(0.08, 0, 0, 205)
        InputContainer.Size = UDim2.new(0.84, 0, 0, 55)
        InputContainer.ZIndex = 3
    
        local InputCorner = Instance.new("UICorner", InputContainer)
        InputCorner.CornerRadius = UDim.new(0, 12)
    
        local InputStroke = Instance.new("UIStroke", InputContainer)
        InputStroke.Color = Color3.fromRGB(50, 50, 62)
        InputStroke.Thickness = 2
        InputStroke.Transparency = 0
    
        local KeyIcon = Instance.new("TextLabel", InputContainer)
        KeyIcon.BackgroundTransparency = 1
        KeyIcon.Position = UDim2.new(0, 15, 0, 0)
        KeyIcon.Size = UDim2.new(0, 25, 1, 0)
        KeyIcon.Font = Enum.Font.GothamBold
        KeyIcon.Text = "🔑"
        KeyIcon.TextColor3 = Color3.fromRGB(139, 92, 246)
        KeyIcon.TextSize = 18
        KeyIcon.ZIndex = 4
    
        local KeyBox = Instance.new("TextBox", InputContainer)
        KeyBox.Name = "KeyInput"
        KeyBox.BackgroundTransparency = 1
        KeyBox.Position = UDim2.new(0, 50, 0, 0)
        KeyBox.Size = UDim2.new(1, -60, 1, 0)
        KeyBox.Font = Enum.Font.GothamMedium
        KeyBox.PlaceholderText = "XXXX-XXXX-XXXX-XXXX"
        KeyBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 115)
        KeyBox.Text = ""
        KeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        KeyBox.TextSize = 16
        KeyBox.TextXAlignment = Enum.TextXAlignment.Left
        KeyBox.ZIndex = 4
    
        -- Buttons Container
        local ButtonsContainer = Instance.new("Frame", MainFrame)
        ButtonsContainer.BackgroundTransparency = 1
        ButtonsContainer.Position = UDim2.new(0.08, 0, 0, 275)
        ButtonsContainer.Size = UDim2.new(0.84, 0, 0, 100)
        ButtonsContainer.ZIndex = 3
    
        -- Verify Button
        local VerifyButton = Instance.new("TextButton", ButtonsContainer)
        VerifyButton.Name = "VerifyBtn"
        VerifyButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
        VerifyButton.BorderSizePixel = 0
        VerifyButton.Size = UDim2.new(1, 0, 0, 48)
        VerifyButton.Font = Enum.Font.GothamBold
        VerifyButton.Text = "Redeem Key"
        VerifyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        VerifyButton.TextSize = 16
        VerifyButton.ZIndex = 3
        VerifyButton.AutoButtonColor = false
    
        local VerifyCorner = Instance.new("UICorner", VerifyButton)
        VerifyCorner.CornerRadius = UDim.new(0, 12)
    
        local VerifyGradient = Instance.new("UIGradient", VerifyButton)
        VerifyGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(139, 92, 246)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(99, 102, 241))
        }
        VerifyGradient.Rotation = 90
    
        -- Get Key Button
        local GetKeyButton = Instance.new("TextButton", ButtonsContainer)
        GetKeyButton.Name = "GetKeyBtn"
        GetKeyButton.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
        GetKeyButton.BorderSizePixel = 0
        GetKeyButton.Position = UDim2.new(0, 0, 0, 58)
        GetKeyButton.Size = UDim2.new(1, 0, 0, 42)
        GetKeyButton.Font = Enum.Font.GothamBold
        GetKeyButton.Text = "GET KEY"
        GetKeyButton.TextColor3 = Color3.fromRGB(139, 92, 246)
        GetKeyButton.TextSize = 15
        GetKeyButton.ZIndex = 3
        GetKeyButton.AutoButtonColor = false
    
        local GetKeyCorner = Instance.new("UICorner", GetKeyButton)
        GetKeyCorner.CornerRadius = UDim.new(0, 12)
    
        local GetKeyStroke = Instance.new("UIStroke", GetKeyButton)
        GetKeyStroke.Color = Color3.fromRGB(139, 92, 246)
        GetKeyStroke.Thickness = 2
    
        -- Status Label
        local StatusLabel = Instance.new("TextLabel", MainFrame)
        StatusLabel.Name = "StatusText"
        StatusLabel.BackgroundTransparency = 1
        StatusLabel.Position = UDim2.new(0, 0, 1.02, -30)
        StatusLabel.Size = UDim2.new(1, 0, 0, 22)
        StatusLabel.Font = Enum.Font.GothamMedium
        StatusLabel.Text = "Powered by ATG Hub"
        StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
        StatusLabel.TextSize = 12
        StatusLabel.ZIndex = 3
    
        -- Close Button
        local CloseButton = Instance.new("TextButton", MainFrame)
        CloseButton.Name = "CloseBtn"
        CloseButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
        CloseButton.BackgroundTransparency = 0.85
        CloseButton.BorderSizePixel = 0
        CloseButton.Position = UDim2.new(1, -50, 0, 15)
        CloseButton.Size = UDim2.new(0, 38, 0, 38)
        CloseButton.Font = Enum.Font.GothamBold
        CloseButton.Text = "❌"
        CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        CloseButton.TextSize = 18
        CloseButton.ZIndex = 10
        CloseButton.AutoButtonColor = false
    
        local CloseCorner = Instance.new("UICorner", CloseButton)
        CloseCorner.CornerRadius = UDim.new(1, 0)
    
        -- Initial Animation
        MainFrame.Position = UDim2.new(0.5, -240, 0.5, -280)
        MainFrame.Size = UDim2.new(0, 480, 0, 0)
        
        spawn(function()
            createTween(BlurEffect, ANIMS.fadeIn, {Size = 18})
            createTween(Overlay, ANIMS.fadeIn, {BackgroundTransparency = 0.3})
            wait(0.15)
            createTween(MainFrame, ANIMS.slideIn, {
                Position = UDim2.new(0.5, -240, 0.5, -200),
                Size = UDim2.new(0, 480, 0, 400)
            })
        end)
    
        -- Hover Effects
        addHoverEffect(VerifyButton, Color3.fromRGB(139, 92, 246), Color3.fromRGB(155, 110, 255))
        addHoverEffect(GetKeyButton, Color3.fromRGB(25, 25, 32), Color3.fromRGB(35, 35, 42))
        
        CloseButton.MouseEnter:Connect(function()
            createTween(CloseButton, ANIMS.buttonHover, {BackgroundTransparency = 0})
            createTween(CloseButton, ANIMS.buttonHover, {Rotation = 90})
        end)
        
        CloseButton.MouseLeave:Connect(function()
            createTween(CloseButton, ANIMS.buttonHover, {BackgroundTransparency = 0.85})
            createTween(CloseButton, ANIMS.buttonHover, {Rotation = 0})
        end)
    
        -- Input Focus Effects
        KeyBox.Focused:Connect(function()
            createTween(InputStroke, ANIMS.buttonHover, {Color = Color3.fromRGB(139, 92, 246)})
            createTween(InputStroke, ANIMS.buttonHover, {Thickness = 3})
        end)
    
        KeyBox.FocusLost:Connect(function()
            createTween(InputStroke, ANIMS.buttonHover, {Color = Color3.fromRGB(50, 50, 62)})
            createTween(InputStroke, ANIMS.buttonHover, {Thickness = 2})
        end)
    
        -- Animated Border Gradient
        spawn(function()
            while ScreenGui.Parent and MainFrame.Parent do
                createTween(BorderGradientColor, TweenInfo.new(4, Enum.EasingStyle.Linear), {Offset = Vector2.new(1, 0)})
                wait(4)
                BorderGradientColor.Offset = Vector2.new(-1, 0)
            end
        end)
    
        return {
            ScreenGui = ScreenGui,
            KeyBox = KeyBox,
            VerifyButton = VerifyButton,
            GetKeyButton = GetKeyButton,
            StatusLabel = StatusLabel,
            CloseButton = CloseButton,
            InputStroke = InputStroke,
            MainFrame = MainFrame,
            BlurEffect = BlurEffect
        }
    end
    
    -- Main Init
    function ATGKeySystem:Init(callback)
        callback = callback or function() end
    
        -- ตรวจสอบ script_key จาก environment ก่อน
        local scriptKey = getScriptKey()
        
        if scriptKey and scriptKey ~= "" then
            -- พบ script_key ในตัวแปร - ทำการ verify ทันที
            local ok, result = pcall(function() return self:VerifyKey(scriptKey) end)
            if ok and result and result.valid then
                -- Key ถูกต้อง - บันทึกและ return โดยไม่แสดง UI
                if writefile then
                    pcall(writefile, self.SAVE_FILENAME, scriptKey)
                end
                callback(true, result)
                if getgenv then
                    getgenv().ATG_KeyVerified = true
                elseif _G then
                    _G.ATG_KeyVerified = true
                end
                return
            end
            -- Key ไม่ถูกต้อง - จะแสดง UI ด้านล่าง
        end
    
        -- ตรวจสอบ saved key
        local savedKey = nil
        if isfile and pcall(isfile, self.SAVE_FILENAME) and isfile(self.SAVE_FILENAME) then
            local ok, data = pcall(readfile, self.SAVE_FILENAME)
            if ok and type(data) == "string" and data ~= "" then
                savedKey = data
            end
        end
    
        if savedKey then
            local ok, result = pcall(function() return self:VerifyKey(savedKey) end)
            if ok and result and result.valid then
                callback(true, result)
                if getgenv then
                    getgenv().ATG_KeyVerified = true
                elseif _G then
                    _G.ATG_KeyVerified = true
                end
                return
            end
        end
    
        -- แสดง UI เมื่อไม่มี key หรือ key ไม่ถูกต้อง
        local ui, err = self:CreateUI()
        if not ui then
            callback(false, { message = err or "Failed to create UI" })
            return
        end
    
        ui.VerifyButton.MouseButton1Click:Connect(function()
            local key = ui.KeyBox.Text or ""
            if key == "" then
                ui.StatusLabel.Text = "● Please enter a valid key"
                ui.StatusLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
                shakeElement(ui.KeyBox.Parent)
                return
            end
    
            ui.StatusLabel.Text = "🔬 Verifying key..."
            ui.StatusLabel.TextColor3 = Color3.fromRGB(139, 92, 246)
            ui.VerifyButton.Text = "⏳  VERIFYING..."
    
            spawn(function()
                local ok, result = pcall(function() return self:VerifyKey(key) end)
                if not ok or not result then
                    ui.StatusLabel.Text = "● Connection failed"
                    ui.StatusLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
                    ui.VerifyButton.Text = "✓  VERIFY KEY"
                    shakeElement(ui.MainFrame)
                    return
                end
    
                if result.valid then
                    ui.StatusLabel.Text = "✅ Verified! Valid for " .. tostring(result.remaining_hours or "24") .. " hours"
                    ui.StatusLabel.TextColor3 = Color3.fromRGB(16, 185, 129)
                    ui.VerifyButton.Text = "✅ SUCCESS!"
                    createTween(ui.InputStroke, ANIMS.success, {Color = Color3.fromRGB(16, 185, 129)})
                    createTween(ui.VerifyButton, ANIMS.success, {BackgroundColor3 = Color3.fromRGB(16, 185, 129)})

                    if writefile then
                        pcall(writefile, self.SAVE_FILENAME, key)
                    end

                    wait(0.6)
                    createTween(ui.MainFrame, ANIMS.fadeIn, {Size = UDim2.new(0, 480, 0, 0)})
                    createTween(ui.BlurEffect, ANIMS.fadeIn, {Size = 0})
                    wait(0.4)
                    pcall(function() ui.ScreenGui:Destroy() end)
                    pcall(function() ui.BlurEffect:Destroy() end)
                    callback(true, result)

                    if getgenv then
                        getgenv().ATG_KeyVerified = true
                    elseif _G then
                        _G.ATG_KeyVerified = true
                    end
                else
                    ui.StatusLabel.Text = "● " .. (result.message or "Invalid key")
                    ui.StatusLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
                    ui.VerifyButton.Text = "💎 VERIFY KEY"
                    shakeElement(ui.KeyBox.Parent)
                end
            end)
        end)
    
        ui.GetKeyButton.MouseButton1Click:Connect(function()
            if setclipboard then
                pcall(setclipboard, self.WEB_URL)
                ui.StatusLabel.Text = "● Link copied to clipboard!"
                ui.StatusLabel.TextColor3 = Color3.fromRGB(16, 185, 129)
            else
                ui.StatusLabel.Text = "● Opening website..."
                ui.StatusLabel.TextColor3 = Color3.fromRGB(139, 92, 246)
            end
    
            pcall(function()
                if syn and syn.request then
                    syn.request({Url = self.WEB_URL, Method = "GET"})
                elseif request then
                    request({Url = self.WEB_URL, Method = "GET"})
                end
            end)
        end)
    
        ui.CloseButton.MouseButton1Click:Connect(function()
            createTween(ui.MainFrame, ANIMS.fadeIn, {Size = UDim2.new(0, 480, 0, 0)})
            createTween(ui.BlurEffect, ANIMS.fadeIn, {Size = 0})
            wait(0.3)
            pcall(function() ui.ScreenGui:Destroy() end)
            pcall(function() ui.BlurEffect:Destroy() end)
            callback(false, { message = "User closed the key system" })
        end)
    end
    
    -- Auto-run
    pcall(function()
        if not game:IsLoaded() then
            pcall(function() game.Loaded:Wait() end)
        end
    
        task.spawn(function()
            ATGKeySystem:Init(function(success, data)
                -- Silent operation - no output
            end)
        end)
    end)
    
    return ATGKeySystem
end

pcall(decrypt)
