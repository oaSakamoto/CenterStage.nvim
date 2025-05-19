local config = require('CenterStage.config')

local M = {}

local namespace = vim.api.nvim_create_namespace('center_stage_phantom')
local center_stage_augroup = nil

local last_state = {} -- key: winid, value: { cursor_line, win_height, buf_line_count, num_phantoms }

local function is_disabled(bufnr)
  local filetype = vim.bo[bufnr].filetype
  return vim.tbl_contains(config.options.disable_for_ft, filetype)
end

local function clear_phantom_lines(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
end

function M.clear_all_phantom_lines()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      clear_phantom_lines(bufnr)
    end
  end
end

local function add_phantom_lines(bufnr, count)
  if count <= 0 then
    return
  end
  local last_buffer_line_idx = vim.api.nvim_buf_line_count(bufnr) - 1 -- 0-indexed
  if last_buffer_line_idx < 0 then
    return
  end -- Buffer vazio
  local virt_lines_table = {}
  for _ = 1, count do
    table.insert(virt_lines_table, { { '', config.options.phantom_highlight_group } })
  end
  vim.api.nvim_buf_set_extmark(bufnr, namespace, last_buffer_line_idx, 0, {
    virt_lines = virt_lines_table,
    virt_lines_above = false,
  })
end

local function is_completion_popup_visible()
  if vim.fn.pumvisible() == 1 then
    return true
  end
  return false
end

local function center_cursor()
  if is_completion_popup_visible() then
    return
  end
  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)

  if vim.bo[bufnr].buftype ~= '' or not vim.bo[bufnr].modifiable then
    clear_phantom_lines(bufnr)
    last_state[winid] = nil
    return
  end

  if is_disabled(bufnr) then
    clear_phantom_lines(bufnr)
    last_state[winid] = nil
    return
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(winid)
  local win_height = vim.api.nvim_win_get_height(winid)
  local buf_line_count = vim.api.nvim_buf_line_count(bufnr)

  local current_win_state = {
    cursor_line = cursor_pos[1],
    win_height = win_height,
    buf_line_count = buf_line_count,
  }

  if buf_line_count == 0 or win_height < 3 then -- Menos de 3 linhas não tem "meio"
    clear_phantom_lines(bufnr)
    last_state[winid] = nil
    return
  end

  local target_offset_from_bottom = math.floor(win_height / 2)

  local actual_lines_below_cursor = buf_line_count - cursor_pos[1]

  clear_phantom_lines(bufnr)
  local num_phantoms_added = 0

  if actual_lines_below_cursor < target_offset_from_bottom then
    local phantom_lines_needed = target_offset_from_bottom - actual_lines_below_cursor
    if phantom_lines_needed > 0 then
      add_phantom_lines(bufnr, phantom_lines_needed)
      num_phantoms_added = phantom_lines_needed
    end

    local original_scrolloff = vim.wo[winid].scrolloff
    vim.wo[winid].scrolloff = 0

    local ideal_topline = math.max(1, cursor_pos[1] - math.floor(win_height / 2) + (win_height % 2 == 0 and 1 or 0))
    ideal_topline = math.max(1, cursor_pos[1] - target_offset_from_bottom)

    ideal_topline = math.max(1, cursor_pos[1] - target_offset_from_bottom + 1)

    local view = vim.fn.winsaveview()
    if view.topline ~= ideal_topline then
      view.topline = ideal_topline
      local original_cursor_col_for_view = cursor_pos[2] -- vim.api.nvim_win_get_cursor é 1-indexed

      vim.fn.winrestview(view)

      vim.api.nvim_win_set_cursor(winid, { cursor_pos[1], original_cursor_col_for_view })
    end

    vim.wo[winid].scrolloff = original_scrolloff
  end

  last_state[winid] = {
    cursor_line = cursor_pos[1],
    win_height = win_height,
    buf_line_count = buf_line_count,
    num_phantoms = num_phantoms_added,
  }
end

function M.create_autocmd(augroup_name_param)
  if center_stage_augroup then
    vim.api.nvim_del_augroup_by_id(center_stage_augroup)
  end
  center_stage_augroup = vim.api.nvim_create_augroup(augroup_name_param, { clear = true })

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'BufWinEnter', 'WinResized' }, {
    group = center_stage_augroup,
    pattern = '*', -- Filtros são feitos dentro da callback
    callback = center_cursor,
    desc = 'CenterStage: Keep cursor centered with phantom lines at EOF',
  })
end

return M
