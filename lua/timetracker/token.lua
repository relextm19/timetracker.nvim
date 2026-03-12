local M = {}

M.save_token = function(token)
    local data_dir = vim.fn.stdpath("data")
    local token_path = data_dir .. "/timetracker_token"

    local file = io.open(token_path, "w")
    if not file then
        vim.notify("Failed to open file for saving token", vim.log.levels.ERROR)
        return false
    end

    file:write(token)
    file:close()

    vim.fn.setfperm(token_path, "r--------")

    return true
end

M.load_token = function()
    local data_dir = vim.fn.stdpath("data")
    local token_path = data_dir .. "/timetracker_token"

    local file = io.open(token_path, "r")
    if not file then
        return nil
    end

    local token = file:read("*all")
    file:close()

    return token and token ~= "" and token or nil
end

return M
