local session = require("timetracker.session")

local M = {}

local dashboard_layout

local function format_time(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    return string.format("%dh %dm %ds", hours, minutes, secs)
end

local function get_wrapped_lines(item, name_col_width)
    local name_width = #item.name
    local time_str = format_time(item.totalTime)
    local result = {}

    if name_width <= name_col_width then
        table.insert(result, string.format("%-" .. name_col_width .. "s %s", item.name, time_str))
    else
        local lhs = string.sub(item.name, 1, name_col_width)
        local rhs = string.sub(item.name, name_col_width + 1)

        table.insert(result, string.format("%-" .. name_col_width .. "s", lhs))
        table.insert(result, string.format("%-" .. name_col_width .. "s %s", rhs, time_str))
    end

    return result
end

local function build_list(items, win)
    local lines = {}
    local name_col_width = 20

    for _, item in ipairs(items) do
        local wrapped_lines = get_wrapped_lines(item, name_col_width)

        for _, line in ipairs(wrapped_lines) do
            table.insert(lines, line)
        end
    end
    return lines
end

local function update_dashboard(data)
    local project_lines = build_list(data.byProject, dashboard_layout.wins.projects.win)
    local file_lines = build_list(data.byFile, dashboard_layout.wins.files.win)
    local language_lines = build_list(data.byLanguage, dashboard_layout.wins.languages.win)

    vim.api.nvim_buf_set_lines(dashboard_layout.wins.projects.buf, 0, -1, false, project_lines)
    vim.api.nvim_buf_set_lines(dashboard_layout.wins.files.buf, 0, -1, false, file_lines)
    vim.api.nvim_buf_set_lines(dashboard_layout.wins.languages.buf, 0, -1, false, language_lines)
end

local function toggle_dashboard()
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
                    { win = "projects", width = 0.5 },
                    { win = "files",    width = 0.5 },
                },
                { win = "languages", height = 0.3 },
            },

            wins = {
                projects = Snacks.win({ title = "  Projects  ", border = "rounded" }),
                files = Snacks.win({ title = "  Files  ", border = "rounded" }),
                languages = Snacks.win({ title = "  Languages  ", border = "rounded" }),
            }
        })

        session.fetch_sessions(function(data)
            update_dashboard(data)
        end)
    end
end

M.toggle = toggle_dashboard

return M
