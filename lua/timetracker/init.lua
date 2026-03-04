local curl = require("plenary.curl")

local M = {}

-- TODO: maybe change this to get the root markers from the lsp config
local root_markers = { ".git", "package.json", "Makefile", "Cargo.toml", ".mod" }
local start_times = {}

local function new_session(file_name, project_name, language_name, start_time, start_date, end_time, end_date)
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

                    local session = new_session(file_name, project_name, language_name, start_time, start_date, end_time,
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

local function next_input(curr)
    local next = (curr % 3) + 1
    local input_name = "input" .. next

    login_layout.wins[input_name]:focus()
    vim.cmd("startinsert")

    return next
end

local function new_user(email, password)
    return {
        email = email,
        password = password,
    }
end

local function save_token(token)
    local data_dir = vim.fn.stdpath("data")
    local token_path = data_dir .. "/timetracker_token" -- Name this for your plugin

    local file = io.open(token_path, "w")
    if not file then
        vim.notify("Failed to open file for saving token", vim.log.levels.ERROR)
        return false
    end

    file:write(token)
    file:close()

    --read only
    vim.fn.setfperm(token_path, "r--------")

    return true
end

local function submit_form()
    local email    = vim.trim(login_layout.wins.input1:lines(1, 1)[1]) or ""
    local password = vim.trim(login_layout.wins.input2:lines(1, 1)[1]) or ""
    local confirm  = vim.trim(login_layout.wins.input3:lines(1, 1)[1]) or ""
    if email == "" or password == "" then
        vim.notify("Email and Password are required!", vim.log.levels.ERROR)
        return
    end

    if password ~= confirm then
        vim.notify("Passwords do not match!", vim.log.levels.ERROR)
        return
    end

    login_layout:close()
    login_layout = nil

    vim.cmd("stopinsert")

    curl.post("http://localhost:42069/users", {
        body = vim.fn.json_encode(new_user(email, password)),
        print(vim.fn.json_encode(new_user(email, password))),
        headers = {
            content_type = "application/json"
        },
        callback = function(response)
            vim.schedule(function()
                if response.status == 201 then
                    local succes, parsed = pcall(vim.fn.json_decode, response.body)
                    if succes and parsed.token then
                        save_token(parsed.token)
                        vim.notify("Logged in successfully", vim.log.levels.INFO)
                    else
                        vim.notify("Malformed response from server", vim.log.levels.ERROR)
                    end
                else
                    vim.notify("Failed to login" .. response.status, vim.log.levels.ERROR)
                end
            end)
        end
    })
end

local function open_login()
    if login_layout then
        login_layout:close()
        login_layout = nil
    end

    local curr_win_idx = 1

    local form_keys = {
        ["<Tab>"] = {
            function()
                curr_win_idx = next_input(curr_win_idx)
            end,
            mode = { "n", "i" }
        },
        ["<CR>"] = { submit_form, mode = { "n", "i", "v" } },
        q = {
            --go dry
            function()
                if login_layout then
                    login_layout:close()
                    login_layout = nil
                end
                vim.cmd("stopinsert")
            end,
            mode = { "n", "v" }
        }
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
