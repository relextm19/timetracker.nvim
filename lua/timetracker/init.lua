local sqlite = require("sqlite")

local M = {}

-- TODO: maybe change this to get the root markers from the lsp config
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

local function make_win(opts, enter, content)
    local buf = vim.api.nvim_create_buf(false, true)
    if content then vim.api.nvim_buf_set_lines(buf, 0, -1, false, content) end
    local win = vim.api.nvim_open_win(buf, enter, opts)
    return win
end

local function create_header(starting_row, starting_col, bg_width, content)
    local content_width = string.len(content[1])
    local col = math.floor((bg_width - content_width) / 2)

    local opts = {
        relative = "editor",
        width = content_width,
        height = 1,
        row = starting_row,
        col = starting_col + col,
        style = "minimal",
        zindex = 67,
    }

    return make_win(opts, false, content)
end

local function create_background(width, height, row, col)
    local opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
    }

    return make_win(opts, true)
end

local function openFloatingWindow(ratio)
    local bg_width = math.floor(vim.o.columns * ratio)
    local bg_height = math.floor(vim.o.lines * ratio)
    local start_row = math.floor((vim.o.lines - bg_height) / 2)
    local start_col = math.floor((vim.o.columns - bg_width) / 2)
    local bg_win = create_background(bg_width, bg_height, start_row, start_col)
    local header_win = create_header(start_row, start_col, bg_width, { "[1] languages | [2] projects" })
    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(bg_win),
        callback = function()
            if vim.api.nvim_win_is_valid(header_win) then
                vim.api.nvim_win_close(header_win, true)
            end
        end,
        once = true
    })
end

vim.keymap.set("n", "<leader>t", function() openFloatingWindow(0.7) end)
return M
