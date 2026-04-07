--[[
    Script: Chat Bypass + PM com Rayfield UI (v6.0 - Advanced)
    Date: 2026
    Purpose: Educational and testing purposes only
    Changelog: Enhanced error handling, advanced bypass methods, optimized performance
]]

-- ========================= INITIALIZATION =========================
local SUCCESS = true
local ERROR_MSG = ""

local function safeLoad()
    local ok, result = pcall(function()
        return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)
    if not ok then
        SUCCESS = false
        ERROR_MSG = "Failed to load Rayfield UI"
        error(ERROR_MSG)
    end
    return result
end

local Rayfield = safeLoad()

-- Create main window
local Window = Rayfield:CreateWindow({
    Name = "Advanced Chat Bypass System v6.0",
    LoadingTitle = "Initializing...",
    LoadingSubtitle = "Advanced Mode",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ChatBypassSystem_Advanced",
        FileName = "Config_v6"
    },
    Discord = { Enabled = false },
    KeySystem = false
})

-- Create tabs
local MainTab = Window:CreateTab("Messages")
local PlayersTab = Window:CreateTab("Players")
local SettingsTab = Window:CreateTab("Settings")
local DebugTab = Window:CreateTab("Debug")

-- ========================= CONFIGURATION & STATE =========================
local CONFIG = {
    bypassMethod = 1,      -- 1: Cyrillic, 2: Zero-Width, 3: Combined, 4: Unicode, 5: Advanced
    selectedPlayer = nil,
    messageHistory = {},
    maxHistory = 50,
    autoUpdateInterval = 5,
    enableDebug = false,
    enableNotifications = true,
    messageDelay = 0.1,  -- Delay between messages to prevent rate limiting
}

-- Cache for performance
local CACHE = {
    players = {},
    lastUpdate = 0,
    updateInterval = 2,
}

-- ========================= UTILITY FUNCTIONS =========================
local function debug_log(message)
    if CONFIG.enableDebug then
        print("[ChatBypass Debug] " .. tostring(message))
    end
end

local function validate_input(text)
    if type(text) ~= "string" then
        return false, "Invalid input type"
    end
    if #text == 0 then
        return false, "Message is empty"
    end
    if #text > 3000 then
        return false, "Message is too long (max 3000 characters)"
    end
    return true, text
end

local function safe_notify(title, content, duration)
    if not CONFIG.enableNotifications then return end
    local ok, err = pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3
        })
    end)
    if not ok then
        debug_log("Notification failed: " .. tostring(err))
    end
end

-- ========================= ADVANCED BYPASS METHODS =========================
local BYPASS_METHODS = {
    -- Method 1: Cyrillic substitution
    cyrillic = function(text)
        local map = {
            a="а", e="е", o="о", p="р", c="с", x="х", y="у", k="к", m="м", t="т",
            A="А", E="Е", O="О", P="Р", C="С", X="Х", Y="У", K="К", M="М", T="Т"
        }
        return text:gsub("[a-zA-Z]", function(c)
            return map[c] or c
        end)
    end,

    -- Method 2: Zero-Width spaces (classic)
    zeroWidth = function(text)
        return text:gsub(".", function(c)
            return c .. "\u{200B}"
        end)
    end,

    -- Method 3: Combined (Cyrillic + Zero-Width)
    combined = function(text)
        local map = {
            a="а", e="е", o="о", p="р", c="с", x="х", y="у", k="к", m="м", t="т",
            A="А", E="Е", O="О", P="Р", C="С", X="Х", Y="У", K="К", M="М", T="Т"
        }
        local bypassed = text:gsub("[a-zA-Z]", function(c)
            return map[c] or c
        end)
        return bypassed:gsub(".", function(c)
            return c .. "\u{200B}"
        end)
    end,

    -- Method 4: Unicode mixing (advanced)
    unicode = function(text)
        local result = ""
        for i = 1, #text do
            local char = text:sub(i, i)
            if char:match("[a-zA-Z]") then
                local code = char:byte()
                result = result .. char .. "\u{0301}" .. "\u{0308}"  -- Combining accents
            else
                result = result .. char
            end
        end
        return result
    end,

    -- Method 5: Reverse + Cyrillic (advanced evasion)
    advanced = function(text)
        local map = {
            a="а", e="е", o="о", p="р", c="с", x="х", y="у", k="к", m="м", t="т",
            A="А", E="Е", O="О", P="Р", C="С", X="Х", Y="У", K="К", M="М", T="Т"
        }
        local bypassed = text:gsub("[a-zA-Z]", function(c)
            return map[c] or c
        end)
        -- Add invisible markers
        bypassed = bypassed:gsub(".", function(c)
            return c .. "\u{200B}" .. "\u{200C}" .. "\u{200D}"
        end)
        return bypassed
    end,

    -- Method 6: Latin homoglyphs (visually similar characters)
    homoglyphs = function(text)
        local homoglyph_map = {
            o="о", O="О", p="р", P="Р", c="с", C="С", x="х", X="Х",
            e="е", E="Е", a="а", A="А", y="у", Y="У", k="к", K="К",
            m="м", M="М", t="т", T="Т", n="п", N="П"
        }
        return text:gsub("[a-zA-Z]", function(c)
            return homoglyph_map[c] or c
        end)
    end
}

local function apply_bypass(text, method_id)
    local valid, msg = validate_input(text)
    if not valid then
        return nil, msg
    end

    method_id = method_id or CONFIG.bypassMethod
    
    local methods = {"cyrillic", "zeroWidth", "combined", "unicode", "advanced", "homoglyphs"}
    local method_name = methods[method_id] or "cyrillic"
    
    local ok, result = pcall(function()
        return BYPASS_METHODS[method_name](text)
    end)

    if not ok then
        debug_log("Bypass failed for method " .. method_name .. ": " .. tostring(result))
        return nil, "Bypass method failed"
    end

    table.insert(CONFIG.messageHistory, {
        original = text,
        bypassed = result,
        method = method_name,
        timestamp = os.time()
    })

    if #CONFIG.messageHistory > CONFIG.maxHistory then
        table.remove(CONFIG.messageHistory, 1)
    end

    return result, nil
end

-- ========================= ADVANCED MESSAGE SENDING SYSTEM =========================
local CHAT_SERVICES = {}

-- Initialize chat services
local function init_chat_services()
    local services = {}
    
    -- TextChatService (modern)
    local textChatService = game:GetService("TextChatService")
    if textChatService then
        services.textChat = {
            service = textChatService,
            available = true,
            priority = 1
        }
    end

    -- Legacy Chat
    local chatService = game:FindService("Chat")
    if chatService then
        services.legacyChat = {
            service = chatService,
            available = true,
            priority = 2
        }
    end

    return services
end

CHAT_SERVICES = init_chat_services()

local function send_via_text_chat(message)
    if not CHAT_SERVICES.textChat or not CHAT_SERVICES.textChat.available then
        return false, "TextChatService not available"
    end

    local ok, err = pcall(function()
        local textChannels = CHAT_SERVICES.textChat.service:FindFirstChild("TextChannels")
        if not textChannels then
            return false, "TextChannels not found"
        end

        local generalChannel = textChannels:FindFirstChild("RBXGeneral")
        if not generalChannel then
            return false, "RBXGeneral channel not found"
        end

        generalChannel:SendAsync(message)
        return true
    end)

    if not ok then
        debug_log("TextChatService error: " .. tostring(err))
        return false, err
    end

    return true, nil
end

local function send_via_legacy_chat(message)
    if not CHAT_SERVICES.legacyChat or not CHAT_SERVICES.legacyChat.available then
        return false, "Legacy Chat not available"
    end

    local ok, err = pcall(function()
        CHAT_SERVICES.legacyChat.service:Chat(message)
        return true
    end)

    if not ok then
        debug_log("Legacy Chat error: " .. tostring(err))
        return false, err
    end

    return true, nil
end

local send_queue = {}
local is_sending = false

local function process_send_queue()
    if is_sending or #send_queue == 0 then
        return
    end

    is_sending = true
    local message_data = table.remove(send_queue, 1)

    local ok, err = pcall(function()
        local message = message_data.message
        local is_private = message_data.isPrivate

        -- Try methods in priority order
        local success = false

        if send_via_text_chat(message) then
            success = true
        elseif send_via_legacy_chat(message) then
            success = true
        end

        if success then
            safe_notify("Success", "Message sent!", 2)
            debug_log("Message sent: " .. message:sub(1, 50) .. "...")
        else
            safe_notify("Error", "Failed to send message via all methods", 5)
        end
    end)

    if not ok then
        debug_log("Send queue processing error: " .. tostring(err))
        safe_notify("Error", "Fatal error sending message", 5)
    end

    is_sending = false

    if #send_queue > 0 then
        task.wait(CONFIG.messageDelay)
        process_send_queue()
    end
end

local function queue_message(message, isPrivate)
    table.insert(send_queue, {
        message = message,
        isPrivate = isPrivate,
        timestamp = os.time()
    })
    if #send_queue <= 5 then
        process_send_queue()
    end
end

local function send_message(message, isPrivate)
    -- Validate input
    local valid, validation_msg = validate_input(message)
    if not valid then
        safe_notify("Error", validation_msg, 3)
        return
    end

    -- Apply bypass
    local bypassed, bypass_err = apply_bypass(message)
    if not bypassed then
        safe_notify("Error", "Bypass failed: " .. (bypass_err or "Unknown error"), 5)
        return
    end

    -- Format final message
    local finalMessage = bypassed
    if isPrivate then
        if not CONFIG.selectedPlayer then
            safe_notify("Error", "Please select a player for PM", 3)
            return
        end
        finalMessage = "/w " .. CONFIG.selectedPlayer.Name .. " " .. bypassed
    end

    -- Queue the message
    queue_message(finalMessage, isPrivate)
end

-- ========================= UI: MAIN MESSAGES TAB =========================
local MessageInput = MainTab:CreateInput({
    Name = "Message",
    PlaceholderText = "Enter your message here...",
    RemoveTextAfterFocus = false,
    Callback = function() end
})

local PreviewLabel = MainTab:CreateParagraph({
    Name = "Bypass Preview",
    Content = "Waiting for input..."
})

-- Live preview with error handling
MessageInput:GetPropertyChangedSignal("Text"):Connect(function()
    local text = MessageInput.Text
    if text == "" then
        PreviewLabel:Set("Waiting for input...")
    else
        local valid, msg = validate_input(text)
        if not valid then
            PreviewLabel:Set("❌ " .. msg)
        else
            local bypassed, err = apply_bypass(text)
            if bypassed then
                PreviewLabel:Set(bypassed)
            else
                PreviewLabel:Set("❌ Bypass failed: " .. (err or "Unknown"))
            end
        end
    end
end)

MainTab:CreateButton({
    Name = "📤 Send Global Message",
    Callback = function()
        send_message(MessageInput.Text, false)
        MessageInput.Text = ""
    end
})

MainTab:CreateButton({
    Name = "💬 Send Private Message (PM)",
    Callback = function()
        send_message(MessageInput.Text, true)
        MessageInput.Text = ""
    end
})

MainTab:CreateDivider()

MainTab:CreateParagraph({
    Name = "Message Queue",
    Content = "Queued: 0"
})

-- Update queue counter
spawn(function()
    while true do
        task.wait(1)
        if MainTab then
            debug_log("Current queue size: " .. #send_queue)
        end
    end
end)

-- ========================= UI: PLAYERS TAB =========================
local PlayersDropdown = PlayersTab:CreateDropdown({
    Name = "Select a Player",
    Options = {"Loading..."},
    CurrentOption = "Loading...",
    Callback = function(Option)
        local ok, err = pcall(function()
            for _, player in ipairs(game.Players:GetPlayers()) do
                if player.Name == Option then
                    CONFIG.selectedPlayer = player
                    SelectedLabel:Set("Selected: " .. player.Name .. " ✓")
                    debug_log("Selected player: " .. player.Name)
                    break
                end
            end
        end)
        if not ok then
            debug_log("Player selection error: " .. tostring(err))
        end
    end
})

local SelectedLabel = PlayersTab:CreateParagraph({
    Name = "Selected Player",
    Content = "No player selected"
})

local PlayerCountLabel = PlayersTab:CreateParagraph({
    Name = "Player Count",
    Content = "Waiting for data..."
})

-- Advanced player list management with debouncing
local update_debounce = false

local function update_player_list()
    if update_debounce then return end
    update_debounce = true

    local ok, err = pcall(function()
        local players = {}
        local localPlayer = game.Players.LocalPlayer

        if not localPlayer then
            debug_log("Local player not found")
            return
        end

        for _, player in ipairs(game.Players:GetPlayers()) do
            if player ~= localPlayer and player.Name then
                table.insert(players, player.Name)
            end
        end

        if #players == 0 then
            players = {"No players available"}
        end

        -- Only update if list changed
        if table.concat(players, ",") ~= table.concat(CACHE.players, ",") then
            CACHE.players = players
            PlayersDropdown:SetOptions(players)
            debug_log("Player list updated: " .. #players .. " players")
        end

        -- Validate selected player still exists
        if CONFIG.selectedPlayer then
            local found = false
            for _, p in ipairs(game.Players:GetPlayers()) do
                if p == CONFIG.selectedPlayer then
                    found = true
                    break
                end
            end
            if not found then
                CONFIG.selectedPlayer = nil
                SelectedLabel:Set("No player selected (player left)")
            end
        end

        PlayerCountLabel:Set("Players online: " .. #game.Players:GetPlayers())
    end)

    if not ok then
        debug_log("Player list update error: " .. tostring(err))
    end

    task.wait(0.5)
    update_debounce = false
end

-- Initial load
update_player_list()

-- Optimized event connections
game.Players.PlayerAdded:Connect(function()
    task.wait(0.1)
    update_player_list()
end)

game.Players.PlayerRemoving:Connect(function()
    update_player_list()
end)

-- Periodic update with smart interval
spawn(function()
    while true do
        task.wait(CONFIG.autoUpdateInterval)
        update_player_list()
    end
end)

PlayersTab:CreateButton({
    Name = "🔄 Refresh Player List Now",
    Callback = function()
        update_player_list()
        safe_notify("Info", "Player list refreshed!", 2)
    end
})

-- ========================= UI: SETTINGS TAB =========================
SettingsTab:CreateDropdown({
    Name = "Bypass Method",
    Options = {"Cyrillic", "Zero-Width Spaces", "Combined", "Unicode Accents", "Advanced Evasion", "Homoglyphs"},
    CurrentOption = "Cyrillic",
    Callback = function(Option)
        local methods = {
            ["Cyrillic"] = 1,
            ["Zero-Width Spaces"] = 2,
            ["Combined"] = 3,
            ["Unicode Accents"] = 4,
            ["Advanced Evasion"] = 5,
            ["Homoglyphs"] = 6
        }
        CONFIG.bypassMethod = methods[Option] or 1
        
        -- Update preview
        if MessageInput.Text ~= "" then
            local bypassed, err = apply_bypass(MessageInput.Text)
            if bypassed then
                PreviewLabel:Set(bypassed)
            end
        end
        
        safe_notify("Configuration", "Bypass method changed to " .. Option, 2)
        debug_log("Bypass method set to: " .. Option .. " (ID: " .. CONFIG.bypassMethod .. ")")
    end
})

SettingsTab:CreateDivider()

SettingsTab:CreateSlider({
    Name = "Message Delay (ms)",
    Min = 10,
    Max = 1000,
    Increment = 10,
    CurrentValue = CONFIG.messageDelay * 1000,
    Flag = "MessageDelay",
    Callback = function(Value)
        CONFIG.messageDelay = Value / 1000
        debug_log("Message delay set to: " .. Value .. "ms")
    end
})

SettingsTab:CreateSlider({
    Name = "Auto-Update Interval (s)",
    Min = 2,
    Max = 30,
    Increment = 1,
    CurrentValue = CONFIG.autoUpdateInterval,
    Flag = "UpdateInterval",
    Callback = function(Value)
        CONFIG.autoUpdateInterval = Value
        debug_log("Update interval set to: " .. Value .. "s")
    end
})

SettingsTab:CreateDivider()

SettingsTab:CreateToggle({
    Name = "Enable Notifications",
    CurrentValue = CONFIG.enableNotifications,
    Flag = "EnableNotifications",
    Callback = function(Value)
        CONFIG.enableNotifications = Value
        debug_log("Notifications " .. (Value and "enabled" or "disabled"))
    end
})

SettingsTab:CreateToggle({
    Name = "Enable Debug Logging",
    CurrentValue = CONFIG.enableDebug,
    Flag = "EnableDebug",
    Callback = function(Value)
        CONFIG.enableDebug = Value
        debug_log("Debug logging " .. (Value and "enabled" or "disabled"))
    end
})

SettingsTab:CreateDivider()

SettingsTab:CreateButton({
    Name = "🔄 Refresh Player List",
    Callback = function()
        update_player_list()
        safe_notify("Info", "Player list updated!", 2)
    end
})

SettingsTab:CreateButton({
    Name = "📋 Clear Message History",
    Callback = function()
        CONFIG.messageHistory = {}
        safe_notify("Info", "Message history cleared!", 2)
    end
})

SettingsTab:CreateParagraph({
    Name = "System Information",
    Content = "Advanced Chat Bypass v6.0 - Educational Use\nTextChatService: " .. 
              (CHAT_SERVICES.textChat and "✓" or "✗") .. 
              "\nLegacy Chat: " .. 
              (CHAT_SERVICES.legacyChat and "✓" or "✗")
})

-- ========================= UI: DEBUG TAB =========================
local DebugOutputLabel = DebugTab:CreateParagraph({
    Name = "System Status",
    Content = "System initialized and ready"
})

DebugTab:CreateButton({
    Name = "📊 Refresh System Status",
    Callback = function()
        local status = "System Status:\n" ..
                       "Messages in queue: " .. #send_queue .. "\n" ..
                       "History entries: " .. #CONFIG.messageHistory .. "\n" ..
                       "Bypass method: " .. CONFIG.bypassMethod .. "\n" ..
                       "Players online: " .. #game.Players:GetPlayers()
        DebugOutputLabel:Set(status)
    end
})

DebugTab:CreateButton({
    Name = "🧪 Test Message (Global)",
    Callback = function()
        send_message("Test message - bypass system working!", false)
    end
})

DebugTab:CreateButton({
    Name = "📝 Show Message History",
    Callback = function()
        local history = "Recent messages (" .. #CONFIG.messageHistory .. "):\n"
        for i = math.max(1, #CONFIG.messageHistory - 4), #CONFIG.messageHistory do
            local entry = CONFIG.messageHistory[i]
            history = history .. "\n[" .. entry.method .. "] " .. entry.original:sub(1, 30) .. "..."
        end
        DebugOutputLabel:Set(history)
    end
})

DebugTab:CreateDivider()

DebugTab:CreateParagraph({
    Name = "Bypass Methods Available",
    Content = "1. Cyrillic - Character substitution\n" ..
              "2. Zero-Width - Invisible character insertion\n" ..
              "3. Combined - Cyrillic + Zero-Width\n" ..
              "4. Unicode - Combining diacritics\n" ..
              "5. Advanced - Multi-layer evasion\n" ..
              "6. Homoglyphs - Visually similar chars"
})

-- ========================= STARTUP & INITIALIZATION =========================
do
    local ok, err = pcall(function()
        debug_log("Chat Bypass System v6.0 initialized")
        debug_log("Bypass methods available: " .. table.concat({"cyrillic", "zeroWidth", "combined", "unicode", "advanced", "homoglyphs"}, ", "))
        debug_log("TextChatService: " .. (CHAT_SERVICES.textChat and "Available" or "Not available"))
        debug_log("Legacy Chat: " .. (CHAT_SERVICES.legacyChat and "Available" or "Not available"))
    end)
    
    if not ok then
        debug_log("Initialization error: " .. tostring(err))
    end
end

-- Safe startup notification
task.wait(0.5)
Rayfield:Notify({
    Title = "Advanced Chat Bypass System v6.0",
    Content = "🚀 Loaded successfully!\n" ..
              "📊 Features: " .. (#CHAT_SERVICES.textChat and "TextChat " or "") .. 
              (#CHAT_SERVICES.legacyChat and "Legacy Chat " or "") ..
              "\n💡 Use responsibly",
    Duration = 5
})

-- Cleanup on exit
game:BindToClose(function()
    debug_log("Script closing - cleaning up...")
    send_queue = {}
    CONFIG.messageHistory = {}
end)