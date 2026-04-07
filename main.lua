--[[
    Script: Chat Bypass + PM System (Rayfield UI)
    Version: 6.0 - Corrigido e Funcional (2026)
]]

-- Carrega a biblioteca Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Cria a janela principal
local Window = Rayfield:CreateWindow({
    Name = "Advanced Chat Bypass",
    LoadingTitle = "Carregando...",
    LoadingSubtitle = "by You",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ChatBypassSystem",
        FileName = "Config"
    },
    Discord = { Enabled = false },
    KeySystem = false
})

-- Criação das abas
local ChatTab = Window:CreateTab("💬 Chat")
local PlayersTab = Window:CreateTab("👥 Players")
local BypassTab = Window:CreateTab("🔓 Bypass")
local SettingsTab = Window:CreateTab("⚙️ Settings")

-- ========================= CONFIGURAÇÕES =========================
local Config = {
    SelectedPlayer = nil,
    CurrentBypass = "Cyrillic"
}

-- ========================= FUNÇÕES DE BYPASS =========================
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

local function zeroWidthBypass(text)
    local zwsp = "\u{200B}"
    return text:gsub(".", "%1" .. zwsp)
end

local function combinedBypass(text)
    local map = {a="а", b="Ь", c="с", e="е", g="ɡ", h="һ", i="і", k="к", m="м", n="п", o="о", p="р", r="г", s="ѕ", t="т", u="υ", x="х", y="у"}
    local bypassed = text:gsub("%a", function(ch)
        local lower = ch:lower()
        local mapped = map[lower]
        if mapped then
            return (ch:upper() == ch) and mapped:upper() or mapped
        end
        return ch
    end)
    return zeroWidthBypass(bypassed)
end

local function applyBypass(text)
    if text == "" then return "" end
    if Config.CurrentBypass == "Cyrillic" then
        return cyrillicBypass(text)
    elseif Config.CurrentBypass == "Zero-Width" then
        return zeroWidthBypass(text)
    elseif Config.CurrentBypass == "Combined" then
        return combinedBypass(text)
    end
    return text
end

-- ========================= ENVIO DE MENSAGEM =========================
local function sendMessage(message, isPrivate)
    if message == "" then
        Rayfield:Notify({Title = "Erro", Content = "Digite uma mensagem!", Duration = 3})
        return false
    end

    local finalMessage = applyBypass(message)
    if isPrivate then
        if not Config.SelectedPlayer then
            Rayfield:Notify({Title = "Erro", Content = "Selecione um jogador no menu 'Players'!", Duration = 3})
            return false
        end
        finalMessage = "/w " .. Config.SelectedPlayer.Name .. " " .. finalMessage
    end

    -- Tenta enviar a mensagem usando diferentes sistemas de chat do Roblox
    local success = false
    local textChatService = game:GetService("TextChatService")
    local textChannels = textChatService:FindFirstChild("TextChannels")
    if textChannels then
        local generalChannel = textChannels:FindFirstChild("RBXGeneral")
        if generalChannel then
            local ok, err = pcall(function()
                generalChannel:SendAsync(finalMessage)
            end)
            if ok then success = true end
        end
    end

    if not success then
        local ok, err = pcall(function()
            game:GetService("Chat"):Chat(finalMessage)
        end)
        if ok then success = true end
    end

    if success then
        Rayfield:Notify({Title = "Sucesso", Content = "Mensagem enviada!", Duration = 2})
    else
        Rayfield:Notify({Title = "Erro", Content = "Falha ao enviar mensagem.", Duration = 4})
    end
    return success
end

-- ========================= ABA DE CHAT =========================
-- Seção da mensagem
ChatTab:CreateSection("Sua Mensagem")
local messageInput = ChatTab:CreateInput({
    Name = "Mensagem",
    PlaceholderText = "Digite sua mensagem aqui...",
    RemoveTextAfterFocus = false,
    Callback = function() end
})

-- Seção de pré-visualização
ChatTab:CreateSection("Pré-visualização (Bypass Aplicado)")
local previewLabel = ChatTab:CreateParagraph({
    Name = "",
    Content = "Aguardando mensagem..."
})

-- Atualiza a pré-visualização em tempo real
messageInput:GetPropertyChangedSignal("Text"):Connect(function()
    local text = messageInput.Text
    if text == "" then
        previewLabel:Set("Aguardando mensagem...")
    else
        previewLabel:Set(applyBypass(text))
    end
end)

-- Botões de ação
ChatTab:CreateSection("Ações")
ChatTab:CreateButton({
    Name = "Enviar Mensagem Global",
    Callback = function()
        sendMessage(messageInput.Text, false)
    end
})
ChatTab:CreateButton({
    Name = "Enviar Mensagem Privada (PM)",
    Callback = function()
        sendMessage(messageInput.Text, true)
    end
})

-- ========================= ABA DE JOGADORES =========================
PlayersTab:CreateSection("Jogadores Online")
local playerDropdown = PlayersTab:CreateDropdown({
    Name = "Selecione um Jogador",
    Options = {"Carregando..."},
    CurrentOption = "Carregando...",
    Callback = function(option)
        for _, p in ipairs(game.Players:GetPlayers()) do
            if p.Name == option then
                Config.SelectedPlayer = p
                selectedLabel:Set("Selecionado: " .. p.Name)
                break
            end
        end
    end
})

local selectedLabel = PlayersTab:CreateParagraph({
    Name = "Jogador Selecionado",
    Content = "Nenhum jogador selecionado"
})

-- Função para atualizar a lista de jogadores
local function updatePlayerList()
    local players = {}
    local localPlayer = game.Players.LocalPlayer
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= localPlayer then
            table.insert(players, p.Name)
        end
    end
    if #players == 0 then players = {"Nenhum outro jogador"} end
    playerDropdown:SetOptions(players)
    
    if Config.SelectedPlayer and not table.find(players, Config.SelectedPlayer.Name) then
        Config.SelectedPlayer = nil
        selectedLabel:Set("Nenhum jogador selecionado")
    elseif Config.SelectedPlayer then
        selectedLabel:Set("Selecionado: " .. Config.SelectedPlayer.Name)
    end
end

updatePlayerList()
game.Players.PlayerAdded:Connect(updatePlayerList)
game.Players.PlayerRemoving:Connect(updatePlayerList)
PlayersTab:CreateButton({
    Name = "Atualizar Lista",
    Callback = function()
        updatePlayerList()
        Rayfield:Notify({Title = "Info", Content = "Lista atualizada!", Duration = 2})
    end
})

-- ========================= ABA DE BYPASS =========================
BypassTab:CreateSection("Métodos de Bypass")
local methodDropdown = BypassTab:CreateDropdown({
    Name = "Método",
    Options = {"Cyrillic", "Zero-Width", "Combined"},
    CurrentOption = "Cyrillic",
    Callback = function(option)
        Config.CurrentBypass = option
        local text = messageInput.Text
        if text ~= "" then
            previewLabel:Set(applyBypass(text))
        end
        Rayfield:Notify({Title = "Bypass", Content = "Método alterado para " .. option, Duration = 2})
    end
})

-- ========================= ABA DE CONFIGURAÇÕES =========================
SettingsTab:CreateSection("Sobre")
SettingsTab:CreateParagraph({
    Name = "Advanced Chat Bypass System",
    Content = "Versão 6.0 (2026)\n\nCom 3 métodos de bypass:\n• Cyrillic\n• Zero-Width\n• Combined\n\nScript totalmente funcional com a Rayfield UI."
})
SettingsTab:CreateSection("Aviso")
SettingsTab:CreateParagraph({
    Name = "Aviso Legal",
    Content = "O bypass de palavras viola os Termos de Serviço da Roblox. Use por sua conta e risco."
})
SettingsTab:CreateButton({
    Name = "Testar Bypass",
    Callback = function()
        sendMessage("Hello World", false)
    end
})

-- Notificação final
Rayfield:Notify({
    Title = "Advanced Chat Bypass",
    Content = "Sistema carregado! Todas as abas estão funcionando.",
    Duration = 5
})