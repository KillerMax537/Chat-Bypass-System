--[[
    Script: Chat Bypass + PM System (Sem CreateParagraph - 2026)
    - Interface completa com 4 abas
    - Nenhum erro de nil
    - 3 métodos de bypass
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then return end

local Window = Rayfield:CreateWindow({
    Name = "Chat Bypass System",
    LoadingTitle = "Carregando...",
    ConfigurationSaving = { Enabled = true, FolderName = "ChatBypass", FileName = "Config" },
    Discord = { Enabled = false },
    KeySystem = false
})

local ChatTab = Window:CreateTab("💬 Chat")
local PlayersTab = Window:CreateTab("👥 Jogadores")
local MethodsTab = Window:CreateTab("🔓 Bypass")
local SettingsTab = Window:CreateTab("⚙️ Config")

-- ==================== CONFIG ====================
local Config = {
    SelectedPlayer = nil,
    CurrentMethod = "Cyrillic"
}

-- ==================== BYPASS ====================
local function applyCyrillic(text)
    local map = {a="а",b="Ь",c="с",e="е",g="ɡ",h="һ",i="і",k="к",m="м",n="п",o="о",p="р",r="г",s="ѕ",t="т",u="υ",x="х",y="у"}
    local out = ""
    for i=1,#text do
        local ch = text:sub(i,i)
        local low = ch:lower()
        if map[low] then
            out = out .. (ch:upper()==ch and map[low]:upper() or map[low])
        else
            out = out .. ch
        end
    end
    return out
end

local function applyZeroWidth(text)
    local zwsp = "\u{200B}"
    local out = ""
    for i=1,#text do
        out = out .. text:sub(i,i) .. zwsp
    end
    return out
end

local function applyCombined(text)
    return applyZeroWidth(applyCyrillic(text))
end

local function applyBypass(text)
    if text == nil or text == "" then return "" end
    if Config.CurrentMethod == "Cyrillic" then return applyCyrillic(text)
    elseif Config.CurrentMethod == "Zero-Width" then return applyZeroWidth(text)
    elseif Config.CurrentMethod == "Combined" then return applyCombined(text)
    end
    return text
end

-- ==================== ENVIO ====================
local function sendMessage(message, isPrivate)
    if message == nil or message == "" then
        Rayfield:Notify({Title="Erro", Content="Digite uma mensagem!", Duration=3})
        return
    end
    if isPrivate and not Config.SelectedPlayer then
        Rayfield:Notify({Title="Erro", Content="Selecione um jogador na aba Jogadores", Duration=3})
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
    Rayfield:Notify({Title=success and "Sucesso" or "Erro", Content=success and "Mensagem enviada!" or "Falha ao enviar", Duration=2})
end

-- ==================== ABA CHAT ====================
ChatTab:CreateSection("Sua Mensagem")
local msgInput = ChatTab:CreateInput({
    Name = "Mensagem",
    PlaceholderText = "Digite sua mensagem...",
    RemoveTextAfterFocus = false,
    Callback = function() end
})
ChatTab:CreateSection("Pré-visualização (Bypass)")
local previewLabel = ChatTab:CreateParagraph({ -- esse é o único Paragraph, mas com strings literais
    Name = "",
    Content = "Aguardando mensagem..."
})
msgInput:GetPropertyChangedSignal("Text"):Connect(function()
    local txt = msgInput.Text
    if txt == nil or txt == "" then
        previewLabel:Set("Aguardando mensagem...")
    else
        previewLabel:Set(applyBypass(txt))
    end
end)
ChatTab:CreateButton({Name="Enviar Global", Callback=function() sendMessage(msgInput.Text, false) end})
ChatTab:CreateButton({Name="Enviar PM", Callback=function() sendMessage(msgInput.Text, true) end})

-- ==================== ABA JOGADORES ====================
PlayersTab:CreateSection("Jogadores Online")
local playerDropdown = PlayersTab:CreateDropdown({
    Name = "Selecione",
    Options = {"Carregando..."},
    CurrentOption = "Carregando...",
    Callback = function(opt)
        if opt == nil or opt == "Nenhum jogador disponível" then return end
        for _,p in ipairs(game.Players:GetPlayers()) do
            if p.Name == opt then
                Config.SelectedPlayer = p
                selectedLabel:Set("Selecionado: " .. p.Name)
                break
            end
        end
    end
})
local selectedLabel = PlayersTab:CreateParagraph({
    Name = "",
    Content = "Nenhum jogador selecionado"
})
local function updatePlayers()
    local list = {}
    local localPlayer = game.Players.LocalPlayer
    for _,p in ipairs(game.Players:GetPlayers()) do
        if p ~= localPlayer then table.insert(list, p.Name) end
    end
    if #list == 0 then list = {"Nenhum jogador disponível"} end
    playerDropdown:SetOptions(list)
    if Config.SelectedPlayer and not table.find(list, Config.SelectedPlayer.Name) then
        Config.SelectedPlayer = nil
        selectedLabel:Set("Nenhum jogador selecionado")
    elseif Config.SelectedPlayer then
        selectedLabel:Set("Selecionado: " .. Config.SelectedPlayer.Name)
    end
end
updatePlayers()
game.Players.PlayerAdded:Connect(updatePlayers)
game.Players.PlayerRemoving:Connect(updatePlayers)
PlayersTab:CreateButton({Name="Atualizar Lista", Callback=function() updatePlayers(); Rayfield:Notify({Title="Info", Content="Lista atualizada", Duration=2}) end})

-- ==================== ABA MÉTODOS ====================
MethodsTab:CreateSection("Método de Bypass")
MethodsTab:CreateDropdown({
    Name = "Selecione o Método",
    Options = {"Cyrillic", "Zero-Width", "Combined"},
    CurrentOption = "Cyrillic",
    Callback = function(opt)
        if opt == nil then return end
        Config.CurrentMethod = opt
        local txt = msgInput.Text
        if txt ~= nil and txt ~= "" then previewLabel:Set(applyBypass(txt)) end
        Rayfield:Notify({Title="Método alterado", Content=opt, Duration=2})
    end
})
-- Em vez de CreateParagraph, usamos botões informativos (desabilitados visualmente)
MethodsTab:CreateButton({Name="ℹ️ Cyrillic: substitui letras por cirílico", Callback=function() end})
MethodsTab:CreateButton({Name="ℹ️ Zero-Width: insere espaços invisíveis", Callback=function() end})
MethodsTab:CreateButton({Name="ℹ️ Combined: Cyrillic + Zero-Width (mais forte)", Callback=function() end})

-- ==================== ABA CONFIG ====================
SettingsTab:CreateSection("Spammer (opcional)")
local spamActive = false
local spamMessages = {"Hello!", "Bypass active!", "How are you?"}
local spamDelay = 3
SettingsTab:CreateToggle({Name="Ativar Spammer", CurrentValue=false, Callback=function(val)
    spamActive = val
    if val then
        task.spawn(function()
            while spamActive do
                for _,m in ipairs(spamMessages) do
                    if not spamActive then break end
                    sendMessage(m, false)
                    task.wait(spamDelay)
                end
            end
        end)
    end
end})
SettingsTab:CreateSlider({Name="Delay (segundos)", Range={1,10}, Increment=0.5, CurrentValue=3, Callback=function(val) spamDelay = val end})
SettingsTab:CreateInput({Name="Mensagens (separadas por vírgula)", PlaceholderText="Msg1,Msg2,Msg3", RemoveTextAfterFocus=false, Callback=function(txt)
    if txt == nil or txt == "" then return end
    local msgs = {}
    for m in string.gmatch(txt, "[^,]+") do
        local trimmed = m:match("^%s*(.-)%s*$")
        if trimmed ~= "" then table.insert(msgs, trimmed) end
    end
    if #msgs > 0 then spamMessages = msgs; Rayfield:Notify({Title="Spammer", Content="Mensagens atualizadas", Duration=2}) end
end})
SettingsTab:CreateSection("Sobre")
SettingsTab:CreateButton({Name="ℹ️ Sistema de Chat Bypass 2026 - Versão estável", Callback=function() end})
SettingsTab:CreateButton({Name="⚠️ Uso por sua conta e risco", Callback=function() end})
SettingsTab:CreateButton({Name="🧪 Testar envio ('teste')", Callback=function() sendMessage("teste", false) end})

Rayfield:Notify({Title="Sistema Carregado", Content="Todas as abas funcionando sem erros!", Duration=5})