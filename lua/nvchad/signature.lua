local config = require("core.utils").load_config().ui.lsp.signature 

-- thx to https://gitlab.com/ranjithshegde/dotbare/-/blob/master/.config/nvim/lua/lsp/init.lua
local M = {}


M.signature_window = function(_, result, ctx, config)
  local bufnr, winner = vim.lsp.handlers.signature_help(_, result, ctx, config)
  if winner then
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local current_cursor_line, _ = cursor_pos[1], cursor_pos[2]
    local main_buf_height = vim.api.nvim_win_get_height(0)
    --local main_buf_width = vim.api.nvim_win_get_width(0)

    -- Calculate the height and width based on content
    local max_height = config.max_height or 10
    local max_width = config.max_width or 80
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local sig_win_height = math.min(line_count, max_height)
    local sig_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local sig_win_width = 0
    for _, line in ipairs(sig_lines) do
      sig_win_width = math.min(math.max(sig_win_width, #line), max_width)
    end

    -- Calculate available space above and below cursor
    local lines_above = current_cursor_line - 1
    local lines_below = main_buf_height - current_cursor_line

    -- Determine optimal placement and height for the floating window
    -- Determine optimal placement and height for the floating window
    local anchor
    local row
    if lines_below >= sig_win_height then
      -- Place below cursor if enough space
      anchor = "NW"
      row = 1
    elseif lines_above >= sig_win_height then
      -- Place above cursor if enough space
      anchor = "SW"
      row = 0
    elseif lines_below > lines_above then
      -- Reduce sig_win_height to fit available space below cursor
      anchor = "NW"
      row = 1
      sig_win_height = lines_below
    else
      -- Reduce sig_win_height to fit available space above cursor
      anchor = "SW"
      row = 1
      sig_win_height = lines_above
    end

    vim.api.nvim_win_set_config(winner, {
      anchor = anchor,
      relative = "cursor",
      row = row,
      col = 0,
      width = sig_win_width,
      height = sig_win_height,
    })
  end

  if bufnr and winner then
    return bufnr, winner
  end
end


-- thx to https://github.com/seblj/dotfiles/blob/0542cae6cd9a2a8cbddbb733f4f65155e6d20edf/nvim/lua/config/lspconfig/init.lua
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local util = require "vim.lsp.util"
local clients = {}

local check_trigger_char = function(line_to_cursor, triggers)
  if not triggers then
    return false
  end

  for _, trigger_char in ipairs(triggers) do
    local current_char = line_to_cursor:sub(#line_to_cursor, #line_to_cursor)
    local prev_char = line_to_cursor:sub(#line_to_cursor - 1, #line_to_cursor - 1)
    if current_char == trigger_char then
      return true
    end
    if current_char == " " and prev_char == trigger_char then
      return true
    end
  end
  return false
end

local open_signature = function()
  local triggered = false

  for _, client in pairs(clients) do
    local triggers = client.server_capabilities.signatureHelpProvider.triggerCharacters

    -- csharp has wrong trigger chars for some odd reason
    if client.name == "csharp" then
      triggers = { "(", "," }
    end

    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    local line_to_cursor = line:sub(1, pos[2])

    if not triggered then
      triggered = check_trigger_char(line_to_cursor, triggers)
    end
  end

  if triggered then
    local params = util.make_position_params()
    vim.lsp.buf_request(
      0,
      "textDocument/signatureHelp",
      params,
      vim.lsp.with(M.signature_window, {
        border = "single",
        focusable = false,
        silent = config.silent,
      })
    )
  end
end

M.setup = function(client)
  if config.disabled then
    return
  end
  table.insert(clients, client)
  local group = augroup("LspSignature", { clear = false })
  vim.api.nvim_clear_autocmds { group = group, pattern = "<buffer>" }

  autocmd("TextChangedI", {
    group = group,
    pattern = "<buffer>",
    callback = function()
      -- Guard against spamming of method not supported after
      -- stopping a language serer with LspStop
      local active_clients = vim.lsp.get_active_clients()
      if #active_clients < 1 then
        return
      end
      open_signature()
    end,
  })
end

return M
