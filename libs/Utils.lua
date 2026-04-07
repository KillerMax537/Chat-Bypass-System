-- libs/Utils.lua
local Utils = {}

function Utils:Notify(Rayfield, title, content, duration)
    Rayfield:Notify({
        Title = title,
        Content = content,
        Duration = duration or 3
    })
end

return Utils