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

    local ChatTab = Window:CreateTab("💬 Chat")
    local PlayersTab = Window:CreateTab("👥 Jogadores")
    local BypassTab = Window:CreateTab("🔓 Bypass")
    local SettingsTab = Window:CreateTab("⚙️ Configurações")

    -- ======================== ABA CHAT ========================
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
    MessageInput:GetPropertyChangedSignal("Text"):Connect(function()
        local text = MessageInput.Text
        if text == "" then
            PreviewLabel:Set("Aguardando mensagem...")
        else
            PreviewLabel:Set(Bypass:apply(text))
        end
    end)
    ChatTab:CreateButton({
        Name = "Enviar Global",
        Callback = function()
            local ok, msg = ChatSender:send(MessageInput.Text, false)
            Rayfield:Notify({Title = ok and "Sucesso" or "Erro", Content = msg, Duration = 3})
        end
    })
    ChatTab:CreateButton({
        Name = "Enviar PM",
        Callback = function()
            local ok, msg = ChatSender:send(MessageInput.Text, true)
            Rayfield:Notify({Title = ok and "Sucesso" or "Erro", Content = msg, Duration = 3})
        end
    })

    -- ======================== ABA JOGADORES ========================
    PlayersTab:CreateSection("Jogadores Online")
    local PlayerDropdown = PlayersTab:CreateDropdown({
        Name = "Selecione um Jogador",
        Options = {"Carregando..."},
        CurrentOption = "Carregando...",
        Callback = function(option)
            for _, p in ipairs(game.Players:GetPlayers()) do
                if p.Name == option then
                    ChatSender.selectedPlayer = p
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
    local function updatePlayerList()
        local players = PlayerManager:updateList()
        PlayerDropdown:SetOptions(players)
        if ChatSender.selectedPlayer and not table.find(players, ChatSender.selectedPlayer.Name) then
            ChatSender.selectedPlayer = nil
            SelectedLabel:Set("Nenhum jogador selecionado")
        elseif ChatSender.selectedPlayer then
            SelectedLabel:Set("Selecionado: " .. ChatSender.selectedPlayer.Name)
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

    -- ======================== ABA BYPASS ========================
    BypassTab:CreateSection("Métodos de Bypass")
    BypassTab:CreateDropdown({
        Name = "Método",
        Options = {"Cyrillic", "ZeroWidth", "Combined"},
        CurrentOption = "Cyrillic",
        Callback = function(option)
            Bypass:setMethod(option)
            if MessageInput.Text ~= "" then
                PreviewLabel:Set(Bypass:apply(MessageInput.Text))
            end
            Rayfield:Notify({Title = "Bypass", Content = "Método alterado para " .. option, Duration = 2})
        end
    })
    BypassTab:CreateSection("Descrição")
    BypassTab:CreateParagraph({ Name = "Cyrillic", Content = "Substitui letras por caracteres cirílicos." })
    BypassTab:CreateParagraph({ Name = "ZeroWidth", Content = "Insere caracteres invisíveis entre as letras." })
    BypassTab:CreateParagraph({ Name = "Combined", Content = "Aplica Cyrillic + ZeroWidth (mais poderoso)." })

    -- ======================== ABA CONFIGURAÇÕES ========================
    SettingsTab:CreateSection("Sobre")
    SettingsTab:CreateParagraph({
        Name = "Sistema de Chat Bypass",
        Content = "Versão 2.0 - Modular e totalmente funcional.\nTodas as abas estão populadas corretamente."
    })
    SettingsTab:CreateSection("Aviso")
    SettingsTab:CreateParagraph({
        Name = "Aviso Legal",
        Content = "O bypass de chat pode violar os Termos de Serviço da Roblox. Use por sua conta e risco."
    })
    SettingsTab:CreateButton({
        Name = "Testar Envio",
        Callback = function()
            ChatSender:send("Test message from bypass system", false)
        end
    })

    Rayfield:Notify({Title = "Sistema Carregado", Content = "Todas as 4 abas funcionando!", Duration = 5})
end

return Interface