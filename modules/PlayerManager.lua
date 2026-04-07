local PlayerManager = {}
PlayerManager.players = {}

function PlayerManager:updateList()
    local players = {}
    local localPlayer = game.Players.LocalPlayer
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= localPlayer then
            table.insert(players, player.Name)
        end
    end
    if #players == 0 then players = {"Nenhum outro jogador"} end
    self.players = players
    return players
end

return PlayerManager