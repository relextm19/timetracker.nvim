local curl = require("plenary.curl")
local auth = require("timetracker.auth")

local M = {}

local root_markers = { ".git", "package.json", "Makefile", "Cargo.toml", ".mod" }
local start_times = {}
local token = auth.load_token()

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
    local headers = {
        content_type = "application/json"
    }
    if token then
        headers["Authorization"] = "Bearer " .. token
    else
        vim.notify("Token not present", vim.log.levels.ERROR)
        return
    end

    curl.post("http://localhost:42069/session", {
        body = vim.fn.json_encode(session),
        headers = headers,
        callback = function(response)
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

                    local session = new_session(file_name, project_name, language_name, start_time, start_date, end_time, end_date)
                    sendSession(session)
                end

                start_times[event.buf] = nil
            end
        end
    })
end

return M
