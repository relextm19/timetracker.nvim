local M = {}

M.pad_right = function(str, target_width)
    local spaces_needed = math.max(0, target_width - #str)
    return str .. string.rep(" ", spaces_needed)
end

M.format_time = function(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    return string.format("%d:%02d:%02d", hours, minutes, secs)
end


M.center_text = function(text, containter_width)
    local text_width = vim.fn.strdisplaywidth(text)

    local padding_amount = math.floor((containter_width - text_width) / 2)

    local left_padding = string.rep(" ", math.max(0, padding_amount))

    return left_padding .. text
end

return M
