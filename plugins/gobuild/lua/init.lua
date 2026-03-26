---@module 'gobuild'
---@class GoBuildModule
---@field errors string[]
local M = {}

function M:new()
  local obj = setmetatable({
    errors = {},
  }, { __index = self })
  return obj
end

---@return string|false
function M:get_go_lsp_root()
  local clients = vim.lsp.get_clients { bufnr = 0 }
  for _, client in ipairs(clients) do
    if client.name == 'gopls' then return client.config.root_dir end
  end

  return false
end

function M:go_build()
  local root = self:get_go_lsp_root()
  if root == false then
    Snacks.notifier.notify('No gopls lsp root found', 'error', { title = 'Go build' })
    return
  end

  local title = 'go build ./...'
  local progress = Snacks.notifier.notify('running...', 'info', { timeout = 0, title = title })

  vim.system { 'mkdir', '-p', '/tmp/nvimgobuild' }
  vim.system({ 'go', 'build', '-o', '/tmp/nvimgobuild/', './...' }, { cwd = root, text = true }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        self.errors = {}
        vim.system({ 'rm', '-f', '/tmp/nvimgobuild/*' }, { text = true }, function() end)
        Snacks.notifier.notify('success', 'info', { id = progress, timeout = 3000, title = title })
      else
        self.errors = self:rebase_errors(vim.split(obj.stderr, '\n', { trimempty = true }), root)
        Snacks.notifier.notify('failed', 'error', { id = progress, timeout = 3000, title = title })
      end

      self:fill_qlist(obj.code ~= 0)
    end)
  end)
end

---@param open? boolean
function M:fill_qlist(open)
  vim.fn.setqflist({}, ' ', { title = 'Go Build', lines = self.errors, efm = '%f:%l:%c: %m' })
  if open == true then
    vim.cmd 'Trouble quickfix open'
  else
    vim.cmd 'Trouble quickfix close'
  end
end

---Rebase error paths to be relative to the cwd instead of the gopls root. This is necessary because the quickfix list will open in the cwd, not the gopls root.
---@param errors string[]
---@param root string
---@return string[]
function M:rebase_errors(errors, root)
  local cwd = vim.fn.getcwd()
  local rel_root = vim.fs.relpath(cwd, root)
  local target = {}

  -- loop through errors and replace the prefix path with one that's relative to the cwd
  for i, err in ipairs(errors) do
    local path, rest = M.split_error(err)
    if rest == '' then
      target[i] = path
    else
      path = vim.fs.joinpath(rel_root, path)
      target[i] = path .. rest
    end
  end

  return target
end

function M.split_error(input)
  local i = input:find ':'
  if not i then
    return input, '' -- Or handle error: no colon found
  end

  local before = input:sub(1, i - 1)
  local after = input:sub(i)

  return before, after
end

function M.setup()
  local gobuild = M:new()

  vim.api.nvim_create_user_command('GoBuild', function(opts)
    if opts.fargs[1] == 'quickfix' then
      gobuild:fill_qlist(true)
    else
      gobuild:go_build()
    end
  end, {
    nargs = '?',
    desc = 'Build Go project using gopls root',
  })
end

return M
-- vim: ts=2 sts=2 sw=2 et
