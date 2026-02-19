local helper = require('timetracker.helper')

local M = {}

M.setup = function()
    local group = vim.api.nvim_create_augroup("TimeTrackerGroup", { clear = true })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function(event)
            print("Entered buffer: ", helper.getFileNameFromPath(event.file))
        end,
    })
end

return M
