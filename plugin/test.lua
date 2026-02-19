local M = {}

M.setup = function()
    print('setup run')
    vim.api.nvim_create_autocmd("BufEnter", {
        callback = function()
            print("file switched")
        end,
    })
end

return M
