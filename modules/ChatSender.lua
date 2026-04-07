local ChatSender = {}
ChatSender.selectedPlayer = nil

function ChatSender:send(message, isPrivate)
    if message == "" then
        return false, "Digite uma mensagem!"
    end
    if isPrivate and not self.selectedPlayer then
        return false, "Selecione um jogador para o PM!"
    end
    local finalMessage = message
    if isPrivate then
        finalMessage = "/w " .. self.selectedPlayer.Name .. " " .. finalMessage
    end
    local success = false
    local textChatService = game:GetService("TextChatService")
    local textChannels = textChatService:FindFirstChild("TextChannels")
    if textChannels then
        local generalChannel = textChannels:FindFirstChild("RBXGeneral") or textChannels:FindFirstChild("General")
        if generalChannel then
            local ok = pcall(function() generalChannel:SendAsync(finalMessage) end)
            if ok then success = true end
        end
    end
    if not success then
        local ok = pcall(function() game:GetService("Chat"):Chat(finalMessage) end)
        if ok then success = true end
    end
    if success then
        return true, "Mensagem enviada!"
    else
        return false, "Falha ao enviar mensagem."
    end
end

return ChatSender