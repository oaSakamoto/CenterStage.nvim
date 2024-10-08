local config = require('CenterStage.config')
local utils = require('CenterStage.utils')

local M = {}

function M.setup(opts)
    config.setup(opts)
    utils.create_autocmd()
end

return M
