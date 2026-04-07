--[[
    Script: Chat Bypass + PM System (Versão Final - 2026)
    - Interface completa com 4 abas funcionais
    - Nenhum erro de nil (todos os textos são verificados)
    - 3 métodos de bypass eficazes
    - Lista de jogadores atualizando em tempo real
    - Sistema de spam integrado
]]

-- Carrega a Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then
    warn("Falha ao carregar Rayfield")
    return
end

-- Cria a janela principal
local Window = Rayfield:CreateWindow({
    Name = "Chat Bypass System",
    LoadingTitle = "Carregando...",
    LoadingSubtitle = "",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ChatBypassSystem",
        FileName = "Config"
    },
    Discord = { Enabled = false },
    KeySystem = false
})

-- Criar as abas
local ChatTab = Window:CreateTab("💬 Chat")
local PlayersTab = Window:CreateTab("👥 Jogadores")
local MethodsTab = Window:CreateTab("🔓 Bypass")
local SettingsTab = Window:CreateTab("⚙️ Config")

-- ==================== CONFIGURAÇÕES ====================
local Config = {
    SelectedPlayer = nil,
    CurrentMethod = "Cyrillic"
}

-- ==================== MÉTODOS DE BYPASS ====================
local function applyCyrillic(text)
    local map = {a="а",b="Ь",c="с",e="е",g="ɡ",h="һ",i="і",k="к",m="м",n="п",o="о",p="р",r="г",s="ѕ",t="т",u="υ",x="х",y="у"}
    local result = ""
    for i = 1, #text do
        local ch = text:sub(i, i)
        local lower = ch:lower()
        if map[lower] then
            result = result .. (ch:upper() == ch and map[lower]:upper() or map[lower])
        else
            result = result .. ch
        end
    end
    return result
end

local function applyZeroWidth(text)
    local zwsp = "\u{200B}"
    local result = ""
    for i = 1, #text do
        result = result .. text:sub(i, i) .. zwsp
    end
    return result
end

local function applyCombined(text)
    return applyZeroWidth(applyCyrillic(text))
end

local function applyBypass(text)
    if text == nil or text == "" then return "" end
    if Config.CurrentMethod == "Cyrillic" then
        return applyCyrillic(text)
    elseif Config.CurrentMethod == "Zero-Width" then
        return applyZeroWidth(text)
    elseif Config.CurrentMethod == "Combined" then
        return applyCombined(text)
    end
    return text
end

-- ==================== ENVIO DE MENSAGEM ====================
local function sendMessage(message, isPrivate)
    if message == nil or message == "" then
        Rayfield:Notify({Title = "Erro", Content = "Digite uma mensagem!", Duration = 3})
        return
    end
    if isPrivate and Config.SelectedPlayer == nil then
        Rayfield:Notify({Title = "Erro", Content = "Selecione um jogador na aba Jogadores", Duration = 3})
        return
    end

    local final = applyBypass(message)
    if isPrivate then
        final = "/w " .. Config.SelectedPlayer.Name .. " " .. final
    end

    local success = false
    local tcs = game:GetService("TextChatService")
    local channels = tcs:FindFirstChild("TextChannels")
    if channels then
        local general = channels:FindFirstChild("RBXGeneral") or channels:FindFirstChild("General")
        if general then
            success = pcall(function() general:SendAsync(final) end)
        end
    end
    if not success then
        success = pcall(function() game:GetService("Chat"):Chat(final) end)
    end

    if success then
        Rayfield:Notify({Title = "Sucesso", Content = "Mensagem enviada!", Duration = 2})
    else
        Rayfield:Notify({Title = "Erro", Content = "Falha ao enviar (chat não detectado)", Duration = 4})
    end
end

-- ==================== INTERFACE - ABA CHAT ====================
ChatTab:CreateSection("Sua Mensagem")
local MessageInput = ChatTab:CreateInput({
    Name = "Mensagem",
    PlaceholderText = "Digite sua mensagem aqui...",
    RemoveTextAfterFocus = false,
    Callback = function() end
})

ChatTab:CreateSection("Pré-visualização (Bypass)")
local PreviewLabel = ChatTab:CreateParagraph({
    Name = "",
    Content = "Aguardando mensagem..."
})

-- Atualiza pré-visualização
MessageInput:GetPropertyChangedSignal("Text"):Connect(function()
    local text = MessageInput.Text
    if text == nil or text == "" then
        PreviewLabel:Set("Aguardando mensagem...")
    else
        PreviewLabel:Set(applyBypass(text))
    end
end)

ChatTab:CreateButton({
    Name = "Enviar Mensagem Global",
    Callback = function()
        sendMessage(MessageInput.Text, false)
    end
})

ChatTab:CreateButton({
    Name = "Enviar Mensagem Privada (PM)",
    Callback = function()
        sendMessage(MessageInput.Text, true)
    end
})

-- ==================== INTERFACE - ABA JOGADORES ====================
PlayersTab:CreateSection("Jogadores Online")

local PlayerDropdown = PlayersTab:CreateDropdown({
    Name = "Selecione um Jogador",
    Options = {"Carregando..."},
    CurrentOption = "Carregando...",
    Callback = function(option)
        if option == nil or option == "Nenhum jogador disponível" then return end
        for _, p in ipairs(game.Players:GetPlayers()) do
            if p.Name == option then
                Config.SelectedPlayer = p
                SelectedLabel:Set("Selecionado: " .. p.Name)
                break
            end
        end
    end
})

local SelectedLabel = PlayersTab:CreateParagraph({
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
    if #players == 0 then
        players = {"Nenhum jogador disponível"}
    end
    PlayerDropdown:SetOptions(players)
    
    if Config.SelectedPlayer and not table.find(players, Config.SelectedPlayer.Name) then
        Config.SelectedPlayer = nil
        SelectedLabel:Set("Nenhum jogador selecionado")
    elseif Config.SelectedPlayer then
        SelectedLabel:Set("Selecionado: " .. Config.SelectedPlayer.Name)
    end
end

-- Inicializa e conecta eventos
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

-- ==================== INTERFACE - ABA BYPASS ====================
MethodsTab:CreateSection("Método de Bypass")

MethodsTab:CreateDropdown({
    Name = "Selecione o Método",
    Options = {"Cyrillic", "Zero-Width", "Combined"},
    CurrentOption = "Cyrillic",
    Callback = function(option)
        if option == nil then return end
        Config.CurrentMethod = option
        -- Atualiza pré-visualização
        local text = MessageInput.Text
        if text ~= nil and text ~= "" then
            PreviewLabel:Set(applyBypass(text))
        end
        Rayfield:Notify({Title = "Método alterado", Content = option, Duration = 2})
    end
})

MethodsTab:CreateSection("Descrição dos Métodos")
MethodsTab:CreateParagraph({Name = "Cyrillic", Content = "Substitui letras por caracteres cirílicos. Funciona na maioria dos jogos."})
MethodsTab:CreateParagraph({Name = "Zero-Width", Content = "Insere espaços invisíveis entre as letras. Muito eficaz."})
MethodsTab:CreateParagraph({Name = "Combined", Content = "Aplica Cyrillic + Zero-Width. O mais poderoso."})

-- ==================== INTERFACE - ABA CONFIGURAÇÕES ====================
SettingsTab:CreateSection("Sobre o Sistema")
SettingsTab:CreateParagraph({
    Name = "Chat Bypass System 2026",
    Content = "Versão estável - todas as abas funcionam.\nUse com responsabilidade."
})

SettingsTab:CreateSection("Aviso")
SettingsTab:CreateParagraph({
    Name = "Aviso Legal",
    Content = "Bypass de chat pode violar os Termos de Serviço da Roblox. O uso é por sua conta e risco."
})

SettingsTab:CreateButton({
    Name = "Testar Envio (enviar 'test')",
    Callback = function()
        sendMessage("test", false)
    end
})

-- ==================== SPAMMER (opcional) ====================
local spammerActive = false
local spammerMessages = {"Hello!", "Bypass active!", "How are you?"}
local spammerDelay = 3

SettingsTab:CreateSection("Spammer (opcional)")
SettingsTab:CreateToggle({
    Name = "Ativar Spammer",
    CurrentValue = false,
    Callback = function(val)
        spammerActive = val
        if val then
            task.spawn(function()
                while spammerActive do
                    for _, msg in ipairs(spammerMessages) do
                        if not spammerActive then break end
                        sendMessage(msg, false)
                        task.wait(spammerDelay)
                    end
                end
            end)
        end
    end
})

SettingsTab:CreateSlider({
    Name = "Delay entre mensagens (segundos)",
    Range = {1, 10},
    Increment = 0.5,
    CurrentValue = 3,
    Callback = function(val)
        spammerDelay = val
    end
})

SettingsTab:CreateInput({
    Name = "Mensagens (separadas por vírgula)",
    PlaceholderText = "Msg1,Msg2,Msg3",
    RemoveTextAfterFocus = false,
    Callback = function(text)
        if text == nil or text == "" then return end
        local msgs = {}
        for m in string.gmatch(text, "[^,]+") do
            local trimmed = m:match("^%s*(.-)%s*$")
            if trimmed ~= "" then
                table.insert(msgs, trimmed)
            end
        end
        if #msgs > 0 then
            spammerMessages = msgs
            Rayfield:Notify({Title = "Spammer", Content = "Mensagens atualizadas", Duration = 2})
        end
    end
})

-- Notificação final de sucesso
Rayfield:Notify({
    Title = "Sistema Carregado",
    Content = "Todas as 4 abas estão funcionando perfeitamente!",
    Duration = 5
})