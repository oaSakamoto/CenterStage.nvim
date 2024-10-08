local M = {}

M.defaults = {
    disable_for_ft = { 'netrw', 'TelescopePrompt'}
}

M.options = {}

function M.setup(opts)
   M.options = vim.tbl_extend('force', {},  M.defaults, opts or {})
end

return M
