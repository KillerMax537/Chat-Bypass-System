--[[
    Script: Sistema de Chat Bypass + PM (Orion UI)
    Descrição: Um sistema completo e estável para enviar mensagens com bypass.
    Funcionalidades:
        - Interface com 4 abas (Chat, Jogadores, Bypass, Configurações).
        - Três métodos de bypass: Cirílico, Zero-Width e Combinado.
        - Pré-visualização em tempo real da mensagem com bypass aplicado.
        - Lista de jogadores atualizada automaticamente para mensagens privadas.
        - Sistema de Spammer com delay e mensagens personalizáveis.
]]

-- Carrega a biblioteca Orion
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexware/Orion/main/source')))()
if not OrionLib then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Erro Crítico",
        Text = "Falha ao carregar a Orion UI. Verifique sua conexão com a internet.",
        Duration = 10
    })
    return
end

-- Cria a janela principal
local Window = OrionLib:MakeWindow({
    Name = "Chat Bypass System",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "ChatBypassSystem",
    IntroEnabled = true,
    IntroText = "Carregando Sistema...",
    IntroIcon = "rbxassetid://4483345998" -- Um ícone qualquer da biblioteca
})

-- ========================= CONFIGURAÇÕES =========================
local Config = {
    SelectedPlayer = nil,
    CurrentMethod = "Cyrillic"
}

-- ========================= MÉTODOS DE BYPASS AVANÇADOS =========================
-- Método 1: Cirílico
local function applyCyrillic(text)
    local map = {
        a="а", b="ь", c="с", e="е", g="ɡ", h="һ", i="і", k="к",
        m="м", n="п", o="о", p="р", r="г", s="ѕ", t="т", u="υ", x="х", y="у"
    }
    local result = ""
    for i = 1, #text do
        local char = text:sub(i, i)
        local lowerChar = char:lower()
        local mapped = map[lowerChar]
        if mapped then
            result = result .. (char:upper() == char and mapped:upper() or mapped)
        else
            result = result .. char
        end
    end
    return result
end

-- Método 2: Zero-Width (espaços invisíveis)
local function applyZeroWidth(text)
    local zwsp = "\u{200B}"
    local result = ""
    for i = 1, #text do
        result = result .. text:sub(i, i) .. zwsp
    end
    return result
end

-- Método 3: Combinado (Cirílico + Zero-Width)
local function applyCombined(text)
    return applyZeroWidth(applyCyrillic(text))
end

-- Função principal de bypass que chama o método selecionado
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

-- ========================= FUNÇÃO DE ENVIO DE MENSAGEM =========================
local function sendMessage(message, isPrivate)
    if message == nil or message == "" then
        OrionLib:MakeNotification({
            Name = "Erro",
            Content = "Você não pode enviar uma mensagem vazia!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return false
    end

    if isPrivate and Config.SelectedPlayer == nil then
        OrionLib:MakeNotification({
            Name = "Erro",
            Content = "Por favor, selecione um jogador na aba 'Jogadores' primeiro.",
            Image = "rbxassetid://4483345998",
            Time = 4
        })
        return false
    end

    local finalMessage = applyBypass(message)
    if isPrivate then
        finalMessage = "/w " .. Config.SelectedPlayer.Name .. " " .. finalMessage
    end

    -- Tenta enviar usando o novo sistema de chat do Roblox (TextChatService)
    local success = false
    local textChatService = game:GetService("TextChatService")
    local textChannels = textChatService:FindFirstChild("TextChannels")
    if textChannels then
        local generalChannel = textChannels:FindFirstChild("RBXGeneral") or textChannels:FindFirstChild("General")
        if generalChannel then
            local ok, err = pcall(function()
                generalChannel:SendAsync(finalMessage)
            end)
            if ok then success = true else warn("Erro no TextChatService: " .. tostring(err)) end
        end
    end

    -- Se falhou, tenta enviar usando o sistema de chat antigo (Chat)
    if not success then
        local chatService = game:GetService("Chat")
        local ok, err = pcall(function()
            chatService:Chat(finalMessage)
        end)
        if ok then success = true else warn("Erro no Chat legado: " .. tostring(err)) end
    end

    if success then
        OrionLib:MakeNotification({
            Name = "Sucesso",
            Content = "Mensagem enviada com sucesso!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
        return true
    else
        OrionLib:MakeNotification({
            Name = "Falha no Envio",
            Content = "O jogo pode usar um sistema de chat personalizado. O bypass ainda pode funcionar, mas não foi possível enviar.",
            Image = "rbxassetid://4483345998",
            Time = 5
        })
        return false
    end
end

-- ========================= CRIAÇÃO DAS ABAS =========================
-- Aba de Chat
local ChatTab = Window:MakeTab({
    Name = "Chat",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Aba de Jogadores
local PlayersTab = Window:MakeTab({
    Name = "Jogadores",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Aba de Métodos de Bypass
local BypassTab = Window:MakeTab({
    Name = "Bypass",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Aba de Configurações (Spammer)
local ConfigTab = Window:MakeTab({
    Name = "Configurações",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- ========================= CONSTRUÇÃO DA INTERFACE =========================
-- --- Aba de Chat ---
local ChatSection = ChatTab:AddSection({
    Name = "Sua Mensagem"
})

local MessageInput = ChatTab:AddTextbox({
    Name = "Mensagem",
    Default = "",
    TextDisappear = false,
    Callback = function(Value)
        -- O callback é chamado quando o texto muda. Vamos usar isso para a pré-visualização.
        -- Mas a pré-visualização será atualizada em tempo real por outro evento.
    end
})

local PreviewSection = ChatTab:AddSection({
    Name = "Pré-visualização do Bypass"
})

local PreviewLabel = ChatTab:AddLabel("Aguardando mensagem...")

-- Atualiza a pré-visualização em tempo real
local function updatePreview()
    local text = MessageInput.Text
    if text == nil or text == "" then
        PreviewLabel:Set("Aguardando mensagem...")
    else
        PreviewLabel:Set(applyBypass(text))
    end
end

-- Conecta a atualização ao evento de mudança de texto
MessageInput:GetPropertyChangedSignal("Text"):Connect(updatePreview)

ChatTab:AddButton({
    Name = "Enviar Mensagem Global",
    Callback = function()
        sendMessage(MessageInput.Text, false)
    end
})

ChatTab:AddButton({
    Name = "Enviar Mensagem Privada (PM)",
    Callback = function()
        sendMessage(MessageInput.Text, true)
    end
})

-- --- Aba de Jogadores ---
local PlayersSection = PlayersTab:AddSection({
    Name = "Jogadores Online"
})

local PlayerDropdown = PlayersTab:AddDropdown({
    Name = "Selecione um Jogador",
    Options = {"Carregando..."},
    Callback = function(option)
        if option == nil or option == "Nenhum jogador disponível" then return end
        for _, player in ipairs(game.Players:GetPlayers()) do
            if player.Name == option then
                Config.SelectedPlayer = player
                SelectedLabel:Set("Selecionado: " .. player.Name)
                break
            end
        end
    end
})

local SelectedLabel = PlayersTab:AddLabel("Nenhum jogador selecionado")

local function updatePlayerList()
    local players = {}
    local localPlayer = game.Players.LocalPlayer
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= localPlayer then
            table.insert(players, player.Name)
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

updatePlayerList()
game.Players.PlayerAdded:Connect(updatePlayerList)
game.Players.PlayerRemoving:Connect(updatePlayerList)

PlayersTab:AddButton({
    Name = "Atualizar Lista de Jogadores",
    Callback = function()
        updatePlayerList()
        OrionLib:MakeNotification({
            Name = "Info",
            Content = "Lista de jogadores atualizada!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- --- Aba de Métodos de Bypass ---
local BypassSection = BypassTab:AddSection({
    Name = "Selecione o Método"
})

local MethodDropdown = BypassTab:AddDropdown({
    Name = "Método de Bypass",
    Options = {"Cyrillic", "ZeroWidth", "Combined"},
    Callback = function(option)
        Config.CurrentMethod = option
        updatePreview()
        OrionLib:MakeNotification({
            Name = "Método Alterado",
            Content = "Agora usando: " .. option,
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

BypassTab:AddLabel("Descrição dos Métodos")
BypassTab:AddParagraph("Cyrillic", "Substitui letras por caracteres do alfabeto cirílico. É o método mais comum e funciona na maioria dos jogos.")
BypassTab:AddParagraph("ZeroWidth", "Insere caracteres invisíveis entre cada letra da mensagem. Muito eficaz contra filtros simples.")
BypassTab:AddParagraph("Combined", "Aplica primeiro o método Cyrillic e depois o ZeroWidth. É o método mais poderoso e recomendado para filtros mais agressivos.")

-- --- Aba de Configurações (Spammer) ---
local SpamSection = ConfigTab:AddSection({
    Name = "Spammer (opcional)"
})

local spamActive = false
local spamMessages = {"Hello!", "Bypass active!", "How are you?"}
local spamDelay = 3

ConfigTab:AddToggle({
    Name = "Ativar Spammer",
    Default = false,
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

ConfigTab:AddSlider({
    Name = "Delay entre mensagens (segundos)",
    Min = 1,
    Max = 10,
    Default = 3,
    Increment = 0.5,
    Callback = function(val)
        spamDelay = val
    end
})

ConfigTab:AddTextbox({
    Name = "Mensagens (separadas por vírgula)",
    Default = "",
    TextDisappear = false,
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
            OrionLib:MakeNotification({
                Name = "Spammer",
                Content = "Mensagens atualizadas!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

local AboutSection = ConfigTab:AddSection({
    Name = "Sobre"
})

ConfigTab:AddParagraph("Sistema de Chat Bypass 2026", "Versão estável com Orion UI. Todas as funcionalidades estão operacionais.")
ConfigTab:AddParagraph("Aviso Legal", "O uso de bypass em chats pode violar os Termos de Serviço da Roblox. Use por sua conta e risco.")

-- Notificação final para confirmar que tudo foi carregado
OrionLib:MakeNotification({
    Name = "Sistema Carregado",
    Content = "Todas as abas foram carregadas com sucesso! Use com responsabilidade.",
    Image = "rbxassetid://4483345998",
    Time = 6
})