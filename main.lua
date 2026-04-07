--[[
    Script: Chat Bypass + PM System (Versão Ultra - 2026)
    Métodos incluídos:
    - Cyrillic homoglyphs
    - Greek homoglyphs
    - Zero-width spaces (ZWSP, ZWNJ, ZWJ)
    - Combining diacritics (múltiplos)
    - Invisible character injection (U+200B, U+200C, U+200D)
    - Reverse text + homoglyphs
    - Modo "Kamikaze" (aleatório entre todos)
]]

-- Carrega Rayfield com fallback
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then
    game:GetService("StarterGui"):SetCore("SendNotification", {Title="Erro", Text="Falha ao carregar Rayfield", Duration=5})
    return
end

-- Janela principal
local Window = Rayfield:CreateWindow({
    Name = "Advanced Chat Bypass Ultra",
    LoadingTitle = "Carregando...",
    LoadingSubtitle = "by Expert",
    ConfigurationSaving = { Enabled = true, FolderName = "ChatBypassUltra", FileName = "Config" },
    Discord = { Enabled = false },
    KeySystem = false
})

-- Abas
local ChatTab = Window:CreateTab("💬 Chat")
local PlayersTab = Window:CreateTab("👥 Players")
local MethodsTab = Window:CreateTab("🔓 Methods")
local SettingsTab = Window:CreateTab("⚙️ Settings")

-- ========================= CONFIG =========================
local Config = {
    SelectedPlayer = nil,
    CurrentMethod = "Cyrillic",
    SpamEnabled = false,
    SpamDelay = 2,
    SpamMessages = {"Hello!", "Bypass active!", "How are you?"}
}

-- ========================= MÉTODOS AVANÇADOS =========================
local function cyrillic(text)
    local map = {a="а",b="Ь",c="с",e="е",g="ɡ",h="һ",i="і",k="к",m="м",n="п",o="о",p="р",r="г",s="ѕ",t="т",u="υ",x="х",y="у"}
    local out = ""
    for i=1,#text do
        local ch = text:sub(i,i)
        local lower = ch:lower()
        if map[lower] then
            out = out .. (ch:upper()==ch and map[lower]:upper() or map[lower])
        else
            out = out .. ch
        end
    end
    return out
end

local function greek(text)
    local map = {a="α",b="β",c="ϲ",d="δ",e="ε",f="φ",g="γ",h="η",i="ι",k="κ",l="λ",m="μ",n="ν",o="ο",p="π",r="ρ",s="σ",t="τ",u="υ",x="ξ",y="υ",z="ζ"}
    local out = ""
    for i=1,#text do
        local ch = text:sub(i,i)
        local lower = ch:lower()
        if map[lower] then
            out = out .. (ch:upper()==ch and map[lower]:upper() or map[lower])
        else
            out = out .. ch
        end
    end
    return out
end

local function zeroWidth(text)
    local zwsp = "\u{200B}" -- zero-width space
    local out = ""
    for i=1,#text do
        out = out .. text:sub(i,i) .. zwsp
    end
    return out
end

local function zeroWidthJoiners(text)
    local zwj = "\u{200D}" -- zero-width joiner
    local out = ""
    for i=1,#text do
        out = out .. text:sub(i,i) .. zwj
    end
    return out
end

local function combiningDiacritics(text)
    local diacritics = {"\u{0300}","\u{0301}","\u{0302}","\u{0303}","\u{0304}","\u{0306}","\u{0307}","\u{0308}","\u{0309}","\u{030A}"}
    local out = ""
    for i=1,#text do
        local ch = text:sub(i,i)
        if ch:match("%a") then
            out = out .. ch .. diacritics[math.random(#diacritics)]
        else
            out = out .. ch
        end
    end
    return out
end

local function reversePlusCyrillic(text)
    local reversed = text:reverse()
    return cyrillic(reversed)
end

local function kamikaze(text)
    local methods = {cyrillic, greek, zeroWidth, zeroWidthJoiners, combiningDiacritics, reversePlusCyrillic}
    return methods[math.random(#methods)](text)
end

-- Router principal
local function applyBypass(text)
    if text == "" then return "" end
    if Config.CurrentMethod == "Cyrillic" then return cyrillic(text)
    elseif Config.CurrentMethod == "Greek" then return greek(text)
    elseif Config.CurrentMethod == "Zero-Width Space" then return zeroWidth(text)
    elseif Config.CurrentMethod == "Zero-Width Joiner" then return zeroWidthJoiners(text)
    elseif Config.CurrentMethod == "Combining Diacritics" then return combiningDiacritics(text)
    elseif Config.CurrentMethod == "Reverse + Cyrillic" then return reversePlusCyrillic(text)
    elseif Config.CurrentMethod == "Kamikaze (Random)" then return kamikaze(text)
    end
    return text
end

-- ========================= ENVIO DE MENSAGEM =========================
local function sendMessage(message, isPrivate)
    if message == "" then
        Rayfield:Notify({Title="Erro", Content="Mensagem vazia", Duration=3})
        return false
    end
    if isPrivate and not Config.SelectedPlayer then
        Rayfield:Notify({Title="Erro", Content="Selecione um jogador", Duration=3})
        return false
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
    Rayfield:Notify({Title=success and "Sucesso" or "Falha", Content=success and "Enviado!" or "Não foi possível enviar", Duration=2})
    return success
end

-- ========================= INTERFACE - ABA CHAT =========================
ChatTab:CreateSection("Sua Mensagem")
local msgInput = ChatTab:CreateInput({Name="Mensagem", PlaceholderText="Digite aqui...", RemoveTextAfterFocus=false, Callback=function() end})
ChatTab:CreateSection("Pré-visualização (Bypass Aplicado)")
local previewLabel = ChatTab:CreateParagraph({Name="", Content="Aguardando mensagem..."})
msgInput:GetPropertyChangedSignal("Text"):Connect(function()
    local t = msgInput.Text
    previewLabel:Set(t=="" and "Aguardando mensagem..." or applyBypass(t))
end)
ChatTab:CreateButton({Name="Enviar Global", Callback=function() sendMessage(msgInput.Text, false) end})
ChatTab:CreateButton({Name="Enviar PM", Callback=function() sendMessage(msgInput.Text, true) end})

-- ========================= INTERFACE - PLAYERS =========================
PlayersTab:CreateSection("Jogadores Online")
local playerDropdown = PlayersTab:CreateDropdown({Name="Selecione", Options={"Carregando..."}, CurrentOption="Carregando...", Callback=function(opt)
    for _,p in ipairs(game.Players:GetPlayers()) do
        if p.Name == opt then Config.SelectedPlayer = p; selectedLabel:Set("Selecionado: "..p.Name) end
    end
end})
local selectedLabel = PlayersTab:CreateParagraph({Name="Jogador Selecionado", Content="Nenhum"})
local function updatePlayers()
    local list = {}
    for _,p in ipairs(game.Players:GetPlayers()) do
        if p ~= game.Players.LocalPlayer then table.insert(list, p.Name) end
    end
    if #list==0 then list={"Nenhum outro jogador"} end
    playerDropdown:SetOptions(list)
    if Config.SelectedPlayer and not table.find(list, Config.SelectedPlayer.Name) then
        Config.SelectedPlayer = nil; selectedLabel:Set("Nenhum jogador selecionado")
    elseif Config.SelectedPlayer then selectedLabel:Set("Selecionado: "..Config.SelectedPlayer.Name) end
end
updatePlayers()
game.Players.PlayerAdded:Connect(updatePlayers)
game.Players.PlayerRemoving:Connect(updatePlayers)
PlayersTab:CreateButton({Name="Atualizar Lista", Callback=function() updatePlayers(); Rayfield:Notify({Title="Info", Content="Lista atualizada", Duration=2}) end})

-- ========================= INTERFACE - MÉTODOS =========================
MethodsTab:CreateSection("Selecione o Método de Bypass")
local methodDropdown = MethodsTab:CreateDropdown({
    Name = "Método",
    Options = {"Cyrillic", "Greek", "Zero-Width Space", "Zero-Width Joiner", "Combining Diacritics", "Reverse + Cyrillic", "Kamikaze (Random)"},
    CurrentOption = "Cyrillic",
    Callback = function(opt)
        Config.CurrentMethod = opt
        if msgInput.Text ~= "" then previewLabel:Set(applyBypass(msgInput.Text)) end
        Rayfield:Notify({Title="Método alterado", Content=opt, Duration=2})
    end
})
MethodsTab:CreateSection("Descrição Rápida")
MethodsTab:CreateParagraph({Name="Cyrillic", Content="Letras cirílicas homógrafas."})
MethodsTab:CreateParagraph({Name="Greek", Content="Letras gregas homógrafas."})
MethodsTab:CreateParagraph({Name="Zero-Width Space", Content="Espaços invisíveis (U+200B)."})
MethodsTab:CreateParagraph({Name="Zero-Width Joiner", Content="Conector invisível (U+200D)."})
MethodsTab:CreateParagraph({Name="Combining Diacritics", Content="Acentos sobrepostos."})
MethodsTab:CreateParagraph({Name="Reverse + Cyrillic", Content="Inverte o texto + Cyrillic."})
MethodsTab:CreateParagraph({Name="Kamikaze", Content="Aleatório entre todos os métodos."})

-- ========================= INTERFACE - CONFIGURAÇÕES =========================
SettingsTab:CreateSection("Spammer (opcional)")
SettingsTab:CreateToggle({Name="Ativar Spammer", CurrentValue=false, Callback=function(val)
    Config.SpamEnabled = val
    if val then
        task.spawn(function()
            while Config.SpamEnabled do
                for _,m in ipairs(Config.SpamMessages) do
                    if not Config.SpamEnabled then break end
                    sendMessage(m, false)
                    task.wait(Config.SpamDelay)
                end
            end
        end)
    end
end})
SettingsTab:CreateSlider({Name="Delay (segundos)", Range={1,10}, Increment=0.5, CurrentValue=2, Callback=function(val) Config.SpamDelay = val end})
SettingsTab:CreateInput({Name="Mensagens (separadas por vírgula)", PlaceholderText="Msg1,Msg2,Msg3", RemoveTextAfterFocus=false, Callback=function(txt)
    local msgs = {}
    for m in string.gmatch(txt, "[^,]+") do table.insert(msgs, m:match("^%s*(.-)%s*$")) end
    if #msgs>0 then Config.SpamMessages = msgs; Rayfield:Notify({Title="Spammer", Content="Mensagens atualizadas", Duration=2}) end
end})
SettingsTab:CreateSection("Sobre")
SettingsTab:CreateParagraph({Name="Chat Bypass Ultra 2026", Content="7 métodos avançados de bypass. Todas as abas funcionais. Use com responsabilidade."})
SettingsTab:CreateButton({Name="Testar Envio ('Hello World')", Callback=function() sendMessage("Hello World", false) end})

-- Notificação final
Rayfield:Notify({Title="Sistema Ultra Carregado", Content="Todos os métodos e abas estão prontos!", Duration=6})