-- main.lua
-- Este é o único script que você executa manualmente no executor.

local repoBase = "https://raw.githubusercontent.com/KillerMax537/Chat-Bypass-System/main/"

-- Função segura para carregar um módulo do GitHub.
local function loadModule(path)
    local url = repoBase .. path
    local content = game:HttpGet(url)
    local moduleFunction, loadError = loadstring(content)
    if not moduleFunction then
        error("Falha ao carregar o módulo " .. path .. ": " .. tostring(loadError))
    end
    return moduleFunction()
end

-- Carrega as bibliotecas e módulos na ordem correta.
local Rayfield = loadModule("libs/Rayfield.lua")
local Utils = loadModule("libs/Utils.lua")
local Bypass = loadModule("modules/Bypass.lua")
local PlayerManager = loadModule("modules/PlayerManager.lua")
local ChatSender = loadModule("modules/ChatSender.lua")
local Interface = loadModule("ui/Interface.lua")

-- Inicializa a UI e o sistema, passando os módulos carregados como dependências.
Interface:Initialize(Rayfield, Bypass, PlayerManager, ChatSender)