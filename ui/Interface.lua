-- ui/Interface.lua
local Interface = {}

function Interface:Initialize(Rayfield, Bypass, PlayerManager, ChatSender)
    local Window = Rayfield:CreateWindow({
        Name = "Chat Bypass System",
        LoadingTitle = "Carregando...",
        LoadingSubtitle = "",
        ConfigurationSaving = { Enabled = true, FolderName = "ChatBypassSystem", FileName = "Config" },
        Discord = { Enabled = false },
        KeySystem = false
    })

    local ChatTab = Window:CreateTab("Mensagens")
    local PlayersTab = Window:CreateTab("Jogadores")
    local SettingsTab = Window:CreateTab("Configurações")

    -- Chat Tab
    ChatTab:CreateSection("Sua Mensagem")
    local MessageInput = ChatTab:CreateInput({
        Name = "Mensagem",
        PlaceholderText = "Digite sua mensagem aqui...",
        RemoveTextAfterFocus = false,
        Callback = function() end
    })

    ChatTab:CreateSection("Pré-visualização (Bypass Aplicado)")
    local PreviewLabel = ChatTab:CreateParagraph({
        Name = "",
        Content = "Aguardando mensagem..."
    })

    MessageInput:GetPropertyChangedSignal("Text"):Connect(function()
        local text = MessageInput.Text
        if text == "" then
            PreviewLabel:Set("Aguardando mensagem...")
        else
            PreviewLabel:Set(Bypass:apply(text))
        end
    end)

    ChatTab:CreateButton({
        Name = "Enviar Mensagem Global",
        Callback = function()
            local success, msg = ChatSender:send(MessageInput.Text, false)
            if success then
                Rayfield:Notify({Title = "Sucesso", Content = msg, Duration = 2})
            else
                Rayfield:Notify({Title = "Erro", Content = msg, Duration = 4})
            end
        end
    })

    ChatTab:CreateButton({
        Name = "Enviar Mensagem Privada (PM)",
        Callback = function()
            local success, msg = ChatSender:send(MessageInput.Text, true)
            if success then
                Rayfield:Notify({Title = "Sucesso", Content = msg, Duration = 2})
            else
                Rayfield:Notify({Title = "Erro", Content = msg, Duration = 4})
            end
        end
    })

    -- Players Tab
    PlayersTab:CreateSection("Jogadores Online")
    local playerDropdown = PlayersTab:CreateDropdown({
        Name = "Selecione um Jogador",
        Options = {"Carregando..."},
        CurrentOption = "Carregando...",
        Callback = function(option)
            for _, p in ipairs(game.Players:GetPlayers()) do
                if p.Name == option then
                    ChatSender.selectedPlayer = p
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

    local function updatePlayerList()
        local players = PlayerManager:updateList()
        playerDropdown:SetOptions(players)
        if ChatSender.selectedPlayer and not table.find(players, ChatSender.selectedPlayer.Name) then
            ChatSender.selectedPlayer = nil
            selectedLabel:Set("Nenhum jogador selecionado")
        elseif ChatSender.selectedPlayer then
            selectedLabel:Set("Selecionado: " .. ChatSender.selectedPlayer.Name)
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

    -- Settings Tab
    SettingsTab:CreateSection("Métodos de Bypass")
    SettingsTab:CreateDropdown({
        Name = "Método",
        Options = {"Cyrillic", "ZeroWidth", "Combined"},
        CurrentOption = "Cyrillic",
        Callback = function(option)
            Bypass:setMethod(option)
            local text = MessageInput.Text
            if text ~= "" then
                PreviewLabel:Set(Bypass:apply(text))
            end
            Rayfield:Notify({Title = "Bypass", Content = "Método alterado para " .. option, Duration = 2})
        end
    })

    Rayfield:Notify({Title = "Sistema Carregado", Content = "UI inicializada com sucesso!", Duration = 5})
end

return Interface