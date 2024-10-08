local config = require('CenterStage.config')

local M = {}

local function is_disable(bufnr)
    local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
    for _ , disable in ipairs(config.options.disble_for_ft) do
        if filetype == disable then
            return true
        end
    end
    return false
end

local function center_cursor()
    local bufnr = vim.api.nvim_get_current_buf()

    if is_disable(bufnr) then
        return
    end

    local window = vim.api.nvim_get_current_win()
    local cursor = vim.api.nvim_win_get_cursor(window)
    local cursor_line, cursor_col = cursor[1], cursor[2]
    local window_height = vim.api.nvim_win_get_height(window)
    local top_line = vim.fn.line('w0')
    local bottom_line = vim.fn.line('w$')

    if cursor_line <= top_line + window_height * 0.25 or cursor_line >= bottom_line - window_height * 0.25 then
        local view = vim.fn.winsaveview()
        view.topline = math.max(1, cursor_line - math.floor(window_height / 2))
        vim.fn.winrestview(view)

        vim.api.nvim_win_set_cursor(window, {cursor_line, cursor_col})
    end
end

function M.create_autocmd()
    vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
        group = vim.api.nvim_create_augroup("CenterCursor", { clear = true }),
        callback = center_cursor
    })
end

return M
