--[[
    Script: Meta Chat Bypass Hub - Versão Avançada
    Autor: Custom
    Descrição: Hub próprio com interface avançada, múltiplos métodos de bypass,
    sistema de spam, lista de jogadores, notificações internas, e otimizações.
    Estilo: Moderno, escuro, responsivo.
]]

-- ========================= CONFIGURAÇÕES GLOBAIS =========================
local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local ChatService = game:GetService("Chat")
local RunService = game:GetService("RunService")

-- Estado do hub
local Hub = {
    Open = true,
    SelectedPlayer = nil,
    BypassMethod = "Cyrillic", -- Opções: Cyrillic, ZeroWidth, Combined, Diacritics, Reverse, Kamikaze
    SpammerActive = false,
    SpammerDelay = 2,
    SpammerMessages = {"Hello!", "Bypass active!", "Meta Hub"},
    DebugMode = true, -- Logs no console
}

-- ========================= FUNÇÕES DE DEBUG =========================
local function DebugLog(...)
    if Hub.DebugMode then
        print("[MetaHub]", ...)
    end
end

-- ========================= MÉTODOS DE BYPASS AVANÇADOS =========================
-- 1. Cyrillic homoglyphs
local function Bypass_Cyrillic(text)
    local map = {
        a="а", b="ь", c="с", e="е", g="ɡ", h="һ", i="і", k="к",
        m="м", n="п", o="о", p="р", r="г", s="ѕ", t="т", u="υ", x="х", y="у"
    }
    local result = ""
    for i = 1, #text do
        local char = text:sub(i, i)
        local lower = char:lower()
        if map[lower] then
            result = result .. (char:upper() == char and map[lower]:upper() or map[lower])
        else
            result = result .. char
        end
    end
    return result
end

-- 2. Zero-Width Spaces (U+200B)
local function Bypass_ZeroWidth(text)
    local zwsp = "\u{200B}"
    local result = ""
    for i = 1, #text do
        result = result .. text:sub(i, i) .. zwsp
    end
    return result
end

-- 3. Combining Diacritics (acentos empilhados)
local function Bypass_Diacritics(text)
    local diacritics = {"\u{0300}","\u{0301}","\u{0302}","\u{0303}","\u{0304}","\u{0306}","\u{0307}","\u{0308}"}
    local result = ""
    for i = 1, #text do
        local char = text:sub(i, i)
        if char:match("%a") then
            result = result .. char .. diacritics[math.random(#diacritics)]
        else
            result = result .. char
        end
    end
    return result
end

-- 4. Reverse + Cyrillic (inversão)
local function Bypass_Reverse(text)
    return Bypass_Cyrillic(text:reverse())
end

-- 5. Kamikaze (aleatório entre todos os métodos)
local function Bypass_Kamikaze(text)
    local methods = {Bypass_Cyrillic, Bypass_ZeroWidth, Bypass_Diacritics, Bypass_Reverse}
    return methods[math.random(#methods)](text)
end

-- 6. Combined (Cyrillic + ZeroWidth)
local function Bypass_Combined(text)
    return Bypass_ZeroWidth(Bypass_Cyrillic(text))
end

-- Roteador principal
local function ApplyBypass(text)
    if text == nil or text == "" then return "" end
    if Hub.BypassMethod == "Cyrillic" then
        return Bypass_Cyrillic(text)
    elseif Hub.BypassMethod == "ZeroWidth" then
        return Bypass_ZeroWidth(text)
    elseif Hub.BypassMethod == "Combined" then
        return Bypass_Combined(text)
    elseif Hub.BypassMethod == "Diacritics" then
        return Bypass_Diacritics(text)
    elseif Hub.BypassMethod == "Reverse" then
        return Bypass_Reverse(text)
    elseif Hub.BypassMethod == "Kamikaze" then
        return Bypass_Kamikaze(text)
    end
    return text
end

-- ========================= ENVIO DE MENSAGEM (COM QUEBRA DE ANTICHEAT LEVE) =========================
-- Tentativa de bypass do filtro via atraso e simulação de digitação (conceito)
local function SendMessage(text, isPrivate)
    if text == nil or text == "" then
        Notify("Erro", "Mensagem vazia!", 3)
        return false
    end
    if isPrivate and not Hub.SelectedPlayer then
        Notify("Erro", "Selecione um jogador para PM!", 3)
        return false
    end
    
    local final = ApplyBypass(text)
    if isPrivate then
        final = "/w " .. Hub.SelectedPlayer.Name .. " " .. final
    end
    
    -- Pequeno delay para tentar evitar detecção instantânea (opcional)
    task.wait(0.05)
    
    local success = false
    -- Tenta TextChatService (novo)
    local textChannels = TextChatService:FindFirstChild("TextChannels")
    if textChannels then
        local general = textChannels:FindFirstChild("RBXGeneral") or textChannels:FindFirstChild("General")
        if general then
            success = pcall(function() general:SendAsync(final) end)
        end
    end
    -- Fallback para Chat legacy
    if not success then
        success = pcall(function() ChatService:Chat(final) end)
    end
    
    if success then
        Notify("Sucesso", "Mensagem enviada!", 2)
        DebugLog("Enviado: " .. final)
    else
        Notify("Erro", "Falha ao enviar (chat não detectado)", 4)
        DebugLog("Falha ao enviar: " .. final)
    end
    return success
end

-- ========================= SISTEMA DE NOTIFICAÇÃO INTERNO =========================
local NotifyQueue = {}
local function Notify(title, content, duration)
    -- Criar uma notificação visual simples na tela
    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(0, 300, 0, 50)
    notif.Position = UDim2.new(1, -310, 0, 10)
    notif.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    notif.BorderSizePixel = 0
    notif.BackgroundTransparency = 0.2
    notif.ClipsDescendants = true
    notif.Parent = game.CoreGui
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 20)
    titleLabel.Position = UDim2.new(0, 5, 0, 0)
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.BackgroundTransparency = 1
    titleLabel.Parent = notif
    
    local contentLabel = Instance.new("TextLabel")
    contentLabel.Size = UDim2.new(1, -10, 0, 25)
    contentLabel.Position = UDim2.new(0, 5, 0, 20)
    contentLabel.Text = content
    contentLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    contentLabel.TextXAlignment = Enum.TextXAlignment.Left
    contentLabel.Font = Enum.Font.Gotham
    contentLabel.TextSize = 12
    contentLabel.BackgroundTransparency = 1
    contentLabel.Parent = notif
    
    -- Animação de entrada
    notif:TweenPosition(UDim2.new(1, -310, 0, 10), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
    task.wait(duration)
    notif:TweenPosition(UDim2.new(1, 0, 0, 10), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true)
    task.wait(0.3)
    notif:Destroy()
end

-- ========================= CRIAÇÃO DA INTERFACE (GUI PERSONALIZADA) =========================
local function CreateHub()
    -- ScreenGui principal
    local gui = Instance.new("ScreenGui")
    gui.Name = "MetaHub"
    gui.ResetOnSpawn = false
    gui.Parent = game.CoreGui
    
    -- Frame principal (janela)
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 550, 0, 450)
    mainFrame.Position = UDim2.new(0.5, -275, 0.5, -225)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = gui
    
    -- Sombra / borda sutil
    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.Position = UDim2.new(0, -5, 0, -5)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.8
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 0
    shadow.Parent = mainFrame
    
    -- Título
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -50, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.Text = "Meta Chat Bypass Hub"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 16
    titleText.BackgroundTransparency = 1
    titleText.Parent = titleBar
    
    -- Botão fechar
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 35, 1, 0)
    closeBtn.Position = UDim2.new(1, -35, 0, 0)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.Gotham
    closeBtn.TextSize = 18
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        Hub.Open = false
    end)
    
    -- Sistema de abas (buttons e container)
    local tabsContainer = Instance.new("Frame")
    tabsContainer.Size = UDim2.new(1, 0, 0, 40)
    tabsContainer.Position = UDim2.new(0, 0, 0, 35)
    tabsContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    tabsContainer.BorderSizePixel = 0
    tabsContainer.Parent = mainFrame
    
    local contentContainer = Instance.new("Frame")
    contentContainer.Size = UDim2.new(1, 0, 1, -75)
    contentContainer.Position = UDim2.new(0, 0, 0, 75)
    contentContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    contentContainer.BorderSizePixel = 0
    contentContainer.Parent = mainFrame
    
    -- Tabela de abas
    local tabs = {
        {name = "Chat", index = 1},
        {name = "Players", index = 2},
        {name = "Bypass", index = 3},
        {name = "Spammer", index = 4},
    }
    local activeTab = 1
    local tabButtons = {}
    local tabContents = {}
    
    -- Função para mostrar conteúdo da aba
    local function SwitchTab(tabIndex)
        activeTab = tabIndex
        for i, content in pairs(tabContents) do
            content.Visible = (i == tabIndex)
        end
        for i, btn in pairs(tabButtons) do
            btn.BackgroundColor3 = (i == tabIndex) and Color3.fromRGB(55, 55, 70) or Color3.fromRGB(30, 30, 40)
        end
    end
    
    -- Criar botões das abas
    for i, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 100, 1, 0)
        btn.Position = UDim2.new((i-1)*0.2, 0, 0, 0)
        btn.Text = tab.name
        btn.BackgroundColor3 = (i == 1) and Color3.fromRGB(55, 55, 70) or Color3.fromRGB(30, 30, 40)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 14
        btn.Parent = tabsContainer
        btn.MouseButton1Click:Connect(function() SwitchTab(i) end)
        tabButtons[i] = btn
        
        -- Criar frame de conteúdo para cada aba
        local contentFrame = Instance.new("ScrollingFrame")
        contentFrame.Size = UDim2.new(1, 0, 1, 0)
        contentFrame.Position = UDim2.new(0, 0, 0, 0)
        contentFrame.BackgroundTransparency = 1
        contentFrame.BorderSizePixel = 0
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        contentFrame.ScrollBarThickness = 6
        contentFrame.Parent = contentContainer
        contentFrame.Visible = (i == 1)
        tabContents[i] = contentFrame
        
        -- Layout automático dentro do ScrollingFrame
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = contentFrame
    end
    
    -- ==================== ABA CHAT ====================
    local chatContent = tabContents[1]
    
    local msgLabel = Instance.new("TextLabel")
    msgLabel.Size = UDim2.new(1, -20, 0, 25)
    msgLabel.Position = UDim2.new(0, 10, 0, 5)
    msgLabel.Text = "Sua Mensagem:"
    msgLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    msgLabel.BackgroundTransparency = 1
    msgLabel.Font = Enum.Font.Gotham
    msgLabel.TextSize = 14
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.LayoutOrder = 1
    msgLabel.Parent = chatContent
    
    local messageBox = Instance.new("TextBox")
    messageBox.Size = UDim2.new(1, -20, 0, 40)
    messageBox.Position = UDim2.new(0, 10, 0, 35)
    messageBox.PlaceholderText = "Digite sua mensagem..."
    messageBox.Text = ""
    messageBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    messageBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    messageBox.Font = Enum.Font.Gotham
    messageBox.TextSize = 14
    messageBox.ClearTextOnFocus = false
    messageBox.LayoutOrder = 2
    messageBox.Parent = chatContent
    
    local previewLabel = Instance.new("TextLabel")
    previewLabel.Size = UDim2.new(1, -20, 0, 25)
    previewLabel.Position = UDim2.new(0, 10, 0, 85)
    previewLabel.Text = "Pré-visualização: "
    previewLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    previewLabel.BackgroundTransparency = 1
    previewLabel.Font = Enum.Font.Gotham
    previewLabel.TextSize = 12
    previewLabel.TextXAlignment = Enum.TextXAlignment.Left
    previewLabel.LayoutOrder = 3
    previewLabel.Parent = chatContent
    
    local previewValue = Instance.new("TextLabel")
    previewValue.Size = UDim2.new(1, -20, 0, 50)
    previewValue.Position = UDim2.new(0, 10, 0, 115)
    previewValue.Text = "Aguardando..."
    previewValue.TextColor3 = Color3.fromRGB(255, 255, 255)
    previewValue.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    previewValue.BackgroundTransparency = 0.3
    previewValue.Font = Enum.Font.Gotham
    previewValue.TextSize = 13
    previewValue.TextWrapped = true
    previewValue.LayoutOrder = 4
    previewValue.Parent = chatContent
    
    local function updatePreview()
        local txt = messageBox.Text
        if txt == "" then
            previewValue.Text = "Aguardando mensagem..."
        else
            previewValue.Text = ApplyBypass(txt)
        end
    end
    messageBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)
    
    local globalBtn = Instance.new("TextButton")
    globalBtn.Size = UDim2.new(0.9, 0, 0, 40)
    globalBtn.Position = UDim2.new(0.05, 0, 0, 180)
    globalBtn.Text = "Enviar Global"
    globalBtn.BackgroundColor3 = Color3.fromRGB(45, 80, 120)
    globalBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    globalBtn.Font = Enum.Font.GothamBold
    globalBtn.TextSize = 14
    globalBtn.LayoutOrder = 5
    globalBtn.Parent = chatContent
    globalBtn.MouseButton1Click:Connect(function()
        SendMessage(messageBox.Text, false)
    end)
    
    local pmBtn = Instance.new("TextButton")
    pmBtn.Size = UDim2.new(0.9, 0, 0, 40)
    pmBtn.Position = UDim2.new(0.05, 0, 0, 230)
    pmBtn.Text = "Enviar PM (privado)"
    pmBtn.BackgroundColor3 = Color3.fromRGB(100, 70, 120)
    pmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    pmBtn.Font = Enum.Font.GothamBold
    pmBtn.TextSize = 14
    pmBtn.LayoutOrder = 6
    pmBtn.Parent = chatContent
    pmBtn.MouseButton1Click:Connect(function()
        SendMessage(messageBox.Text, true)
    end)
    
    -- Ajustar CanvasSize do ScrollingFrame
    local function updateCanvas(frame)
        local layout = frame:FindFirstChildOfClass("UIListLayout")
        if layout then
            local totalHeight = 0
            for _, child in ipairs(frame:GetChildren()) do
                if child:IsA("GuiObject") and child.Visible then
                    totalHeight = totalHeight + child.Size.Y.Offset + layout.Padding.Offset
                end
            end
            frame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
        end
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        updateCanvas(chatContent)
    end)
    task.wait(0.1)
    updateCanvas(chatContent)
    
    -- ==================== ABA PLAYERS ====================
    local playersContent = tabContents[2]
    
    local playersLabel = Instance.new("TextLabel")
    playersLabel.Size = UDim2.new(1, -20, 0, 25)
    playersLabel.Text = "Jogadores Online:"
    playersLabel.TextColor3 = Color3.fromRGB(200,200,200)
    playersLabel.BackgroundTransparency = 1
    playersLabel.Font = Enum.Font.Gotham
    playersLabel.TextSize = 14
    playersLabel.TextXAlignment = Enum.TextXAlignment.Left
    playersLabel.LayoutOrder = 1
    playersLabel.Parent = playersContent
    
    local playerDropdownBtn = Instance.new("TextButton")
    playerDropdownBtn.Size = UDim2.new(0.9, 0, 0, 35)
    playerDropdownBtn.Text = "Selecionar Jogador"
    playerDropdownBtn.BackgroundColor3 = Color3.fromRGB(40,40,50)
    playerDropdownBtn.LayoutOrder = 2
    playerDropdownBtn.Parent = playersContent
    
    local selectedLabel = Instance.new("TextLabel")
    selectedLabel.Size = UDim2.new(1, -20, 0, 25)
    selectedLabel.Text = "Nenhum jogador selecionado"
    selectedLabel.TextColor3 = Color3.fromRGB(150,150,150)
    selectedLabel.BackgroundTransparency = 1
    selectedLabel.LayoutOrder = 3
    selectedLabel.Parent = playersContent
    
    -- Dropdown personalizado (simples)
    local dropdownFrame = nil
    playerDropdownBtn.MouseButton1Click:Connect(function()
        if dropdownFrame then dropdownFrame:Destroy(); dropdownFrame = nil return end
        dropdownFrame = Instance.new("Frame")
        dropdownFrame.Size = UDim2.new(0.9, 0, 0, 100)
        dropdownFrame.Position = UDim2.new(0.05, 0, 0, 40)
        dropdownFrame.BackgroundColor3 = Color3.fromRGB(30,30,40)
        dropdownFrame.BorderSizePixel = 0
        dropdownFrame.Parent = playersContent
        
        local list = Instance.new("ScrollingFrame")
        list.Size = UDim2.new(1, 0, 1, 0)
        list.BackgroundTransparency = 1
        list.CanvasSize = UDim2.new(0,0,0,0)
        list.ScrollBarThickness = 4
        list.Parent = dropdownFrame
        
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 2)
        layout.Parent = list
        
        local function refreshDropdown()
            for _, child in ipairs(list:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            local players = {}
            for _, p in ipairs(game.Players:GetPlayers()) do
                if p ~= Player then table.insert(players, p) end
            end
            if #players == 0 then
                local none = Instance.new("TextButton")
                none.Size = UDim2.new(1, 0, 0, 25)
                none.Text = "Nenhum jogador"
                none.BackgroundColor3 = Color3.fromRGB(50,50,60)
                none.Parent = list
            else
                for _, p in ipairs(players) do
                    local btn = Instance.new("TextButton")
                    btn.Size = UDim2.new(1, 0, 0, 30)
                    btn.Text = p.Name
                    btn.BackgroundColor3 = Color3.fromRGB(45,45,55)
                    btn.Parent = list
                    btn.MouseButton1Click:Connect(function()
                        Hub.SelectedPlayer = p
                        selectedLabel.Text = "Selecionado: " .. p.Name
                        dropdownFrame:Destroy()
                        dropdownFrame = nil
                    end)
                end
            end
            task.wait(0.05)
            list.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y)
        end
        refreshDropdown()
    end)
    
    local refreshPlayersBtn = Instance.new("TextButton")
    refreshPlayersBtn.Size = UDim2.new(0.9, 0, 0, 35)
    refreshPlayersBtn.Text = "Atualizar Lista"
    refreshPlayersBtn.BackgroundColor3 = Color3.fromRGB(55,55,70)
    refreshPlayersBtn.LayoutOrder = 4
    refreshPlayersBtn.Parent = playersContent
    refreshPlayersBtn.MouseButton1Click:Connect(function()
        if dropdownFrame then dropdownFrame:Destroy(); dropdownFrame = nil end
        Notify("Info", "Lista atualizada", 2)
    end)
    
    updateCanvas(playersContent)
    
    -- ==================== ABA BYPASS ====================
    local bypassContent = tabContents[3]
    
    local methodLabel = Instance.new("TextLabel")
    methodLabel.Size = UDim2.new(1, -20, 0, 25)
    methodLabel.Text = "Método de Bypass:"
    methodLabel.TextColor3 = Color3.fromRGB(200,200,200)
    methodLabel.BackgroundTransparency = 1
    methodLabel.LayoutOrder = 1
    methodLabel.Parent = bypassContent
    
    local methods = {"Cyrillic", "ZeroWidth", "Combined", "Diacritics", "Reverse", "Kamikaze"}
    local methodButtons = {}
    for i, m in ipairs(methods) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 35)
        btn.Text = m
        btn.BackgroundColor3 = (Hub.BypassMethod == m) and Color3.fromRGB(70,100,130) or Color3.fromRGB(40,40,50)
        btn.LayoutOrder = i+1
        btn.Parent = bypassContent
        btn.MouseButton1Click:Connect(function()
            Hub.BypassMethod = m
            for _, b in ipairs(methodButtons) do
                b.BackgroundColor3 = Color3.fromRGB(40,40,50)
            end
            btn.BackgroundColor3 = Color3.fromRGB(70,100,130)
            updatePreview()
            Notify("Bypass", "Método alterado para " .. m, 2)
        end)
        methodButtons[i] = btn
    end
    
    updateCanvas(bypassContent)
    
    -- ==================== ABA SPAMMER ====================
    local spamContent = tabContents[4]
    
    local spamToggle = Instance.new("TextButton")
    spamToggle.Size = UDim2.new(0.9, 0, 0, 40)
    spamToggle.Text = "Spammer: DESATIVADO"
    spamToggle.BackgroundColor3 = Color3.fromRGB(100,60,60)
    spamToggle.LayoutOrder = 1
    spamToggle.Parent = spamContent
    spamToggle.MouseButton1Click:Connect(function()
        Hub.SpammerActive = not Hub.SpammerActive
        spamToggle.Text = Hub.SpammerActive and "Spammer: ATIVADO" or "Spammer: DESATIVADO"
        spamToggle.BackgroundColor3 = Hub.SpammerActive and Color3.fromRGB(60,100,60) or Color3.fromRGB(100,60,60)
        if Hub.SpammerActive then
            task.spawn(function()
                while Hub.SpammerActive do
                    for _, msg in ipairs(Hub.SpammerMessages) do
                        if not Hub.SpammerActive then break end
                        SendMessage(msg, false)
                        task.wait(Hub.SpammerDelay)
                    end
                end
            end)
        end
    end)
    
    local delaySliderLabel = Instance.new("TextLabel")
    delaySliderLabel.Size = UDim2.new(1, -20, 0, 20)
    delaySliderLabel.Text = "Delay: " .. Hub.SpammerDelay .. "s"
    delaySliderLabel.TextColor3 = Color3.fromRGB(200,200,200)
    delaySliderLabel.BackgroundTransparency = 1
    delaySliderLabel.LayoutOrder = 2
    delaySliderLabel.Parent = spamContent
    
    local delaySlider = Instance.new("TextButton") -- Simulando slider com botões +/-
    delaySlider.Size = UDim2.new(0.9, 0, 0, 30)
    delaySlider.Text = "-   " .. Hub.SpammerDelay .. "   +"
    delaySlider.BackgroundColor3 = Color3.fromRGB(50,50,60)
    delaySlider.LayoutOrder = 3
    delaySlider.Parent = spamContent
    delaySlider.MouseButton1Click:Connect(function(input)
        local x = input.Mouse.X
        local btnPos = delaySlider.AbsolutePosition.X
        local btnWidth = delaySlider.AbsoluteSize.X
        local relative = (x - btnPos) / btnWidth
        if relative < 0.33 then
            Hub.SpammerDelay = math.max(1, Hub.SpammerDelay - 0.5)
        elseif relative > 0.66 then
            Hub.SpammerDelay = math.min(10, Hub.SpammerDelay + 0.5)
        end
        Hub.SpammerDelay = tonumber(string.format("%.1f", Hub.SpammerDelay))
        delaySliderLabel.Text = "Delay: " .. Hub.SpammerDelay .. "s"
        delaySlider.Text = "-   " .. Hub.SpammerDelay .. "   +"
    end)
    
    local msgListLabel = Instance.new("TextLabel")
    msgListLabel.Size = UDim2.new(1, -20, 0, 20)
    msgListLabel.Text = "Mensagens (separadas por vírgula):"
    msgListLabel.TextColor3 = Color3.fromRGB(200,200,200)
    msgListLabel.BackgroundTransparency = 1
    msgListLabel.LayoutOrder = 4
    msgListLabel.Parent = spamContent
    
    local msgInput = Instance.new("TextBox")
    msgInput.Size = UDim2.new(0.9, 0, 0, 40)
    msgInput.PlaceholderText = "Hello,How are you?,Bypass"
    msgInput.Text = table.concat(Hub.SpammerMessages, ",")
    msgInput.BackgroundColor3 = Color3.fromRGB(40,40,50)
    msgInput.TextColor3 = Color3.fromRGB(255,255,255)
    msgInput.LayoutOrder = 5
    msgInput.Parent = spamContent
    msgInput:GetPropertyChangedSignal("Text"):Connect(function()
        local txt = msgInput.Text
        local msgs = {}
        for m in string.gmatch(txt, "[^,]+") do
            local trimmed = m:match("^%s*(.-)%s*$")
            if trimmed ~= "" then table.insert(msgs, trimmed) end
        end
        if #msgs > 0 then Hub.SpammerMessages = msgs end
    end)
    
    updateCanvas(spamContent)
    
    -- Notificação inicial
    Notify("Meta Hub", "Carregado com sucesso! Use com responsabilidade.", 4)
    DebugLog("Hub inicializado")
end

-- Executar
CreateHub()