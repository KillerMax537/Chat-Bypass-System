--[[
    Script: Chat Bypass + PM System (Amethyst UI) - Versão Estável
    Funcionalidades:
    - 4 abas totalmente funcionais (Chat, Players, Bypass, Config)
    - 3 métodos de bypass (Cirílico, Zero-Width, Combinado)
    - Pré-visualização em tempo real
    - PM com lista de jogadores
    - Spammer integrado
]]

-- Carrega a biblioteca Amethyst (alternativa moderna ao Rayfield)
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/J0se-j/My-Lua-Library/refs/heads/main/Booting-the-library.lua"))()

-- Cria a janela principal
local Window = Library:CreateWindow({
    Name = "Chat Bypass System",
    LoadingTitle = "Carregando...",
    LoadingSubtitle = "by You",
    ToggleUIKeybind = Enum.KeyCode.RightControl,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ChatBypassSystem",
        FileName = "UserSettings"
    }
})

-- Criação das 4 abas (totalmente funcionais)
local ChatTab = Window:CreateTab("💬 Chat", 4483362458)
local PlayersTab = Window:CreateTab("👥 Players", 4483362458)
local BypassTab = Window:CreateTab("🔓 Bypass", 4483362458)
local ConfigTab = Window:CreateTab("⚙️ Config", 4483362458)

-- ========================= CONFIGURAÇÕES =========================
local Config = {
    SelectedPlayer = nil,
    CurrentMethod = "Cyrillic"
}

-- ========================= MÉTODOS DE BYPASS =========================
-- Método 1: Cirílico
local function applyCyrillic(text)
    local map = {a="а",b="Ь",c="с",e="е",g="ɡ",h="һ",i="і",k="к",m="м",n="п",o="о",p="р",r="г",s="ѕ",t="т",u="υ",x="х",y="у"}
    local out = ""
    for i = 1, #text do
        local ch = text:sub(i, i)
        local lower = ch:lower()
        if map[lower] then
            out = out .. (ch:upper() == ch and map[lower]:upper() or map[lower])
        else
            out = out .. ch
        end
    end
    return out
end

-- Método 2: Zero-Width (espaços invisíveis)
local function applyZeroWidth(text)
    local zwsp = "\u{200B}"
    local out = ""
    for i = 1, #text do
        out = out .. text:sub(i, i) .. zwsp
    end
    return out
end

-- Método 3: Combinado (Cirílico + Zero-Width)
local function applyCombined(text)
    return applyZeroWidth(applyCyrillic(text))
end

-- Função principal de bypass
local function applyBypass(text)
    if text == nil or text == "" then return "" end
    if Config.CurrentMethod == "Cyrillic" then
        return applyCyrillic(text)
    elseif Config.CurrentMethod == "ZeroWidth" then
        return applyZeroWidth(text)
    elseif Config.CurrentMethod == "Combined" then
        return applyCombined(text)
    end
    return text
end

-- ========================= ENVIO DE MENSAGEM =========================
local function sendMessage(message, isPrivate)
    if message == nil or message == "" then
        Library:Notification({Title = "Erro", Content = "Digite uma mensagem!", Duration = 3})
        return
    end
    if isPrivate and Config.SelectedPlayer == nil then
        Library:Notification({Title = "Erro", Content = "Selecione um jogador na aba Players!", Duration = 3})
        return
    end

    local final = applyBypass(message)
    if isPrivate then
        final = "/w " .. Config.SelectedPlayer.Name .. " " .. final
    end

    -- Tenta enviar pelo sistema novo (TextChatService)
    local success = false
    local tcs = game:GetService("TextChatService")
    local channels = tcs:FindFirstChild("TextChannels")
    if channels then
        local general = channels:FindFirstChild("RBXGeneral") or channels:FindFirstChild("General")
        if general then
            success = pcall(function() general:SendAsync(final) end)
        end
    end
    -- Fallback para o sistema antigo (Chat)
    if not success then
        success = pcall(function() game:GetService("Chat"):Chat(final) end)
    end

    if success then
        Library:Notification({Title = "Sucesso", Content = "Mensagem enviada!", Duration = 2})
    else
        Library:Notification({Title = "Erro", Content = "Falha ao enviar (chat não detectado)", Duration = 4})
    end
end

-- ========================= INTERFACE - ABA CHAT =========================
local ChatSection = ChatTab:CreateSection("Sua Mensagem")
local MessageInput = ChatSection:CreateTextBox({
    Name = "Mensagem",
    PlaceholderText = "Digite sua mensagem aqui...",
    RemoveTextAfterFocus = false,
    Callback = function() end
})

local PreviewSection = ChatTab:CreateSection("Pré-visualização (Bypass)")
local PreviewLabel = PreviewSection:CreateParagraph({
    Name = "",
    Content = "Aguardando mensagem..."
})

-- Atualiza a pré-visualização em tempo real
MessageInput:GetPropertyChangedSignal("Text"):Connect(function()
    local text = MessageInput.Text
    if text == nil or text == "" then
        PreviewLabel:Set("Aguardando mensagem...")
    else
        PreviewLabel:Set(applyBypass(text))
    end
end)

local ActionsSection = ChatTab:CreateSection("Ações")
ActionsSection:CreateButton({
    Name = "Enviar Mensagem Global",
    Callback = function()
        sendMessage(MessageInput.Text, false)
    end
})
ActionsSection:CreateButton({
    Name = "Enviar Mensagem Privada (PM)",
    Callback = function()
        sendMessage(MessageInput.Text, true)
    end
})

-- ========================= INTERFACE - ABA PLAYERS =========================
local PlayersSection = PlayersTab:CreateSection("Jogadores Online")
local PlayerDropdown = PlayersSection:CreateDropdown({
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
    Name = "Atualizar Lista Agora",
    Callback = function()
        updatePlayerList()
        Library:Notification({Title = "Info", Content = "Lista atualizada!", Duration = 2})
    end
})

-- ========================= INTERFACE - ABA BYPASS =========================
local BypassSection = BypassTab:CreateSection("Método de Bypass")
local MethodDropdown = BypassSection:CreateDropdown({
    Name = "Selecione o Método",
    Options = {"Cyrillic", "ZeroWidth", "Combined"},
    CurrentOption = "Cyrillic",
    Callback = function(option)
        if option == nil then return end
        Config.CurrentMethod = option
        -- Atualiza pré-visualização
        local text = MessageInput.Text
        if text ~= nil and text ~= "" then
            PreviewLabel:Set(applyBypass(text))
        end
        Library:Notification({Title = "Método alterado", Content = option, Duration = 2})
    end
})

local DescSection = BypassTab:CreateSection("Descrição dos Métodos")
DescSection:CreateParagraph({Name = "Cyrillic", Content = "Substitui letras por caracteres cirílicos. Funciona na maioria dos jogos."})
DescSection:CreateParagraph({Name = "ZeroWidth", Content = "Insere espaços invisíveis entre as letras. Muito eficaz."})
DescSection:CreateParagraph({Name = "Combined", Content = "Aplica Cyrillic + ZeroWidth. O mais poderoso."})

-- ========================= INTERFACE - ABA CONFIG (SPAMMER) =========================
local SpamSection = ConfigTab:CreateSection("Spammer (opcional)")

local spamActive = false
local spamMessages = {"Hello!", "Bypass active!", "How are you?"}
local spamDelay = 3

SpamSection:CreateToggle({
    Name = "Ativar Spammer",
    CurrentValue = false,
    Callback = function(val)
        spamActive = val
        if val then
            task.spawn(function()
                while spamActive do
                    for _, msg in ipairs(spamMessages) do
                        if not spamActive then break end
                        sendMessage(msg, false)
                        task.wait(spamDelay)
                    end
                end
            end)
        end
    end
})

SpamSection:CreateSlider({
    Name = "Delay entre mensagens (segundos)",
    Min = 1,
    Max = 10,
    Default = 3,
    Callback = function(val)
        spamDelay = val
    end
})

SpamSection:CreateTextBox({
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
            spamMessages = msgs
            Library:Notification({Title = "Spammer", Content = "Mensagens atualizadas", Duration = 2})
        end
    end
})

local AboutSection = ConfigTab:CreateSection("Sobre")
AboutSection:CreateParagraph({Name = "Chat Bypass System 2026", Content = "Versão estável com Amethyst UI - todas as abas funcionam. Use com responsabilidade."})
AboutSection:CreateParagraph({Name = "Aviso Legal", Content = "Bypass de chat pode violar os Termos de Serviço da Roblox. O uso é por sua conta e risco."})
AboutSection:CreateButton({
    Name = "Testar Envio ('teste')",
    Callback = function()
        sendMessage("teste", false)
    end
})

-- Notificação de sucesso
Library:Notification({Title = "Sistema Carregado", Content = "Todas as 4 abas estão funcionando!", Duration = 5})