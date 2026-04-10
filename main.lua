--[[
    Uh's... Chat Tool v3.0 - Silent Edition
    - Foco em exibir bolhas de chat ofuscadas, sem enviar mensagens reais.
    - Mantém o scanner de backdoor para tentar fazer outros jogadores falarem.
--]]

-- ========================================================================= --
-- ||                        1. CONFIGURAÇÃO                                || --
-- ========================================================================= --
local CONFIG = {
    UI = {
        Theme = "Default",
        SaveConfig = true,
        FolderName = "Uh's...Chat",
        FileName = "Settings"
    },
    Bypass = {
        Method = "Advanced" -- "Homoglyph", "ZeroWidth", "Combined", "Advanced"
    },
    Backdoor = {
        AutoScan = true,
        UseBubbleFallback = true
    }
}

-- ========================================================================= --
-- ||                    2. CARREGAR RAYFIELD (MÚLTIPLOS MIRRORS)           || --
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
    warn("Rayfield indisponível. Executando em modo console.")
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
-- ||                        3. SERVIÇOS                                    || --
-- ========================================================================= --
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Chat = game:GetService("Chat")
local LocalPlayer = Players.LocalPlayer

-- ========================================================================= --
-- ||                    4. ENGINE DE BYPASS AVANÇADO                       || --
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
-- ||                    5. GERENCIADOR DE BOLHAS                           || --
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
-- ||                    6. BACKDOOR ENGINE (AUTO‑DESCOBERTA)               || --
-- ========================================================================= --
local Backdoor = {}
Backdoor.Remotes = {}
Backdoor.WorkingRemote = nil
Backdoor.Bypass = nil

function Backdoor:Scan()
    local found = {}
    local function scan(obj, depth)
        if depth > 15 then return end
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                table.insert(found, child)
            end
            scan(child, depth + 1)
        end
    end
    scan(game, 0)

    local commonPaths = {
        ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents"),
        ReplicatedStorage:FindFirstChild("ChatService"),
        game:FindFirstChild("Chat"),
        game:FindFirstChild("ServerScriptService")
    }
    for _, container in ipairs(commonPaths) do
        if container then
            for _, child in ipairs(container:GetDescendants()) do
                if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                    if not table.find(found, child) then
                        table.insert(found, child)
                    end
                end
            end
        end
    end

    self.Remotes = found
    return found
end

function Backdoor:AutoFindAndSetRemote(targetPlayer, message)
    if not targetPlayer then return false, "Nenhum alvo" end
    if not self.Bypass then return false, "Engine de bypass ausente" end

    local testMessage = message or "test"
    local processed = self.Bypass:Process(testMessage)

    local argsVariants = {
        {targetPlayer, processed},
        {processed, targetPlayer},
        {targetPlayer.Name, processed},
        {processed, targetPlayer.Name},
        {targetPlayer.UserId, processed},
        {processed, targetPlayer.UserId},
        {targetPlayer, processed, "All"},
        {"SayMessageRequest", targetPlayer.Name, processed}
    }

    local remotesToTest = self.Remotes
    if #remotesToTest == 0 then
        self:Scan()
        remotesToTest = self.Remotes
    end

    for _, remote in ipairs(remotesToTest) do
        for _, args in ipairs(argsVariants) do
            local success = pcall(function()
                if remote:IsA("RemoteFunction") then
                    remote:InvokeServer(unpack(args))
                else
                    remote:FireServer(unpack(args))
                end
            end)
            if success then
                self.WorkingRemote = remote
                return true, "Backdoor encontrado: " .. remote:GetFullName()
            end
        end
    end

    return false, "Nenhum backdoor funcionou entre " .. #remotesToTest .. " remotes."
end

function Backdoor:ForceSay(player, message)
    if not player or not player:IsA("Instance") then return false, "Jogador inválido" end
    if not self.Bypass then return false, "Engine de bypass ausente" end

    local processed = self.Bypass:Process(message)

    local argsVariants = {
        {player, processed},
        {processed, player},
        {player.Name, processed},
        {processed, player.Name},
        {player.UserId, processed},
        {processed, player.UserId}
    }

    if self.WorkingRemote then
        for _, args in ipairs(argsVariants) do
            local success = pcall(function()
                if self.WorkingRemote:IsA("RemoteFunction") then
                    self.WorkingRemote:InvokeServer(unpack(args))
                else
                    self.WorkingRemote:FireServer(unpack(args))
                end
            end)
            if success then
                return true, "Backdoor usado: " .. self.WorkingRemote:GetFullName()
            end
        end
    end

    local found, result = self:AutoFindAndSetRemote(player, message)
    if found then
        return true, "Novo backdoor: " .. result
    end

    if CONFIG.Backdoor.UseBubbleFallback and player.Character then
        local head = player.Character:FindFirstChild("Head")
        if head then
            pcall(function() TextChatService:DisplayBubble(head, processed) end)
            return true, "Bubble exibido (apenas visual)."
        end
    end

    return false, "Nenhum backdoor encontrado."
end

-- ========================================================================= --
-- ||                        7. CONSTRUÇÃO DA UI                            || --
-- ========================================================================= --
local Window = Rayfield:CreateWindow({
    Name = "Uh's... Chat Tool v3.0",
    LoadingTitle = "Uh's... Chat",
    LoadingSubtitle = "Edição Silenciosa",
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
-- ||                        8. INICIALIZAÇÃO                               || --
-- ========================================================================= --
local Bypass = BypassEngine.new(CONFIG.Bypass.Method)
Backdoor.Bypass = Bypass
local BubbleMgr = BubbleManager.new(Bypass)

local CurrentMessage = ""
local TargetPlayer = nil
local TargetName = ""

if CONFIG.Backdoor.AutoScan then
    local remotes = Backdoor:Scan()
    Rayfield:Notify({
        Title = "Backdoor Scanner",
        Content = #remotes .. " remotes encontrados.",
        Duration = 4
    })
end

-- ========================================================================= --
-- ||                        9. ABAS E ELEMENTOS                            || --
-- ========================================================================= --
local ChatTab = Window:CreateTab("Chat", "message-square")
local SettingsTab = Window:CreateTab("Settings", "settings")

local function UpdatePreview(previewPara)
    if CurrentMessage ~= "" then
        previewPara:Set({Title = "Texto Ofuscado", Content = Bypass:Process(CurrentMessage)})
    else
        previewPara:Set({Title = "Texto Ofuscado", Content = "..."})
    end
end

-- ========================================================================= --
-- ||                        ABA CHAT                                       || --
-- ========================================================================= --
ChatTab:CreateSection("Entrada de Mensagem")
local MsgInput = ChatTab:CreateInput({
    Name = "Sua Mensagem",
    PlaceholderText = "Digite aqui...",
    RemoveTextAfterFocus = false,
    Callback = function(text) CurrentMessage = text or "" end
})

ChatTab:CreateSection("Preview do Bypass")
local PreviewPara = ChatTab:CreateParagraph({Title = "Texto Ofuscado", Content = "..."})
ChatTab:CreateButton({Name = "Atualizar Preview", Callback = function() UpdatePreview(PreviewPara) end})

ChatTab:CreateSection("Ações de Bolha")
ChatTab:CreateButton({
    Name = "Exibir Bolha em Você",
    Callback = function()
        if CurrentMessage == "" then
            Rayfield:Notify({Title = "Erro", Content = "Digite uma mensagem.", Duration = 3})
            return
        end
        local ok = BubbleMgr:DisplayForSelf(CurrentMessage)
        if ok then
            Rayfield:Notify({Title = "Sucesso", Content = "Bolha exibida sobre você!", Duration = 2})
        else
            Rayfield:Notify({Title = "Falha", Content = "Não foi possível exibir a bolha.", Duration = 3})
        end
    end
})

ChatTab:CreateSection("Seleção de Alvo (Para Bolha em Outros)")
local function GetPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    if #names == 0 then names = {"Nenhum jogador online"} end
    return names
end

local TargetDropdown = ChatTab:CreateDropdown({
    Name = "Selecionar Alvo",
    Options = GetPlayerNames(),
    CurrentOption = GetPlayerNames()[1],
    Callback = function(opt)
        local selected = type(opt) == "table" and opt[1] or opt
        if selected and selected ~= "Nenhum jogador online" then
            TargetPlayer = Players:FindFirstChild(selected)
            TargetName = selected
        else
            TargetPlayer = nil
            TargetName = ""
        end
        UpdateTargetInfo()
    end
})

local NameInput = ChatTab:CreateInput({
    Name = "Ou digite o nome exato",
    PlaceholderText = "Username",
    RemoveTextAfterFocus = false,
    Callback = function(text)
        if text and text ~= "" then
            local p = Players:FindFirstChild(text)
            TargetPlayer = p
            TargetName = text
        else
            TargetPlayer = nil
            TargetName = ""
        end
        UpdateTargetInfo()
    end
})

local TargetInfoPara = ChatTab:CreateParagraph({Title = "Alvo Atual", Content = "Nenhum"})
function UpdateTargetInfo()
    if TargetPlayer then
        TargetInfoPara:Set({Title = "Alvo Selecionado", Content = string.format("%s (@%s) | ID: %d", TargetPlayer.Name, TargetPlayer.DisplayName, TargetPlayer.UserId)})
    elseif TargetName ~= "" then
        TargetInfoPara:Set({Title = "Alvo (Offline?)", Content = TargetName .. " - Não encontrado online."})
    else
        TargetInfoPara:Set({Title = "Alvo Atual", Content = "Nenhum"})
    end
end

ChatTab:CreateButton({Name = "Atualizar Lista de Alvos", Callback = function()
    TargetDropdown:Refresh(GetPlayerNames(), true)
    Rayfield:Notify({Title = "Alvos", Content = "Lista atualizada.", Duration = 2})
end})

if GetPlayerNames()[1] ~= "Nenhum jogador online" then
    TargetPlayer = Players:FindFirstChild(GetPlayerNames()[1])
    TargetName = GetPlayerNames()[1]
    UpdateTargetInfo()
end

Players.PlayerAdded:Connect(function() wait(0.5) TargetDropdown:Refresh(GetPlayerNames(), true) end)
Players.PlayerRemoving:Connect(function() wait(0.5) TargetDropdown:Refresh(GetPlayerNames(), true) end)

ChatTab:CreateSection("Ações em Outros Jogadores")
ChatTab:CreateButton({
    Name = "Exibir Bolha no Alvo (Visual)",
    Callback = function()
        if CurrentMessage == "" then Rayfield:Notify({Title = "Erro", Content = "Digite uma mensagem.", Duration = 3}) return end
        if not TargetPlayer then Rayfield:Notify({Title = "Erro", Content = "Selecione um alvo online.", Duration = 3}) return end
        local ok = BubbleMgr:DisplayForPlayer(TargetPlayer, CurrentMessage)
        if ok then Rayfield:Notify({Title = "Sucesso", Content = "Bolha exibida em " .. TargetPlayer.Name, Duration = 2})
        else Rayfield:Notify({Title = "Falha", Content = "Não foi possível exibir a bolha.", Duration = 3}) end
    end
})

ChatTab:CreateButton({
    Name = "Forçar Alvo a Dizer (Backdoor)",
    Callback = function()
        if CurrentMessage == "" then Rayfield:Notify({Title = "Erro", Content = "Digite uma mensagem.", Duration = 3}) return end
        if not TargetPlayer then Rayfield:Notify({Title = "Erro", Content = "Selecione um alvo online.", Duration = 3}) return end
        local success, info = Backdoor:ForceSay(TargetPlayer, CurrentMessage)
        if success then Rayfield:Notify({Title = "Backdoor", Content = info, Duration = 5})
        else Rayfield:Notify({Title = "Falha", Content = info, Duration = 5}) end
    end
})

ChatTab:CreateParagraph({Title = "Nota", Content = "Force Say testa TODOS os remotes. Se falhar, usa bolha visual."})

-- ========================================================================= --
-- ||                        ABA SETTINGS                                   || --
-- ========================================================================= --
SettingsTab:CreateSection("Método de Bypass")
SettingsTab:CreateDropdown({Name = "Método", Options = {"Homoglyph", "ZeroWidth", "Combined", "Advanced"}, CurrentOption = CONFIG.Bypass.Method, Callback = function(opt)
    local method = type(opt) == "table" and opt[1] or opt
    Bypass.Method = method
    CONFIG.Bypass.Method = method
    Rayfield:Notify({Title = "Bypass", Content = "Método alterado para " .. method, Duration = 2})
end})

SettingsTab:CreateSection("Backdoor")
SettingsTab:CreateToggle({Name = "Auto-Scan ao Iniciar", CurrentValue = CONFIG.Backdoor.AutoScan, Callback = function(val) CONFIG.Backdoor.AutoScan = val end})
SettingsTab:CreateToggle({Name = "Usar Bubble Fallback", CurrentValue = CONFIG.Backdoor.UseBubbleFallback, Callback = function(val) CONFIG.Backdoor.UseBubbleFallback = val end})
SettingsTab:CreateButton({Name = "Re-escanear Remotes", Callback = function()
    local remotes = Backdoor:Scan()
    Backdoor.WorkingRemote = nil
    Rayfield:Notify({Title = "Scan Completo", Content = #remotes .. " remotes encontrados.", Duration = 4})
end})

-- ========================================================================= --
-- ||                        10. FINALIZAÇÃO                                || --
-- ========================================================================= --
Rayfield:Notify({Title = "Uh's... Chat Tool v3.0", Content = "Carregado! Use os botões para exibir bolhas.", Duration = 6})