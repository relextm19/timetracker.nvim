local curl = require("plenary.curl")
local token = require("timetracker.token")
local helper = require("timetracker.helper")

local M = {}

local auth_layout
local current_mode = "register"
local auth_ns = vim.api.nvim_create_namespace("auth_ui")

local function next_input(curr, max)
    local next = (curr % max) + 1
    local input_name = "input" .. next

    auth_layout.wins[input_name]:focus()
    vim.cmd("startinsert")

    return next
end

local function new_user(email, password)
    return {
        email = email,
        password = password,
    }
end

local function submit_auth_form(email, password, endpoint, succes_msg, failure_msg)
    curl.post("http://localhost:42069/" .. endpoint, {
        body = vim.fn.json_encode(new_user(email, password)),
        headers = {
            content_type = "application/json"
        },
        callback = function(response)
            vim.schedule(function()
                if response.status == 201 or response.status == 200 then
                    local success, parsed = pcall(vim.fn.json_decode, response.body)
                    print(response.status)
                    if success and parsed.token then
                        token.save_token(parsed.token)
                        vim.notify(succes_msg .. " ", vim.log.levels.INFO)
                    else
                        vim.notify("Malformed response from server", vim.log.levels.ERROR)
                    end
                else
                    vim.notify(failure_msg .. " " .. response.status, vim.log.levels.ERROR)
                end
            end)
        end
    })
end

local function submit_register()
    local email    = vim.trim(auth_layout.wins.input1:lines(1, 1)[1]) or ""
    local password = vim.trim(auth_layout.wins.input2:lines(1, 1)[1]) or ""
    local confirm  = vim.trim(auth_layout.wins.input3:lines(1, 1)[1]) or ""
    -- FIXME: the notifications dont show up until you close the window
    if email == "" or password == "" then
        vim.notify("Email and Password are required!", vim.log.levels.ERROR)
        return
    end

    if password ~= confirm then
        vim.notify("Passwords do not match!", vim.log.levels.ERROR)
        return
    end

    auth_layout:close()
    auth_layout = nil

    submit_auth_form(email, password, "register", "user registered", "failed to register")

    vim.cmd("stopinsert")
end

local function submit_login()
    local email    = vim.trim(auth_layout.wins.input1:lines(1, 1)[1]) or ""
    local password = vim.trim(auth_layout.wins.input2:lines(1, 1)[1]) or ""
    if email == "" or password == "" then
        vim.notify("Email and Password are required!", vim.log.levels.ERROR)
        return
    end

    auth_layout:close()
    auth_layout = nil
    vim.cmd("stopinsert")

    submit_auth_form(email, password, "login", "user logged in", "failed to login")
end

local function build_inputs(form_keys)
    local inputs = {}

    table.insert(inputs, Snacks.win({ title = " Email ", border = "rounded", keys = form_keys }))
    table.insert(inputs, Snacks.win({ title = " Password ", border = "rounded", keys = form_keys }))
    table.insert(inputs, Snacks.win({ title = " Confirm Password ", border = "rounded", keys = form_keys, show = false }))

    return inputs
end

local function build_header_buf(mode, targets, text, container_width)
    local buf = vim.api.nvim_create_buf(false, true)

    local target = targets[mode]

    local centered_text = helper.center_text(text, container_width)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { centered_text })
    vim.bo[buf].modifiable = false

    local start_idx, end_idx = string.find(centered_text, target)
    vim.api.nvim_buf_set_extmark(buf, auth_ns, 0, start_idx - 1, {
        end_col = end_idx,
        hl_group = "DiagnosticInfo",
    })

    return buf
end

local function swap_layout()
    local header_text = ("[1] Register  [2] Login")
    local targets = {
        login = "%[2%] Login",
        register = "%[1%] Register"
    }
    local header_buf = build_header_buf(current_mode, targets, header_text, 50)
    auth_layout.wins.header:set_buf(header_buf)

    if current_mode == "register" then
        auth_layout.wins.input3:show()
    else
        auth_layout.wins.input3:hide()
    end
    for i = 1, 3 do
        if auth_layout.wins["input" .. i] then
            vim.api.nvim_buf_set_lines(auth_layout.wins["input" .. i].buf, 0, -1, false, {})
        end
    end

    auth_layout.wins.input1:focus()
end

local function build_layout()
    local width = 50
    local curr_win_idx = 1

    local form_keys = {
        ["<Tab>"] = {
            function()
                local input_count = current_mode == "login" and 2 or 3
                curr_win_idx = next_input(curr_win_idx, input_count)
            end,
            mode = { "n", "i" }
        },
        ["<CR>"] = {
            function()
                local fn = current_mode == "login" and submit_login or submit_register
                fn()
            end,
            mode = { "n", "i", "v" }
        },
        q = {
            function()
                if auth_layout then
                    auth_layout:close()
                    auth_layout = nil
                end
                vim.cmd("stopinsert")
            end,
            mode = { "n", "v" }
        },
        ["1"] = {
            function()
                current_mode = "register"
                swap_layout()
            end,
            mode = { "n", "i" }
        },
        ["2"] = {
            function()
                current_mode = "login"
                swap_layout()
            end,
            mode = { "n", "i" }
        },
    }

    local wins = {}
    local layout = {
        backdrop = 60,
        width = width,
        position = "float",
        box = "vertical",
    }

    local header_text = ("[1] Register  [2] Login")
    local targets = {
        login = "%[2%] Login",
        register = "%[1%] Register"
    }

    local header_buf = build_header_buf(current_mode, targets, header_text, width)
    wins.header = Snacks.win({ buf = header_buf, height = 1, focusable = false })
    table.insert(layout, { win = "header", height = 1 })
    local inputs = build_inputs(form_keys)

    for i, input in ipairs(inputs) do
        table.insert(layout, { win = "input" .. i, height = 1 })
        wins["input" .. i] = input
    end

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
    -- local existing_token = token.load_token()
    -- if existing_token then
    --     vim.notify("Already logged in", vim.log.levels.INFO)
    --     return
    -- end
    if auth_layout then
        auth_layout:close()
        auth_layout = nil
        vim.cmd("stopinsert")
        return
    else
        build_layout()
    end
end

return M
