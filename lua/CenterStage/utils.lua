local config = require('CenterStage.config')

local M = {}

local namespace = vim.api.nvim_create_namespace('center_stage_phantom')

local function is_disabled(bufnr)
    local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
    return vim.tbl_contains(config.options.disable_for_ft, filetype)
end

local function clear_phantom_lines(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
end

local function add_phantom_lines(bufnr, start_line, count)
    local last_line = vim.api.nvim_buf_line_count(bufnr)
    for i = 0, count - 1 do
        if start_line + i <= last_line then
            vim.api.nvim_buf_set_extmark(bufnr, namespace, start_line + i - 1, 0, {
                virt_lines = {{{"", "NonText"}}},
            })
        end
    end
end

local function center_cursor()
    local bufnr = vim.api.nvim_get_current_buf()

    if is_disabled(bufnr) then return end

    local window = vim.api.nvim_get_current_win()
    local cursor = vim.api.nvim_win_get_cursor(window)
    local cursor_line, cursor_col = cursor[1], cursor[2]
    local window_height = vim.api.nvim_win_get_height(window)
    local buffer_line_count = vim.api.nvim_buf_line_count(bufnr)
    local middle_line = math.floor(window_height / 2)

    -- clear_phantom_lines(bufnr)


    if buffer_line_count - cursor_line < middle_line then
        vim.opt_local.scrolloff = 0
        local phantom_lines_needed = math.max(0, middle_line - (buffer_line_count - cursor_line))

        if phantom_lines_needed > 0 then
            add_phantom_lines(bufnr, buffer_line_count, phantom_lines_needed)
        end

        local ideal_top = math.max(1, cursor_line - middle_line)
        local view = vim.fn.winsaveview()

        if view.topline ~= ideal_top then
            view.topline = ideal_top
            vim.fn.winrestview(view)
            vim.api.nvim_win_set_cursor(window, {cursor_line, cursor_col})
        end
        vim.opt_local.scrolloff = 999
    end
end

function M.create_autocmd()
    vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
        group = vim.api.nvim_create_augroup("CenterCursor", { clear = true }),
        callback = center_cursor
    })
end

return M
