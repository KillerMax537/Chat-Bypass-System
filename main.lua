--[[
    Script: Advanced Chat Bypass + PM System
    Version: 5.0 (Fully Functional)
    Features:
    - Multiple advanced bypass methods (Cyrillic, Greek, Zero-Width, Combining Diacritics, Custom)
    - Fully working tabs: Chat, Players, Bypass Methods, Settings
    - Real-time preview
    - Private messaging with player list
    - Custom character mapping editor
]]

-- Load Rayfield UI (with error handling)
local success, Rayfield = pcall(loadstring(game:HttpGet('https://sirius.menu/rayfield')))
if not success or not Rayfield then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Error",
        Text = "Failed to load Rayfield UI. Check your internet.",
        Duration = 5
    })
    return
end

-- Create main window
local Window = Rayfield:CreateWindow({
    Name = "Advanced Chat Bypass",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by Expert",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AdvancedChatBypass",
        FileName = "Config"
    },
    Discord = { Enabled = false },
    KeySystem = false
})

-- ========================= TABS =========================
local ChatTab = Window:CreateTab("💬 Chat")
local PlayersTab = Window:CreateTab("👥 Players")
local BypassTab = Window:CreateTab("🔓 Bypass Methods")
local SettingsTab = Window:CreateTab("⚙ Settings")

-- ========================= CONFIG =========================
local Config = {
    SelectedPlayer = nil,
    CurrentBypass = "Cyrillic", -- Default method
    CustomMapping = {
        a = "а", b = "Ь", c = "с", e = "е", g = "ɡ", h = "һ",
        i = "і", k = "к", m = "м", n = "п", o = "о", p = "р",
        r = "г", s = "ѕ", t = "т", u = "υ", x = "х", y = "у"
    }
}

-- ========================= ADVANCED BYPASS METHODS =========================
local function cyrillicBypass(text)
    local map = {a="а", b="Ь", c="с", e="е", g="ɡ", h="һ", i="і", k="к", m="м", n="п", o="о", p="р", r="г", s="ѕ", t="т", u="υ", x="х", y="у"}
    return text:gsub("%a", function(ch)
        local lower = ch:lower()
        local mapped = map[lower]
        if mapped then
            return (ch:upper() == ch) and mapped:upper() or mapped
        end
        return ch
    end)
end

local function greekBypass(text)
    local map = {a="α", b="β", c="ϲ", d="δ", e="ε", f="φ", g="γ", h="η", i="ι", k="κ", l="λ", m="μ", n="ν", o="ο", p="π", r="ρ", s="σ", t="τ", u="υ", x="ξ", y="υ", z="ζ"}
    return text:gsub("%a", function(ch)
        local lower = ch:lower()
        local mapped = map[lower]
        if mapped then
            return (ch:upper() == ch) and mapped:upper() or mapped
        end
        return ch
    end)
end

local function zeroWidthBypass(text)
    local zwsp = "\u{200B}"
    return text:gsub(".", "%1" .. zwsp)
end

local function combiningDiacriticsBypass(text)
    local diacritics = {"\u{0300}", "\u{0301}", "\u{0302}", "\u{0303}", "\u{0304}", "\u{0306}", "\u{0307}", "\u{0308}"}
    local result = ""
    for i = 1, #text do
        local char = text:sub(i, i)
        if char:match("%a") then
            result = result .. char .. diacritics[math.random(#diacritics)]
        else
            result = result .. char
        end
    end
    return result
end

local function customMappingBypass(text)
    local result = ""
    for i = 1, #text do
        local char = text:sub(i, i)
        local lower = char:lower()
        if Config.CustomMapping[lower] then
            local mapped = Config.CustomMapping[lower]
            result = result .. (char:upper() == char and mapped:upper() or mapped)
        else
            result = result .. char
        end
    end
    return result
end

-- Main bypass router
local function applyBypass(text)
    if text == "" then return "" end
    if Config.CurrentBypass == "Cyrillic" then
        return cyrillicBypass(text)
    elseif Config.CurrentBypass == "Greek" then
        return greekBypass(text)
    elseif Config.CurrentBypass == "Zero-Width" then
        return zeroWidthBypass(text)
    elseif Config.CurrentBypass == "Combining Diacritics" then
        return combiningDiacriticsBypass(text)
    elseif Config.CurrentBypass == "Custom Mapping" then
        return customMappingBypass(text)
    end
    return text
end

-- ========================= SEND MESSAGE FUNCTION =========================
local function sendMessage(message, isPrivate)
    if message == "" then
        Rayfield:Notify({Title = "Error", Content = "Message cannot be empty", Duration = 3})
        return false
    end
    
    local bypassed = applyBypass(message)
    local finalMsg = bypassed
    
    if isPrivate then
        if not Config.SelectedPlayer then
            Rayfield:Notify({Title = "Error", Content = "Select a player first", Duration = 3})
            return false
        end
        finalMsg = "/w " .. Config.SelectedPlayer.Name .. " " .. bypassed
    end
    
    -- Try TextChatService (new)
    local success = false
    local textChatService = game:GetService("TextChatService")
    local textChannels = textChatService:FindFirstChild("TextChannels")
    if textChannels then
        local channel = textChannels:FindFirstChild("RBXGeneral") or textChannels:FindFirstChild("General")
        if channel then
            local ok = pcall(function() channel:SendAsync(finalMsg) end)
            if ok then success = true end
        end
    end
    
    -- Fallback to legacy Chat
    if not success then
        local ok = pcall(function() game:GetService("Chat"):Chat(finalMsg) end)
        if ok then success = true end
    end
    
    if success then
        Rayfield:Notify({Title = "Success", Content = "Message sent!", Duration = 2})
    else
        Rayfield:Notify({Title = "Error", Content = "Failed to send message", Duration = 4})
    end
    return success
end

-- ========================= CHAT TAB UI =========================
ChatTab:CreateSection("Message")
local messageInput = ChatTab:CreateInput({
    Name = "Your Message",
    PlaceholderText = "Type here...",
    RemoveTextAfterFocus = false,
    Callback = function() end
})

ChatTab:CreateSection("Preview (Bypass Applied)")
local previewLabel = ChatTab:CreateParagraph({
    Name = "",
    Content = "Waiting for message..."
})

messageInput:GetPropertyChangedSignal("Text"):Connect(function()
    local text = messageInput.Text
    if text == "" then
        previewLabel:Set("Waiting for message...")
    else
        previewLabel:Set(applyBypass(text))
    end
end)

ChatTab:CreateSection("Actions")
ChatTab:CreateButton({
    Name = "Send Global",
    Callback = function() sendMessage(messageInput.Text, false) end
})
ChatTab:CreateButton({
    Name = "Send Private Message (PM)",
    Callback = function() sendMessage(messageInput.Text, true) end
})

-- ========================= PLAYERS TAB UI =========================
PlayersTab:CreateSection("Online Players")

local playerDropdown = PlayersTab:CreateDropdown({
    Name = "Select Player",
    Options = {"Loading..."},
    CurrentOption = "Loading...",
    Callback = function(option)
        for _, p in ipairs(game.Players:GetPlayers()) do
            if p.Name == option then
                Config.SelectedPlayer = p
                selectedLabel:Set("Selected: " .. p.Name)
                break
            end
        end
    end
})

local selectedLabel = PlayersTab:CreateParagraph({
    Name = "Current Selection",
    Content = "No player selected"
})

local function updatePlayerList()
    local players = {}
    local localPlayer = game.Players.LocalPlayer
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= localPlayer then
            table.insert(players, p.Name)
        end
    end
    if #players == 0 then players = {"No other players"} end
    playerDropdown:SetOptions(players)
    
    if Config.SelectedPlayer and not table.find(players, Config.SelectedPlayer.Name) then
        Config.SelectedPlayer = nil
        selectedLabel:Set("No player selected")
    elseif Config.SelectedPlayer then
        selectedLabel:Set("Selected: " .. Config.SelectedPlayer.Name)
    end
end

updatePlayerList()
game.Players.PlayerAdded:Connect(updatePlayerList)
game.Players.PlayerRemoving:Connect(updatePlayerList)

PlayersTab:CreateButton({
    Name = "Refresh List",
    Callback = function()
        updatePlayerList()
        Rayfield:Notify({Title = "Info", Content = "Player list updated", Duration = 2})
    end
})

-- ========================= BYPASS METHODS TAB UI =========================
BypassTab:CreateSection("Select Bypass Technique")

local methodDropdown = BypassTab:CreateDropdown({
    Name = "Bypass Method",
    Options = {"Cyrillic", "Greek", "Zero-Width", "Combining Diacritics", "Custom Mapping"},
    CurrentOption = "Cyrillic",
    Callback = function(option)
        Config.CurrentBypass = option
        -- Update preview in Chat tab
        local text = messageInput.Text
        if text ~= "" then
            previewLabel:Set(applyBypass(text))
        end
        Rayfield:Notify({Title = "Bypass", Content = "Method set to " .. option, Duration = 2})
    end
})

BypassTab:CreateSection("Custom Mapping Editor")
BypassTab:CreateParagraph({
    Name = "Instructions",
    Content = "Format: letter=replacement,letter2=replacement2\nExample: a=а,b=ь,c=с"
})

local mappingInput = BypassTab:CreateInput({
    Name = "Mapping String",
    PlaceholderText = "a=а,b=ь,c=с,e=е,o=о,p=р",
    RemoveTextAfterFocus = false,
    Callback = function(text)
        local newMapping = {}
        for pair in string.gmatch(text, "([^,]+)") do
            local key, val = pair:match("^(%a)=(.*)$")
            if key and val then
                newMapping[key:lower()] = val
            end
        end
        if next(newMapping) then
            Config.CustomMapping = newMapping
            Rayfield:Notify({Title = "Custom Mapping", Content = "Updated successfully", Duration = 2})
            -- Update preview if custom method is active
            if Config.CurrentBypass == "Custom Mapping" then
                local text = messageInput.Text
                if text ~= "" then
                    previewLabel:Set(applyBypass(text))
                end
            end
        else
            Rayfield:Notify({Title = "Error", Content = "Invalid format. Use letter=value,letter2=value2", Duration = 4})
        end
    end
})

BypassTab:CreateButton({
    Name = "Load Default Mapping",
    Callback = function()
        Config.CustomMapping = {
            a = "а", b = "Ь", c = "с", e = "е", g = "ɡ", h = "һ",
            i = "і", k = "к", m = "м", n = "п", o = "о", p = "р",
            r = "г", s = "ѕ", t = "т", u = "υ", x = "х", y = "у"
        }
        mappingInput:Set("a=а,b=Ь,c=с,e=е,g=ɡ,h=һ,i=і,k=к,m=м,n=п,o=о,p=р,r=г,s=ѕ,t=т,u=υ,x=х,y=у")
        Rayfield:Notify({Title = "Custom Mapping", Content = "Default mapping loaded", Duration = 2})
        if Config.CurrentBypass == "Custom Mapping" then
            local text = messageInput.Text
            if text ~= "" then
                previewLabel:Set(applyBypass(text))
            end
        end
    end
})

-- ========================= SETTINGS TAB UI =========================
SettingsTab:CreateSection("About")
SettingsTab:CreateParagraph({
    Name = "Advanced Chat Bypass System",
    Content = "Version 5.0 (2026)\nFully functional with multiple bypass techniques.\n\nCyrillic - Uses Russian homoglyphs\nGreek - Uses Greek homoglyphs\nZero-Width - Invisible spaces between characters\nCombining Diacritics - Adds accents to letters\nCustom Mapping - User-defined character replacement"
})

SettingsTab:CreateSection("Warning")
SettingsTab:CreateParagraph({
    Name = "Disclaimer",
    Content = "Bypassing chat filters violates Roblox Terms of Service. Use at your own risk. This script is for educational purposes only."
})

SettingsTab:CreateButton({
    Name = "Test Bypass (send 'hello world')",
    Callback = function()
        sendMessage("hello world", false)
    end
})

-- Final notification
Rayfield:Notify({
    Title = "Advanced Chat Bypass",
    Content = "All tabs are working! Select a bypass method and start chatting.",
    Duration = 6
})