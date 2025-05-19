local M = {}

M.defaults = {
  disable_for_ft = { 'netrw', 'TelescopePrompt', 'NvimTree', 'lazy', 'mason' },
  phantom_highlight_group = 'NonText',
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_extend('force', {}, M.defaults, opts or {})
end

M.setup({})

return M
