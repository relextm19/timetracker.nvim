local auth = require("timetracker.auth")
local session = require("timetracker.session")
local dashboard = require("timetracker.dashboard")
local token = require("timetracker.token")

local M = {}

M.setup = function()
    session.setup()

    if not token.load_token() then
        vim.defer_fn(function()
            auth.toggle()
        end, 100)
    end

    vim.keymap.set("n", "<leader>t", function() dashboard.toggle() end)
    vim.keymap.set("n", "<leader>l", function() auth.toggle() end)
end

return M
