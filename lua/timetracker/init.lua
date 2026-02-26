local curl = require("plenary.curl")

local M = {}

-- TODO: maybe change this to get the root markers from the lsp config
local root_markers = { ".git", "package.json", "Makefile", "Cargo.toml", ".mod" }
local start_times = {}

local function newSession(file_name, project_name, language_name, start_time, start_date, end_time, end_date)
    return {
        fileName     = file_name,
        projectName  = project_name,
        languageName = language_name,
        startTime    = start_time,
        startDate    = start_date,
        endTime      = end_time,
        endDate      = end_date,
    }
end

local function sendSession(session)
    curl.post("http://localhost:42069/sessions", {
        body = vim.fn.json_encode(session),
        headers = {
            content_type = "application/json"
        },
        callback = function(response)
            -- We must use vim.schedule to interact with Neovim UI from a background task
            vim.schedule(function()
                if response.status == 201 then
                    vim.notify("Session tracked successfully!", vim.log.levels.INFO)
                else
                    vim.notify("Failed to track session: " .. response.status, vim.log.levels.ERROR)
                end
            end)
        end
    })
end

local function getProjectName(file_path)
    local marker_path = vim.fs.find(root_markers, { upward = true, path = file_path })[1]
    local project_name = "No project"
    if marker_path then
        local project_root = vim.fs.dirname(marker_path)
        project_name = vim.fn.fnamemodify(project_root, ":t")
    end
    return project_name
end

M.setup = function()
    local group = vim.api.nvim_create_augroup("TimeTrackerGroup", { clear = true })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function(event)
            start_times[event.buf] = os.time()
        end,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
        group = group,
        callback = function(event)
            local start_time = start_times[event.buf]
            if start_time then
                local end_time = os.time()
                local time_spent = end_time - start_time
                local file_path = vim.api.nvim_buf_get_name(event.buf)
                local file_name = vim.fn.fnamemodify(file_path, ":t")
                if time_spent > 0 and (file_name and file_name ~= "") then
                    local project_name = getProjectName(file_path)
                    local language_name = vim.fn.fnamemodify(file_name, ":e")
                    local start_date = os.date("%Y-%m-%d", start_time)
                    local end_date = os.date("%Y-%m-%d", end_time)

                    local session = newSession(file_name, project_name, language_name, start_time, start_date, end_time,
                        end_date)
                    -- sendSession(session)
                end

                start_times[event.buf] = nil
            end
        end
    })
end

local dashboard_layout

local function open_dashboard()
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

local login_layout

local function next_win()
    vim.cmd("wincmd w")
    vim.cmd("startinsert")
end

local function prev_win()
    vim.cmd("wincmd W")
    vim.cmd("startinsert")
end

local function open_login()
    if login_layout then
        login_layout:close()
        login_layout = nil
    end

    local form_keys = {
        ["<Tab>"] = { next_win, mode = { "n", "i" } },
        ["<S-Tab>"] = { prev_win, mode = { "n", "i" } },
        -- ["<CR>"] = { submit_form, mode = { "n", "i" } },
        q = "close"
    }

    login_layout = Snacks.layout.new({
        layout = {
            backdrop = 60,
            width = 50,
            position = "float",
            box = "vertical",
            { win = "input1", height = 1 },
            { win = "input2", height = 1 },
            { win = "input3", height = 1 },
        },
        wins = {
            input1 = Snacks.win({ title = " Email ", border = "rounded", keys = form_keys }),
            input2 = Snacks.win({ title = " Password ", border = "rounded", keys = form_keys }),
            input3 = Snacks.win({ title = " Confirm Password ", border = "rounded", keys = form_keys }),
        }
    })

    vim.schedule(function()
        if login_layout and login_layout.wins.input1 then
            login_layout.wins.input1:focus()
            vim.cmd("startinsert")
        end
    end)
end

vim.keymap.set("n", "<leader>t", function() open_dashboard() end)
vim.keymap.set("n", "<leader>l", function() open_login() end)

return M
