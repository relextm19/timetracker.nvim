local M = {}

local function findLast(s, t)
    local curr = 1
    local last_match = nil
    while true do
        local i = string.find(s, t, curr)
        if i == nil then return last_match end
        last_match = i
        curr = i + 1
    end
end

M.getFileNameFromPath = function(fileName)
    local i = findLast(fileName, "/")
    if i == nil then return fileName end
    return string.sub(fileName, i + 1)
end

return M
