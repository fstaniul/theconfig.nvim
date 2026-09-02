-- local one file plugin for switching between file and it's test
-- mapped to gj and gJ

local M = {}

M.rules = {
  -- Go: foo.go <-> foo_test.go
  { pattern = '_test%.go$', alt = function(p) return p:gsub('_test%.go$', '.go') end },
  { pattern = '%.go$', alt = function(p) return p:gsub('%.go$', '_test.go') end },

  -- TSX: foo.tsx <-> foo.test.tsx
  { pattern = '%.test%.tsx$', alt = function(p) return p:gsub('%.test%.tsx$', '.tsx') end },
  { pattern = '%.tsx$', alt = function(p) return p:gsub('%.tsx$', '.test.tsx') end },
}

-- Given the current path, find the first matching rule's alt path.
-- Returns nil if no rule matches (i.e. current file isn't go/tsx).
local function find_alt(path)
  for _, rule in ipairs(M.rules) do
    if path:match(rule.pattern) then
      local alt = rule.alt(path)
      if alt and alt ~= path then return alt end
    end
  end
  return nil
end

-- only switch if the alt file already exists.
function M.toggle()
  local path = vim.fn.expand '%'
  local alt = find_alt(path)

  if alt and vim.fn.filereadable(alt) == 1 then
    vim.cmd('edit ' .. alt)
  else
    vim.notify('No matching test/source file found for: ' .. path, vim.log.levels.WARN)
  end
end

-- switch regardless, creating the file (and any missing dirs) if needed.
function M.toggle_force()
  local path = vim.fn.expand '%'
  local alt = find_alt(path)

  if not alt then
    vim.notify('No test/source convention matched for: ' .. path, vim.log.levels.WARN)
    return
  end

  if vim.fn.filereadable(alt) ~= 1 then vim.fn.mkdir(vim.fn.fnamemodify(alt, ':h'), 'p') end

  vim.cmd('edit ' .. alt)
end

return M
