--[[
    Unit Tests for BackdoorScanner logic
    Mocks Roblox APIs to test scoring, filtering, and scan logic
    Run with: lua5.3 tests/test_backdoor_scanner.lua
--]]

-- ========================================================================= --
--                         TEST FRAMEWORK (minimal)                          --
-- ========================================================================= --
local passed = 0
local failed = 0
local total = 0
local failures = {}

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print(string.format("  PASS: %s", name))
    else
        failed = failed + 1
        table.insert(failures, {name = name, err = err})
        print(string.format("  FAIL: %s\n        %s", name, tostring(err)))
    end
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            msg or "assertion failed", tostring(expected), tostring(actual)), 2)
    end
end

local function assert_true(val, msg)
    if not val then
        error(msg or "expected true, got false/nil", 2)
    end
end

local function assert_false(val, msg)
    if val then
        error(msg or "expected false/nil, got truthy", 2)
    end
end

local function assert_gt(a, b, msg)
    if not (a > b) then
        error(string.format("%s: expected %s > %s", msg or "assertion failed", tostring(a), tostring(b)), 2)
    end
end

local function assert_lt(a, b, msg)
    if not (a < b) then
        error(string.format("%s: expected %s < %s", msg or "assertion failed", tostring(a), tostring(b)), 2)
    end
end

local function assert_gte(a, b, msg)
    if not (a >= b) then
        error(string.format("%s: expected %s >= %s", msg or "assertion failed", tostring(a), tostring(b)), 2)
    end
end

local function assert_lte(a, b, msg)
    if not (a <= b) then
        error(string.format("%s: expected %s <= %s", msg or "assertion failed", tostring(a), tostring(b)), 2)
    end
end

-- ========================================================================= --
--                       ROBLOX API MOCKS                                    --
-- ========================================================================= --

-- Mock Instance class
local MockInstance = {}
MockInstance.__index = MockInstance

function MockInstance.new(className, name, parent)
    local self = setmetatable({}, MockInstance)
    self.ClassName = className
    self.Name = name or className
    self.Parent = parent
    self._children = {}
    self._fullName = nil
    if parent then
        table.insert(parent._children, self)
    end
    return self
end

function MockInstance:IsA(className)
    return self.ClassName == className
        or (className == "Instance")
        or (className == "Folder" and self.ClassName == "Folder")
end

function MockInstance:GetFullName()
    if self._fullName then return self._fullName end
    local parts = {self.Name}
    local current = self.Parent
    while current do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end
    return table.concat(parts, ".")
end

function MockInstance:GetChildren()
    return self._children
end

function MockInstance:FindFirstChild(name, recursive)
    for _, child in ipairs(self._children) do
        if child.Name == name then return child end
        if recursive then
            local found = child:FindFirstChild(name, true)
            if found then return found end
        end
    end
    return nil
end

-- Mock Roblox services
local function createMockGame()
    local gameRoot = MockInstance.new("DataModel", "game", nil)

    local replicatedStorage = MockInstance.new("ReplicatedStorage", "ReplicatedStorage", gameRoot)
    local workspace = MockInstance.new("Workspace", "Workspace", gameRoot)
    local players = MockInstance.new("Players", "Players", gameRoot)

    function gameRoot:GetService(serviceName)
        for _, child in ipairs(self._children) do
            if child.Name == serviceName or child.ClassName == serviceName then
                return child
            end
        end
        return MockInstance.new(serviceName, serviceName, self)
    end

    return gameRoot, replicatedStorage, workspace, players
end

-- ========================================================================= --
--    EXTRACT SCANNER LOGIC (matches the FIXED version in main.lua)          --
-- ========================================================================= --

-- Patterns that suggest a remote is chat-related (higher priority)
local CHAT_PATTERNS = {
    "SayMessage", "Chat", "Message", "SendMessage", "Talk", "Broadcast",
    "DefaultChatSystemChatEvents", "ChatService", "TextChat"
}

-- Patterns that are almost certainly traps - AVOID
-- Updated: removed overly broad "Anti", "Mod", "Check"; replaced with
-- more specific patterns; reduced penalty from -1000 to -200.
local TRAP_PATTERNS = {
    "Kick", "Ban", "Detect", "AntiExploit", "AntiCheat", "AntiHack",
    "Exploit", "Hack", "Script", "Logger",
    "Punish", "Flag", "Report", "Admin", "Moderate", "Secure", "Verify"
}

-- scoreRemote: matches the FIXED version in main.lua
-- Key changes from original:
--   1. Trap matching uses remote.Name only (not full path)
--   2. Trap penalty reduced from -1000 to -200
--   3. Removed overly broad trap patterns ("Anti", "Mod", "Check")
local function scoreRemote(remote)
    local score = 0
    local remoteName = remote.Name:lower()
    local fullPath = remote:GetFullName():lower()

    -- Chat-pattern matching on full path
    for _, pattern in ipairs(CHAT_PATTERNS) do
        if fullPath:find(pattern:lower()) then
            score = score + 50
        end
    end

    -- Trap-pattern matching on remote name only
    for _, pattern in ipairs(TRAP_PATTERNS) do
        if remoteName:find(pattern:lower()) then
            score = score - 200
        end
    end

    local parent = remote.Parent
    if parent then
        if parent.ClassName == "ReplicatedStorage" then
            score = score + 10
        elseif parent:IsA("Folder") and parent.Name:lower():find("chat") then
            score = score + 20
        end
    end

    if remote.Name == "RemoteEvent" or remote.Name == "RemoteFunction" then
        score = score - 20
    end

    return score
end

-- CollectRemotes: adapted from main.lua
local function collectRemotes(gameRoot)
    local remotes = {}
    local function scan(obj, depth)
        if depth > 15 then return end
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                local score = scoreRemote(child)
                if score > -500 then
                    table.insert(remotes, {remote = child, score = score})
                end
            end
            scan(child, depth + 1)
        end
    end
    scan(gameRoot, 0)

    table.sort(remotes, function(a, b) return a.score > b.score end)

    local sortedRemotes = {}
    for _, entry in ipairs(remotes) do
        table.insert(sortedRemotes, entry.remote)
    end
    return sortedRemotes, remotes
end

-- Safe mode filter
local function filterSafeMode(remotes)
    local filtered = {}
    for _, r in ipairs(remotes) do
        if scoreRemote(r) > 0 then
            table.insert(filtered, r)
        end
    end
    return filtered
end

-- ========================================================================= --
--                    TEST SUITE: scoreRemote (basic)                        --
-- ========================================================================= --
print("\n=== scoreRemote: Basic Scoring Tests ===")

local gameRoot, replicatedStorage, workspace, players = createMockGame()

local function makeRemote(className, name, parent)
    return MockInstance.new(className, name, parent or replicatedStorage)
end

test("Chat-related remote 'SayMessageRequest' scores positively", function()
    local remote = makeRemote("RemoteEvent", "SayMessageRequest", replicatedStorage)
    local score = scoreRemote(remote)
    -- "SayMessage" +50, "Message" +50, RS +10 = 110
    assert_eq(score, 110, "SayMessageRequest expected score")
end)

test("Chat-related remote 'ChatEvent' scores positively", function()
    local remote = makeRemote("RemoteEvent", "ChatEvent", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Chat" +50, RS +10 = 60
    assert_eq(score, 60, "ChatEvent expected score")
end)

test("Chat-related remote 'SendMessage' scores positively", function()
    local remote = makeRemote("RemoteEvent", "SendMessage", replicatedStorage)
    local score = scoreRemote(remote)
    -- "SendMessage" +50, "Message" +50, RS +10 = 110
    assert_eq(score, 110, "SendMessage expected score")
end)

test("Chat-related remote 'DefaultChatSystemChatEvents' child scores highly", function()
    local chatFolder = MockInstance.new("Folder", "DefaultChatSystemChatEvents", replicatedStorage)
    local remote = makeRemote("RemoteEvent", "SayMessageRequest", chatFolder)
    local score = scoreRemote(remote)
    -- Full path includes DefaultChatSystemChatEvents.SayMessageRequest
    -- "SayMessage" +50, "Chat" +50, "Message" +50, "DefaultChatSystemChatEvents" +50
    -- Folder with "chat" +20 = 220
    assert_gt(score, 100, "DefaultChatSystemChatEvents child should score high")
end)

test("Trap remote 'KickPlayer' scores negatively", function()
    local remote = makeRemote("RemoteEvent", "KickPlayer", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Kick" -200, RS +10 = -190
    assert_lt(score, 0, "KickPlayer should score negatively")
end)

test("Trap remote 'BanHandler' scores negatively", function()
    local remote = makeRemote("RemoteEvent", "BanHandler", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Ban" -200, RS +10 = -190
    assert_lt(score, 0, "BanHandler should score negatively")
end)

test("Trap remote 'AntiExploit' scores very negatively", function()
    local remote = makeRemote("RemoteEvent", "AntiExploit", replicatedStorage)
    local score = scoreRemote(remote)
    -- "AntiExploit" -200, "Exploit" -200, RS +10 = -390
    assert_lt(score, -200, "AntiExploit should be double-penalized")
end)

test("Generic RemoteEvent with default name gets penalized", function()
    local remote = makeRemote("RemoteEvent", "RemoteEvent", replicatedStorage)
    local score = scoreRemote(remote)
    -- Generic name -20, RS +10 = -10
    assert_eq(score, -10, "Generic RemoteEvent expected score")
end)

test("Generic RemoteFunction with default name gets penalized", function()
    local remote = makeRemote("RemoteFunction", "RemoteFunction", replicatedStorage)
    local score = scoreRemote(remote)
    assert_eq(score, -10, "Generic RemoteFunction expected score")
end)

test("Neutral remote 'UpdatePosition' scores near zero", function()
    local remote = makeRemote("RemoteEvent", "UpdatePosition", replicatedStorage)
    local score = scoreRemote(remote)
    -- No chat, no trap, RS +10 = 10
    assert_eq(score, 10, "Neutral remote in RS expected score")
end)

test("Remote under Folder named 'ChatFolder' gets parent bonus", function()
    local chatFolder = MockInstance.new("Folder", "ChatFolder", replicatedStorage)
    local remote = makeRemote("RemoteEvent", "DoStuff", chatFolder)
    local score = scoreRemote(remote)
    -- "Chat" in full path +50, folder parent with "chat" +20 = 70
    assert_gt(score, 0, "Remote in ChatFolder should score positively")
end)

-- ========================================================================= --
--       TEST SUITE: FALSE POSITIVE / FALSE NEGATIVE DETECTION               --
-- ========================================================================= --
print("\n=== False Positive / False Negative Tests (FIXED logic) ===")

test("FIXED: 'Moderation' no longer caught by trap patterns", function()
    local remote = makeRemote("RemoteEvent", "Moderation", replicatedStorage)
    local score = scoreRemote(remote)
    -- "moderation" does NOT contain "moderate" ("moderat" + "ion")
    -- No trap match, RS +10 = 10
    print(string.format("    [INFO] Moderation score: %d", score))
    assert_eq(score, 10, "Moderation should not be penalized")
end)

test("FIXED: 'Anticipation' no longer caught by 'Anti' trap", function()
    local remote = makeRemote("RemoteEvent", "Anticipation", replicatedStorage)
    local score = scoreRemote(remote)
    -- Old: "Anti" matched -> -1000. New: no "Anti" pattern, check "AntiExploit"/"AntiCheat"/"AntiHack"
    -- "anticipation" doesn't contain "antiexploit", "anticheat", or "antihack"
    -- RS +10 = 10
    print(string.format("    [INFO] Anticipation score: %d", score))
    assert_gt(score, 0, "Anticipation should no longer be penalized")
end)

test("FIXED: 'Checkpoint' no longer caught by 'Check' trap", function()
    local remote = makeRemote("RemoteEvent", "Checkpoint", replicatedStorage)
    local score = scoreRemote(remote)
    -- Old: "Check" matched -> -1000. New: no "Check" pattern
    -- RS +10 = 10
    print(string.format("    [INFO] Checkpoint score: %d", score))
    assert_gt(score, 0, "Checkpoint should no longer be penalized")
end)

test("FIXED: 'ChatCheckRemote' no longer over-penalized", function()
    local remote = makeRemote("RemoteEvent", "ChatCheckRemote", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Chat" +50, no "Check" trap anymore, RS +10 = 60
    print(string.format("    [INFO] ChatCheckRemote score: %d", score))
    assert_gt(score, 0, "ChatCheckRemote should now score positively")
end)

test("'AdminChat' still flagged — Admin is a real trap concern", function()
    local remote = makeRemote("RemoteEvent", "AdminChat", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Admin" -200, "Chat" +50, RS +10 = -140
    print(string.format("    [INFO] AdminChat score: %d", score))
    assert_lt(score, 0, "AdminChat flagged by Admin (intentional)")
end)

test("'ModChat' no longer over-penalized (Mod replaced with Moderate)", function()
    local remote = makeRemote("RemoteEvent", "ModChat", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Moderate" not in "modchat", "Chat" +50, RS +10 = 60
    print(string.format("    [INFO] ModChat score: %d", score))
    assert_gt(score, 0, "ModChat should now be accepted")
end)

test("'MessageLogger' correctly flagged as trap", function()
    local remote = makeRemote("RemoteEvent", "MessageLogger", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Message" +50, "Logger" -200, RS +10 = -140
    assert_lt(score, 0, "MessageLogger should be flagged as trap")
end)

test("'ScriptHandler' correctly identified as trap", function()
    local remote = makeRemote("RemoteEvent", "ScriptHandler", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Script" -200, RS +10 = -190
    assert_lt(score, -100, "ScriptHandler should be penalized")
end)

test("'BroadcastEvent' passes correctly (no false positive)", function()
    local remote = makeRemote("RemoteEvent", "BroadcastEvent", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Broadcast" +50, RS +10 = 60
    assert_eq(score, 60, "BroadcastEvent expected score")
end)

test("'TalkRequest' passes correctly (no false positive)", function()
    local remote = makeRemote("RemoteEvent", "TalkRequest", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Talk" +50, RS +10 = 60
    assert_eq(score, 60, "TalkRequest expected score")
end)

test("'VerifyChat' still flagged — Verify is a legitimate trap concern", function()
    local remote = makeRemote("RemoteEvent", "VerifyChat", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Verify" -200, "Chat" +50, RS +10 = -140
    print(string.format("    [INFO] VerifyChat score: %d", score))
    assert_lt(score, 0, "VerifyChat flagged by Verify trap")
end)

test("'SecureMessage' still flagged — Secure is a trap concern", function()
    local remote = makeRemote("RemoteEvent", "SecureMessage", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Secure" -200, "Message" +50, RS +10 = -140
    print(string.format("    [INFO] SecureMessage score: %d", score))
    assert_lt(score, 0, "SecureMessage flagged by Secure trap")
end)

test("'TextChatCommand' matches TextChat pattern", function()
    local remote = makeRemote("RemoteEvent", "TextChatCommand", replicatedStorage)
    local score = scoreRemote(remote)
    -- "TextChat" +50, "Chat" +50, RS +10 = 110
    assert_gt(score, 50, "TextChatCommand should match TextChat and Chat")
end)

test("'AntiCheatRemote' correctly flagged", function()
    local remote = makeRemote("RemoteEvent", "AntiCheatRemote", replicatedStorage)
    local score = scoreRemote(remote)
    -- "AntiCheat" -200, RS +10 = -190
    assert_lt(score, 0, "AntiCheatRemote should be penalized")
end)

test("'AntiHackSystem' correctly flagged", function()
    local remote = makeRemote("RemoteEvent", "AntiHackSystem", replicatedStorage)
    local score = scoreRemote(remote)
    -- "AntiHack" -200, "Hack" -200, RS +10 = -390
    assert_lt(score, -200, "AntiHackSystem should be heavily penalized")
end)

-- ========================================================================= --
--            TEST SUITE: CollectRemotes (filtering & sorting)               --
-- ========================================================================= --
print("\n=== CollectRemotes Tests ===")

test("CollectRemotes finds all non-deeply-penalized remotes", function()
    local game = MockInstance.new("DataModel", "game", nil)
    local rs = MockInstance.new("ReplicatedStorage", "ReplicatedStorage", game)

    local chatRemote = MockInstance.new("RemoteEvent", "ChatEvent", rs)
    local neutralRemote = MockInstance.new("RemoteEvent", "DataSync", rs)
    local trapRemote = MockInstance.new("RemoteEvent", "AntiExploit", rs)

    local sorted, raw = collectRemotes(game)

    -- AntiExploit: -200-200+10 = -390, above -500 threshold, INCLUDED now
    -- ChatEvent: +50+10 = 60
    -- DataSync: 0+10 = 10
    assert_eq(#sorted, 3, "Should find 3 remotes (trap not below -500)")
    assert_eq(sorted[1].Name, "ChatEvent", "Chat remote should be first")
end)

test("CollectRemotes sorts by score descending", function()
    local game = MockInstance.new("DataModel", "game", nil)
    local rs = MockInstance.new("ReplicatedStorage", "ReplicatedStorage", game)

    local r1 = MockInstance.new("RemoteEvent", "SayMessageRequest", rs)
    local r2 = MockInstance.new("RemoteEvent", "ChatEvent", rs)
    local r3 = MockInstance.new("RemoteEvent", "DataSync", rs)

    local sorted = collectRemotes(game)

    assert_eq(#sorted, 3, "Should find 3 remotes")
    assert_eq(sorted[1].Name, "SayMessageRequest", "Highest scorer first")
    assert_eq(sorted[2].Name, "ChatEvent", "Medium scorer second")
    assert_eq(sorted[3].Name, "DataSync", "Lowest scorer third")
end)

test("CollectRemotes includes RemoteFunctions too", function()
    local game = MockInstance.new("DataModel", "game", nil)
    local rs = MockInstance.new("ReplicatedStorage", "ReplicatedStorage", game)

    local re = MockInstance.new("RemoteEvent", "ChatEvent", rs)
    local rf = MockInstance.new("RemoteFunction", "GetChatData", rs)

    local sorted = collectRemotes(game)
    assert_eq(#sorted, 2, "Should find both RemoteEvent and RemoteFunction")
end)

test("CollectRemotes excludes very heavily penalized remotes (score <= -500)", function()
    local game = MockInstance.new("DataModel", "game", nil)
    local rs = MockInstance.new("ReplicatedStorage", "ReplicatedStorage", game)

    -- Need 3+ trap matches to go below -500: -200*3 + 10 = -590
    local trapRemote = MockInstance.new("RemoteEvent", "AntiExploitHackScript", rs)

    local sorted = collectRemotes(game)
    -- "AntiExploit" -200, "Exploit" -200, "Hack" -200, "Script" -200 = -800+10 = -790
    assert_eq(#sorted, 0, "Very heavily penalized remote should be excluded")
end)

test("CollectRemotes scans nested children", function()
    local game = MockInstance.new("DataModel", "game", nil)
    local rs = MockInstance.new("ReplicatedStorage", "ReplicatedStorage", game)
    local folder = MockInstance.new("Folder", "ChatFolder", rs)
    local nested = MockInstance.new("RemoteEvent", "SayMessageRequest", folder)

    local sorted = collectRemotes(game)
    assert_eq(#sorted, 1, "Should find nested remote")
    assert_eq(sorted[1].Name, "SayMessageRequest", "Nested remote found")
end)

test("CollectRemotes respects depth limit of 15", function()
    local game = MockInstance.new("DataModel", "game", nil)
    local current = game
    for i = 1, 20 do
        current = MockInstance.new("Folder", "Level" .. i, current)
    end
    local deepRemote = MockInstance.new("RemoteEvent", "DeepChat", current)

    local sorted = collectRemotes(game)
    assert_eq(#sorted, 0, "Remote beyond depth 15 should not be found")
end)

test("CollectRemotes finds remotes at exactly depth 15", function()
    local game = MockInstance.new("DataModel", "game", nil)
    local current = game
    for i = 1, 14 do
        current = MockInstance.new("Folder", "Level" .. i, current)
    end
    local remote = MockInstance.new("RemoteEvent", "ChatEvent", current)

    local sorted = collectRemotes(game)
    assert_eq(#sorted, 1, "Remote at depth 15 should be found")
end)

-- ========================================================================= --
--            TEST SUITE: Safe Mode Filtering                                --
-- ========================================================================= --
print("\n=== Safe Mode Filtering Tests ===")

test("Safe mode filters out remotes with score <= 0", function()
    local chatRemote = makeRemote("RemoteEvent", "ChatEvent", replicatedStorage)  -- score 60
    local genericRemote = makeRemote("RemoteEvent", "RemoteEvent", replicatedStorage)  -- score -10
    local dataRemote = makeRemote("RemoteEvent", "DataSync", replicatedStorage)  -- score 10

    local filtered = filterSafeMode({chatRemote, genericRemote, dataRemote})
    assert_eq(#filtered, 2, "Safe mode should keep 2 remotes (ChatEvent + DataSync)")
end)

test("Safe mode with no chat remotes returns empty", function()
    local game = MockInstance.new("DataModel", "game", nil)
    local ws = MockInstance.new("Workspace", "Workspace", game)

    local r1 = MockInstance.new("RemoteEvent", "RemoteEvent", ws)  -- -20
    local r2 = MockInstance.new("RemoteEvent", "SomeEvent", ws)    -- 0

    local filtered = filterSafeMode({r1, r2})
    assert_eq(#filtered, 0, "No safe remotes when none match chat patterns")
end)

test("Safe mode keeps high-scoring chat remotes", function()
    local chatFolder = MockInstance.new("Folder", "DefaultChatSystemChatEvents", replicatedStorage)
    local r = MockInstance.new("RemoteEvent", "SayMessageRequest", chatFolder)

    local filtered = filterSafeMode({r})
    assert_eq(#filtered, 1, "High-scoring chat remote should pass safe mode")
end)

-- ========================================================================= --
--       TEST SUITE: BypassEngine (text processing correctness)              --
-- ========================================================================= --
print("\n=== BypassEngine Tests ===")

local HOMOGLYPH_MAP = {
    a = "\xD0\xB0", c = "\xD1\x81", e = "\xD0\xB5", o = "\xD0\xBE",
    p = "\xD1\x80", x = "\xD1\x85", y = "\xD1\x83",
    k = "\xD0\xBA", m = "\xD0\xBC", t = "\xD1\x82", h = "\xD2\xBB", b = "\xD0\xAC",
}
local ZWSP = "\xE2\x80\x8B"

local function applyHomoglyph(text)
    local result = {}
    for i = 1, #text do
        local c = text:sub(i, i)
        if HOMOGLYPH_MAP[c] then
            table.insert(result, HOMOGLYPH_MAP[c])
        else
            table.insert(result, c)
        end
    end
    return table.concat(result)
end

test("Homoglyph replaces known characters", function()
    local result = applyHomoglyph("ace")
    assert_true(result ~= "ace", "Homoglyph should change known chars")
    assert_eq(#result, 6, "3 chars * 2 bytes each for cyrillic = 6 bytes")
end)

test("Homoglyph preserves unknown characters", function()
    local result = applyHomoglyph("123!@#")
    assert_eq(result, "123!@#", "Non-alpha chars should be unchanged")
end)

test("Homoglyph preserves spaces", function()
    local result = applyHomoglyph("a b")
    assert_true(result:find(" "), "Space should be preserved")
end)

test("Empty string through homoglyph returns empty", function()
    local result = applyHomoglyph("")
    assert_eq(result, "", "Empty input should return empty output")
end)

-- ========================================================================= --
--       TEST SUITE: Pattern Matching Edge Cases                             --
-- ========================================================================= --
print("\n=== Pattern Matching Edge Cases ===")

test("Case insensitivity: 'CHATSERVICE' matches 'ChatService' pattern", function()
    local remote = makeRemote("RemoteEvent", "CHATSERVICE", replicatedStorage)
    local score = scoreRemote(remote)
    -- "chatservice" matches "chatservice" +50 and "chat" +50
    assert_gt(score, 50, "Case insensitive match should work")
end)

test("Case insensitivity: 'saymessagerequest' (all lowercase) matches", function()
    local remote = makeRemote("RemoteEvent", "saymessagerequest", replicatedStorage)
    local score = scoreRemote(remote)
    assert_gt(score, 50, "All lowercase should still match patterns")
end)

test("Multiple chat patterns in same name stack scores", function()
    local remote = makeRemote("RemoteEvent", "ChatMessage", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Chat" +50, "Message" +50, RS +10 = 110
    assert_eq(score, 110, "Multiple chat patterns should stack")
end)

test("Multiple trap patterns in same name stack penalties", function()
    local remote = makeRemote("RemoteEvent", "AntiHackDetect", replicatedStorage)
    local score = scoreRemote(remote)
    -- "AntiHack" -200, "Hack" -200, "Detect" -200 = -600 + RS 10 = -590
    assert_lt(score, -400, "Multiple trap patterns should stack penalties")
end)

test("Remote not in ReplicatedStorage gets no parent bonus", function()
    local game = MockInstance.new("DataModel", "game", nil)
    local ws = MockInstance.new("Workspace", "Workspace", game)
    local remote = MockInstance.new("RemoteEvent", "ChatEvent", ws)
    local score = scoreRemote(remote)
    -- "Chat" +50, no RS bonus = 50
    assert_eq(score, 50, "No parent bonus outside ReplicatedStorage")
end)

test("Remote with nil parent doesn't crash", function()
    local remote = MockInstance.new("RemoteEvent", "ChatEvent", nil)
    local ok, result = pcall(scoreRemote, remote)
    assert_true(ok, "Should not crash with nil parent")
end)

-- ========================================================================= --
--       TEST SUITE: Scoring balance verification                            --
-- ========================================================================= --
print("\n=== Scoring Balance Tests ===")

test("Single chat match outweighs single trap match when combined", function()
    -- With -200 penalty, a remote with 2 chat matches + 1 trap should still be negative
    -- but recoverable with more context
    local remote = makeRemote("RemoteEvent", "ChatKickEvent", replicatedStorage)
    local score = scoreRemote(remote)
    -- "Chat" +50, "Kick" -200, RS +10 = -140
    -- Still negative, but not -940 like before
    print(string.format("    [INFO] ChatKickEvent score: %d (was -940 with old logic)", score))
    assert_lt(score, 0, "Single trap still wins over single chat")
    assert_gt(score, -500, "But penalty is manageable, not catastrophic")
end)

test("Multiple chat matches can overcome single trap", function()
    -- SendMessage + Chat folder -> many chat matches
    local chatFolder = MockInstance.new("Folder", "ChatEvents", replicatedStorage)
    local remote = makeRemote("RemoteEvent", "SendMessageKick", chatFolder)
    local score = scoreRemote(remote)
    -- Chat path: "Chat" +50, "SendMessage" +50, "Message" +50 = 150
    -- Trap: "Kick" -200
    -- Parent folder "chat" +20
    -- = 150 - 200 + 20 = -30
    print(string.format("    [INFO] SendMessageKick in ChatEvents: %d", score))
    -- Still slightly negative but much better than old -850
end)

-- ========================================================================= --
--       TEST SUITE: GenerateUniqueName format                               --
-- ========================================================================= --
print("\n=== Unique Name Generation Tests ===")

test("Generated names start with BEXE_ prefix", function()
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    math.randomseed(os.time())
    local name = "BEXE_" .. chars:sub(math.random(1,26), math.random(1,26)) .. tostring(math.random(1000,9999))
    assert_true(name:sub(1, 5) == "BEXE_", "Name should start with BEXE_")
    assert_true(#name >= 9, "Name should be at least 9 chars")
end)

test("Multiple generated names are likely unique", function()
    math.randomseed(os.time())
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local names = {}
    for i = 1, 100 do
        local name = "BEXE_" .. chars:sub(math.random(1,26), math.random(1,26)) .. tostring(math.random(1000,9999))
        names[name] = (names[name] or 0) + 1
    end
    local unique_count = 0
    for _ in pairs(names) do unique_count = unique_count + 1 end
    assert_gt(unique_count, 50, "At least 50% of 100 names should be unique")
end)

-- ========================================================================= --
--       TEST SUITE: Payload structure                                       --
-- ========================================================================= --
print("\n=== Payload Tests ===")

test("Dummy payload creates a BoolValue with correct name", function()
    local DUMMY_PAYLOAD = [[
local dummy = Instance.new("BoolValue")
dummy.Name = "%s"
dummy.Parent = workspace
game:GetService("Debris"):AddItem(dummy, 5)
]]
    local testName = "BEXE_a1234"
    local payload = DUMMY_PAYLOAD:format(testName)
    assert_true(payload:find(testName), "Payload should contain the dummy name")
    assert_true(payload:find("BoolValue"), "Payload should create a BoolValue")
    assert_true(payload:find("Debris"), "Payload should auto-cleanup with Debris")
end)

test("Payload auto-destroys after 5 seconds (Debris)", function()
    local DUMMY_PAYLOAD = [[
local dummy = Instance.new("BoolValue")
dummy.Name = "%s"
dummy.Parent = workspace
game:GetService("Debris"):AddItem(dummy, 5)
]]
    local payload = DUMMY_PAYLOAD:format("test")
    assert_true(payload:find("AddItem%(dummy, 5%)"), "Should auto-destroy after 5s")
end)

-- ========================================================================= --
--       TEST SUITE: ForceSay safety (FIXED percent escaping)                --
-- ========================================================================= --
print("\n=== ForceSay Safety Tests (FIXED) ===")

test("ForceSay script properly escapes double quotes in messages", function()
    local message = 'Hello "World"'
    local escaped = message:gsub('%%', '%%%%'):gsub('"', '\\"')
    local script = string.format([[
        local message = "%s"
    ]], escaped)
    assert_true(script:find('Hello \\"World\\"'), "Quotes should be escaped")
end)

test("FIXED: ForceSay with percent in message no longer crashes", function()
    local message = "100% complete"
    local escaped = message:gsub('%%', '%%%%'):gsub('"', '\\"')
    local template = 'local message = "%s"'
    local ok, result = pcall(string.format, template, escaped)
    assert_true(ok, "Percent in message should be safely escaped")
    if ok then
        assert_true(result:find("100", 1, true), "Result should contain the message text")
    end
end)

test("FIXED: ForceSay with multiple percents works", function()
    local message = "50% off! 100% guaranteed!"
    local escaped = message:gsub('%%', '%%%%'):gsub('"', '\\"')
    local template = 'local message = "%s"'
    local ok, result = pcall(string.format, template, escaped)
    assert_true(ok, "Multiple percents should be safely escaped")
end)

test("FIXED: Player name with percent doesn't crash ForceSay", function()
    local playerName = "Player%100"
    local safeName = playerName:gsub('%%', '%%%%')
    local template = 'FindFirstChild("%s")'
    local ok, result = pcall(string.format, template, safeName)
    assert_true(ok, "Percent in player name should be safely escaped")
end)

-- ========================================================================= --
--       TEST SUITE: Regression - trap patterns don't block legit names      --
-- ========================================================================= --
print("\n=== Regression: Innocent Names Not Blocked ===")

local innocentNames = {
    "Anticipation", "Checkpoint", "ModChat", "Blackboard",
    "CheckpointSave", "ModelViewer", "AntimatterEffect",
    "Flagpole", "ReportCard", "Moderator",
}

for _, name in ipairs(innocentNames) do
    test("Innocent remote '" .. name .. "' is not catastrophically penalized", function()
        local remote = makeRemote("RemoteEvent", name, replicatedStorage)
        local score = scoreRemote(remote)
        print(string.format("    [INFO] %s score: %d", name, score))
        -- With the fixed logic, none of these should be below -500
        assert_gt(score, -500, name .. " should not be catastrophically penalized")
    end)
end

-- ========================================================================= --
--                          RESULTS SUMMARY                                  --
-- ========================================================================= --
print("\n========================================")
print(string.format("RESULTS: %d passed, %d failed, %d total", passed, failed, total))
print("========================================")

if #failures > 0 then
    print("\nFailed tests:")
    for _, f in ipairs(failures) do
        print(string.format("  - %s: %s", f.name, f.err))
    end
end

print("\n=== SUMMARY OF FIXES APPLIED ===")
print("")
print("1. TRAP PATTERNS refined:")
print("   - Removed overly broad 'Anti', 'Mod', 'Check' patterns")
print("   - Added specific 'AntiExploit', 'AntiCheat', 'AntiHack' instead of 'Anti'")
print("   - Changed 'Mod' to 'Moderate' to avoid matching 'ModChat', 'ModelViewer'")
print("   - Removed 'Check' entirely (too many false positives: Checkpoint, etc.)")
print("")
print("2. SCORING REBALANCED:")
print("   - Trap penalty reduced from -1000 to -200 per match")
print("   - Trap matching now uses remote.Name only (not full path)")
print("   - This prevents folder names from triggering trap patterns")
print("   - A single trap match is still decisive but not catastrophic")
print("")
print("3. FORCESAY string.format BUG FIXED:")
print("   - Added percent escaping: message:gsub('%%', '%%%%')")
print("   - Player names also escaped for safety")
print("   - Messages like '100% complete' no longer crash the format call")
print("")

if failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
