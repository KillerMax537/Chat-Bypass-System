local Bypass = {
    currentMethod = "Cyrillic",
    customMapping = {
        a="а", b="ь", c="с", e="е", g="ɡ", h="һ", i="і", k="к",
        m="м", n="п", o="о", p="р", r="г", s="ѕ", t="т", u="υ", x="х", y="у"
    }
}

function Bypass:apply(text)
    if text == "" then return "" end
    if self.currentMethod == "Cyrillic" then
        local result = ""
        for i = 1, #text do
            local char = text:sub(i, i)
            local lower = char:lower()
            local mapped = self.customMapping[lower]
            if mapped then
                result = result .. (char:upper() == char and mapped:upper() or mapped)
            else
                result = result .. char
            end
        end
        return result
    elseif self.currentMethod == "ZeroWidth" then
        local zwsp = "\u{200B}"
        local result = ""
        for i = 1, #text do
            result = result .. text:sub(i, i) .. zwsp
        end
        return result
    elseif self.currentMethod == "Combined" then
        local cyr = self:apply(text) -- chama o cyrillic (mas cuidado para não loop)
        -- Vamos fazer manualmente
        local cyrillicText = ""
        for i = 1, #text do
            local char = text:sub(i, i)
            local lower = char:lower()
            local mapped = self.customMapping[lower]
            if mapped then
                cyrillicText = cyrillicText .. (char:upper() == char and mapped:upper() or mapped)
            else
                cyrillicText = cyrillicText .. char
            end
        end
        local zwsp = "\u{200B}"
        local result = ""
        for i = 1, #cyrillicText do
            result = result .. cyrillicText:sub(i, i) .. zwsp
        end
        return result
    end
    return text
end

function Bypass:setMethod(method)
    self.currentMethod = method
end

return Bypass