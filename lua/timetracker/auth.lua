local curl = require("plenary.curl")

local M = {}

local auth_layout
local current_mode = "login"

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

local function save_token(token)
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

local function load_token()
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

local function submit_register()
    local email    = vim.trim(auth_layout.wins.input1:lines(1, 1)[1]) or ""
    local password = vim.trim(auth_layout.wins.input2:lines(1, 1)[1]) or ""
    local confirm  = vim.trim(auth_layout.wins.input3:lines(1, 1)[1]) or ""
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

    vim.cmd("stopinsert")

    curl.post("http://localhost:42069/register", {
        body = vim.fn.json_encode(new_user(email, password)),
        headers = {
            content_type = "application/json"
        },
        callback = function(response)
            vim.schedule(function()
                if response.status == 201 then
                    local success, parsed = pcall(vim.fn.json_decode, response.body)
                    if success and parsed.token then
                        save_token(parsed.token)
                        vim.notify("Logged in successfully", vim.log.levels.INFO)
                    else
                        vim.notify("Malformed response from server", vim.log.levels.ERROR)
                    end
                else
                    vim.notify("Failed to register: " .. response.status, vim.log.levels.ERROR)
                end
            end)
        end
    })
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

    curl.post("http://localhost:42069/login", {
        body = vim.fn.json_encode(new_user(email, password)),
        headers = {
            content_type = "application/json"
        },
        callback = function(response)
            vim.schedule(function()
                if response.status == 200 then
                    local success, parsed = pcall(vim.fn.json_decode, response.body)
                    if success and parsed.token then
                        save_token(parsed.token)
                        vim.notify("Logged in successfully", vim.log.levels.INFO)
                    else
                        vim.notify("Malformed response from server", vim.log.levels.ERROR)
                    end
                else
                    vim.notify("Failed to login: " .. response.status, vim.log.levels.ERROR)
                end
            end)
        end
    })
end

local function build_inputs(title, form_keys)
    local inputs = {}

    table.insert(inputs, Snacks.win({ title = " Email ", border = "rounded", keys = form_keys }))
    table.insert(inputs, Snacks.win({ title = " Password ", border = "rounded", keys = form_keys }))

    if title == "register" then
        table.insert(inputs, Snacks.win({ title = " Confirm Password ", border = "rounded", keys = form_keys }))
    end

    return inputs
end

local function build_layout()
    local submit_fn = current_mode == "login" and submit_login or submit_register
    local input_count = current_mode == "login" and 2 or 3

    local curr_win_idx = 1

    local form_keys = {
        ["<Tab>"] = {
            function()
                curr_win_idx = next_input(curr_win_idx, input_count)
            end,
            mode = { "n", "i" }
        },
        ["<CR>"] = { submit_fn, mode = { "n", "i", "v" } },
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
                current_mode = "login"
                auth_layout:close()
                auth_layout = nil
                build_layout()
            end,
            mode = { "n", "i" }
        },
        ["2"] = {
            function()
                current_mode = "register"
                auth_layout:close()
                auth_layout = nil
                build_layout()
            end,
            mode = { "n", "i" }
        }
    }

    local wins = {}
    local layout = {
        backdrop = 60,
        width = 50,
        position = "float",
        box = "vertical",
    }

    local title = current_mode == "login" and "login" or "register"
    local inputs = build_inputs(title, form_keys)

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
    local existing_token = load_token()
    if existing_token then
        vim.notify("Already logged in", vim.log.levels.INFO)
        return
    end

    if auth_layout then
        auth_layout:close()
        auth_layout = nil
        vim.cmd("stopinsert")
        return
    end

    build_layout()
end

M.load_token = load_token

return M
