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

local function add_phantom_lines(bufnr, start_line, count)
  if count <= 0 then
    return
  end
  local last_buffer_line_idx = vim.api.nvim_buf_line_count(bufnr) - 1 -- 0-indexed
  if last_buffer_line_idx < 0 then
    return
  end -- Buffer vazio
  local virt_lines_table = {}
  for _ = 1, count do
    -- Usar o grupo de highlight da configuração
    table.insert(virt_lines_table, { { '', config.options.phantom_highlight_group } })
  end
  vim.api.nvim_buf_set_extmark(bufnr, namespace, last_buffer_line_idx, 0, {
    virt_lines = virt_lines_table,
    virt_lines_above = false, -- Garante que apareçam após a linha marcada
    -- priority = N, -- Poderia definir uma prioridade se houver conflitos
  })
end

local function center_cursor()
  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)

  -- Verifica se o buffer é modificável e "normal"
  -- Isso ajuda a evitar terminais, quickfix, etc., além do filetype check.
  if vim.bo[bufnr].buftype ~= '' or not vim.bo[bufnr].modifiable then
    clear_phantom_lines(bufnr) -- Limpa se entrarmos num buffer não desejado
    last_state[winid] = nil -- Reseta estado cacheado para esta janela
    return
  end

  if is_disabled(bufnr) then
    clear_phantom_lines(bufnr) -- Limpa se o filetype for desabilitado
    last_state[winid] = nil
    return
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(winid) -- {row, col}, 1-indexed
  local win_height = vim.api.nvim_win_get_height(winid)
  local buf_line_count = vim.api.nvim_buf_line_count(bufnr)

  -- Verifica se o estado relevante mudou para evitar trabalho desnecessário
  local current_win_state = {
    cursor_line = cursor_pos[1],
    win_height = win_height,
    buf_line_count = buf_line_count,
  }

  if
    last_state[winid]
    and last_state[winid].cursor_line == current_win_state.cursor_line
    and last_state[winid].win_height == current_win_state.win_height
    and last_state[winid].buf_line_count == current_win_state.buf_line_count
  then
    -- Se o número de linhas fantasma não mudou, não faz nada.
    -- Isso acontece se o cursor se moveu, mas não o suficiente para mudar o cálculo.
    -- A lógica de "phantom_lines_needed" abaixo determinará se algo *realmente* precisa mudar.
    -- Por ora, um simple cache de entrada é suficiente. Veremos se o cache mais complexo é necessário.
  end

  -- Se o buffer está vazio ou a janela é muito pequena, não faz sentido centralizar
  if buf_line_count == 0 or win_height < 3 then -- Menos de 3 linhas não tem "meio"
    clear_phantom_lines(bufnr)
    last_state[winid] = nil
    return
  end

  -- O quanto `scrolloff` tentaria manter abaixo do cursor se fosse possível.
  -- Para centralização, é metade da altura da janela.
  local target_offset_from_bottom = math.floor(win_height / 2)

  -- Linhas reais abaixo da linha atual do cursor
  local actual_lines_below_cursor = buf_line_count - cursor_pos[1]

  -- Limpar sempre as linhas fantasma antes de recalcular é mais simples
  -- do que tentar modificar uma extmark existente com um novo número de virt_lines.
  clear_phantom_lines(bufnr)
  local num_phantoms_added = 0

  if actual_lines_below_cursor < target_offset_from_bottom then
    -- Precisamos adicionar linhas fantasma
    local phantom_lines_needed = target_offset_from_bottom - actual_lines_below_cursor
    if phantom_lines_needed > 0 then
      add_phantom_lines(bufnr, phantom_lines_needed)
      num_phantoms_added = phantom_lines_needed
    end

    -- Com as linhas fantasma adicionadas, agora precisamos ajustar a visão
    -- para que o cursor fique centralizado.
    -- `scrolloff` por si só não reage a `virt_lines` para cálculo de scroll.

    -- Salva o valor original de scrolloff da janela
    local original_scrolloff = vim.wo[winid].scrolloff
    -- Define scrolloff para 0 temporariamente para que nosso ajuste manual não seja combatido
    vim.wo[winid].scrolloff = 0

    -- Calcula a topline ideal para centralizar o cursor
    -- O cursor (cursor_pos[1]) deve estar na linha `target_offset_from_bottom` (ou `middle_line`) da janela.
    -- Portanto, a `topline` deve ser `cursor_pos[1] - target_offset_from_bottom + 1` (se 1-indexed middle)
    -- ou `cursor_pos[1] - math.floor(win_height / 2)` se queremos que o cursor fique *na* linha do meio ou logo abaixo.
    -- Se win_height = 20, middle = 10. Cursor na linha 10. topline = cursor_line - 10 + 1.
    local ideal_topline = math.max(1, cursor_pos[1] - math.floor(win_height / 2) + (win_height % 2 == 0 and 1 or 0))
    -- Ajuste para win_height par/ímpar pode ser necessário dependendo da preferência.
    -- Uma forma mais simples:
    ideal_topline = math.max(1, cursor_pos[1] - target_offset_from_bottom)
    -- No entanto, scrolloff geralmente calcula a partir do topo e da base.
    -- Se o cursor está na linha `L` e `scrolloff` é `S`, `topline` é `L-S`.
    -- Queremos que `L - topline + 1 = target_offset_from_bottom` (posição do cursor na tela)
    -- `topline = L - target_offset_from_bottom + 1`

    ideal_topline = math.max(1, cursor_pos[1] - target_offset_from_bottom + 1)

    local view = vim.fn.winsaveview()
    if view.topline ~= ideal_topline then
      view.topline = ideal_topline
      -- `winrestview` pode mover o cursor para a coluna 0 se a linha era mais curta.
      -- E também pode alterar `leftcol` se não estiver salvo/restaurado.
      -- Salvar e restaurar `virtcol` (ou apenas `col`) pode ser mais robusto.
      local original_cursor_col_for_view = cursor_pos[2] -- vim.api.nvim_win_get_cursor é 1-indexed

      vim.fn.winrestview(view)

      -- Restaurar a posição exata do cursor (especialmente coluna)
      vim.api.nvim_win_set_cursor(winid, { cursor_pos[1], original_cursor_col_for_view })
    end

    -- Restaura o scrolloff original
    vim.wo[winid].scrolloff = original_scrolloff
  else
    -- Não estamos perto o suficiente do final para precisar de linhas fantasma.
    -- `clear_phantom_lines` já foi chamado no início.
    -- O `scrolloff` natural do usuário (ex: 999) deve funcionar.
  end

  -- Atualiza o cache de estado
  last_state[winid] = {
    cursor_line = cursor_pos[1],
    win_height = win_height,
    buf_line_count = buf_line_count,
    num_phantoms = num_phantoms_added, -- Para depuração ou lógica de cache mais avançada
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
  -- Adicionar WinScrolled pode ser interessante se o usuário scrollar sem mover o cursor (mouse, C-e, C-y)
  -- No entanto, CursorMoved/I geralmente cobre isso bem.
  -- Adicionar BufLeave para limpar explicitamente pode ser uma opção,
  -- mas BufWinEnter no novo buffer/janela deve cuidar disso.
end

return M
