local auth = require("timetracker.auth")
local session = require("timetracker.session")

local M = {}

local dashboard_layout

local function toggle_dashboard()
    if dashboard_layout then
        dashboard_layout:close()
        dashboard_layout = nil
    else
        dashboard_layout = Snacks.layout.new({
            layout = {
                backdrop = 60,
                width = 0.8,
                height = 0.8,
                position = "float",
                box = "vertical",
                {
                    box = "horizontal",
                    height = 0.7,
                    { win = "left_pane",  width = 0.5 },
                    { win = "right_pane", width = 0.5 },
                },
                { win = "bottom_pane", height = 0.3 },
            },

            wins = {
                left_pane = Snacks.win({ title = "  Projects  ", border = "rounded" }),
                right_pane = Snacks.win({ title = "  Files  ", border = "rounded" }),
                bottom_pane = Snacks.win({ title = "  Languages  ", border = "rounded" }),
            }
        })
    end
end

M.setup = function()
    session.setup()

    if not auth.load_token() then
        vim.defer_fn(function()
            auth.toggle()
        end, 100)
    end

    vim.keymap.set("n", "<leader>t", function() toggle_dashboard() end)
    vim.keymap.set("n", "<leader>l", function() auth.toggle() end)
end

return M
