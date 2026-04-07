-- modules/Bypass.lua
local Bypass = {
    currentMethod = "Cyrillic",
    customMapping = {
        a = "а", e = "е", o = "о", p = "р", c = "с", x = "х", y = "у", k = "к", m = "м", t = "т"
    }
}

function Bypass:apply(text)
    if text == "" then return "" end
    if self.currentMethod == "Cyrillic" then
        return text:gsub("%a", function(c)
            local lower = c:lower()
            local mapped = self.customMapping[lower]
            if mapped then
                return (c:upper() == c) and mapped:upper() or mapped
            end
            return c
        end)
    elseif self.currentMethod == "ZeroWidth" then
        return table.concat({text:gsub(".", "%1\u{200B}")})
    elseif self.currentMethod == "Combined" then
        local cyrillicText = text:gsub("%a", function(c)
            local lower = c:lower()
            local mapped = self.customMapping[lower]
            if mapped then
                return (c:upper() == c) and mapped:upper() or mapped
            end
            return c
        end)
        return table.concat({cyrillicText:gsub(".", "%1\u{200B}")})
    end
    return text
end

function Bypass:setMethod(method)
    self.currentMethod = method
end

return Bypass