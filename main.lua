local repoBase = "https://raw.githubusercontent.com/KillerMax537/Chat-Bypass-System/main/"

local function loadModule(path)
    local url = repoBase .. path
    local content = game:HttpGet(url)
    local fn, err = loadstring(content)
    if not fn then error("Erro ao carregar " .. path .. ": " .. err) end
    return fn()
end

local Rayfield = loadModule("libs/Rayfield.lua")
local Bypass = loadModule("modules/Bypass.lua")
local PlayerManager = loadModule("modules/PlayerManager.lua")
local ChatSender = loadModule("modules/ChatSender.lua")
local Interface = loadModule("ui/Interface.lua")

Interface:Initialize(Rayfield, Bypass, PlayerManager, ChatSender)