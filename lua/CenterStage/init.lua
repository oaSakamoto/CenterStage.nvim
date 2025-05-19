local config = require('CenterStage.config')
local utils = require('CenterStage.utils')

local M = {}

local augroup_name = 'CenterStageCursor'

function M.setup(opts)
  config.setup(opts)
  utils.create_autocmd(augroup_name)
end

function M.disable()
  utils.clear_all_phantom_lines()
  vim.api.nvim_del_augroup_by_name(augroup_name)
  vim.notify('CenterStage disabled', vim.log.levels.INFO)
end

function M.enable()
  utils.create_autocmd(augroup_name)
  vim.notify('CenterStage enabled', vim.log.levels.INFO)
end

return M
