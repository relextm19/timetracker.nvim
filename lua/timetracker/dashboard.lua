local session = require("timetracker.sessions")
local helper = require("timetracker.helper")

local M = {}

local dashboard_layout

local function close_dashboard()
    if dashboard_layout then
        dashboard_layout:close()
        dashboard_layout = nil
    end
end

local function as_list(value)
    if type(value) == "table" then
        return value
    end

    return {}
end

local function get_wrapped_lines(item, name_col_width)
    local total_time = tonumber(item.totalTime) or 0
    local time_str = helper.format_time(total_time)
    local result = {}
    local remaining_name = tostring(item.name or "Unknown")

    while #remaining_name > name_col_width do
        local chunk = string.sub(remaining_name, 1, name_col_width)
        table.insert(result, chunk)

        remaining_name = string.sub(remaining_name, name_col_width + 1)
    end

    local padded_name = helper.pad_right(remaining_name, name_col_width)
    table.insert(result, padded_name .. " " .. time_str)

    return result
end

local function build_list(items, win)
    items = as_list(items)
    local lines = {}

    local longest_time_str = -1
    for _, item in ipairs(items) do
        longest_time_str = math.max(longest_time_str, #helper.format_time(tonumber(item.totalTime) or 0))
    end
    -- -1 accounts for the space in the final string
    local name_col_width = math.max(1, vim.api.nvim_win_get_width(win) - longest_time_str - 1)

    for _, item in ipairs(items) do
        local wrapped_lines = get_wrapped_lines(item, name_col_width)

        for _, line in ipairs(wrapped_lines) do
            table.insert(lines, line)
        end
    end
    return lines
end

local function update_dashboard(data)
    if not dashboard_layout then
        return
    end

    local _, payload = next(data)

    if not payload then
        return
    end

    local project_lines = build_list(payload.byProject, dashboard_layout.wins.projects.win)
    local file_lines = build_list(payload.byFile, dashboard_layout.wins.files.win)
    local language_lines = build_list(payload.byLanguage, dashboard_layout.wins.languages.win)
    local time_lines = build_list(payload.byTime, dashboard_layout.wins.time_frame.win)

    vim.api.nvim_buf_set_lines(dashboard_layout.wins.projects.buf, 0, -1, false, project_lines)
    vim.api.nvim_buf_set_lines(dashboard_layout.wins.files.buf, 0, -1, false, file_lines)
    vim.api.nvim_buf_set_lines(dashboard_layout.wins.languages.buf, 0, -1, false, language_lines)
    vim.api.nvim_buf_set_lines(dashboard_layout.wins.time_frame.buf, 0, -1, false, time_lines)
end

local function toggle_dashboard()
    if dashboard_layout then
        close_dashboard()
    else
        local dashboard_keys = {
            q = {
                close_dashboard,
                mode = { "n", "v" }
            },
        }

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
                    { win = "projects" },
                    { win = "files" },
                },
                {
                    box = "horizontal",
                    height = 0.3,
                    { win = "languages" },
                    { win = "time_frame" },
                }
            },

            wins = {
                projects = Snacks.win({ title = "  Projects  ", border = "rounded", keys = dashboard_keys }),
                files = Snacks.win({ title = "  Files  ", border = "rounded", keys = dashboard_keys }),
                languages = Snacks.win({ title = "  Languages  ", border = "rounded", keys = dashboard_keys }),
                time_frame = Snacks.win({ title = "  Time Frame  ", border = "rounded", keys = dashboard_keys }),
            }
        })

        session.fetch_sessions(function(data)
            update_dashboard(data)
        end)
    end
end

M.toggle = toggle_dashboard

return M
