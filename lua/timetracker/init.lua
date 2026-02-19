local sqlite = require("sqlite")

local M = {}

-- maybe change this to get the root markers from the lsp config
local root_markers = { ".git", "package.json", "Makefile", "Cargo.toml", ".mod" }
local start_times = {}

local db = sqlite({
    uri = vim.fs.normalize(vim.fn.stdpath("data") .. '/timetracker.db'),
    sessions = {
        ID          = true,
        FileName    = "text",
        ProjectName = "text",
        StartTime   = "integer",
        StartDate   = "text",
        EndTime     = "integer",
        EndDate     = "text",
    }
})

local function newSession(file_name, project_name, start_time, start_date, end_time, end_date)
    return {
        FileName    = file_name,
        ProjectName = project_name,
        StartTime   = start_time,
        StartDate   = start_date,
        EndTime     = end_time,
        EndDate     = end_date,
    }
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
                    local start_date = os.date("%Y-%m-%d", start_time)
                    local end_date = os.date("%Y-%m-%d", end_time)

                    local session = newSession(file_name, project_name, start_time, start_date, end_time, end_date)
                    db.sessions:insert(session)
                end

                start_times[event.buf] = nil
            end
        end
    })
end

return M
