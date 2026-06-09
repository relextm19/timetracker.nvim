local token = require("timetracker.token")

local M = {}

local auth_layout
local function close_auth_layout()
    if auth_layout then
        auth_layout:close()
        auth_layout = nil
    end
    vim.cmd("stopinsert")
end

local function submit_api_key()
    local api_key = vim.trim(auth_layout.wins.input1:lines(1, 1)[1]) or ""

    if api_key == "" then
        vim.notify("API key is required", vim.log.levels.ERROR)
        return
    end

    local success = token.save_token(api_key)
    if success then
        vim.notify("API key saved", vim.log.levels.INFO)
        close_auth_layout()
    end
end

local function build_layout()
    local width = 60

    local form_keys = {
        ["<CR>"] = {
            submit_api_key,
            mode = { "n", "i", "v" }
        },
        q = {
            close_auth_layout,
            mode = { "n", "i", "v" }
        },
    }

    local wins = {}
    local layout = {
        backdrop = 60,
        width = width,
        position = "float",
        box = "vertical",
    }

    local header_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(header_buf, 0, -1, false, { "[Enter] Save API Key  [q] Cancel" })
    vim.bo[header_buf].modifiable = false

    wins.header = Snacks.win({ buf = header_buf, height = 1, focusable = false })
    table.insert(layout, { win = "header", height = 1 })

    wins.input1 = Snacks.win({ title = " API Key ", border = "rounded", keys = form_keys })
    table.insert(layout, { win = "input1", height = 1 })

    auth_layout = Snacks.layout.new({
        layout = layout,
        wins = wins
    })

    vim.schedule(function()
        if auth_layout and auth_layout.wins.input1 then
            auth_layout.wins.input1:focus()
            vim.cmd("startinsert")
        end
    end)
end

M.toggle = function()
    if auth_layout then
        close_auth_layout()
        return
    else
        build_layout()
    end
end

return M
