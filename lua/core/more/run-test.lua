-- Run the test(s) associated with the current file and load results into
-- the quickfix list. No-op if the current file doesn't match any runner.
--
-- Extend M.runners to support more languages/file types.

local M = {}

-- Parse `go test -v` output lines into quickfix entries, resolving bare
-- filenames (e.g. "foo_test.go:15: message") against the package dir.
local function parse_go_test_output(lines, dir)
  local qf = {}
  for _, line in ipairs(lines) do
    if line ~= '' then
      local file, lnum, rest = line:match '^%s*([%w%._/-]+%.go):(%d+):%s*(.*)$'
      if file then
        qf[#qf + 1] = { filename = dir .. '/' .. file, lnum = tonumber(lnum), text = rest }
      else
        qf[#qf + 1] = { text = line }
      end
    end
  end
  return qf
end

local function run_go_test()
  local dir = vim.fn.expand '%:p:h'

  vim.system({ 'go', 'test', dir }, { text = true }, function(result)
    vim.schedule(function()
      local output = (result.stdout or '') .. (result.stderr or '')
      local qf = parse_go_test_output(vim.split(output, '\n'), dir)
      if result.code == 0 then
        vim.notify('go test passed: ' .. dir, vim.log.levels.INFO)
      else
        vim.fn.setqflist(qf, 'r')
        vim.cmd 'copen'
        vim.notify('go test failed: ' .. dir, vim.log.levels.WARN)
      end
    end)
  end)
end

M.runners = {
  { pattern = '_test%.go$', run = run_go_test },
}

-- Run the test for the current file. No-op if no runner matches.
function M.run()
  local path = vim.fn.expand '%:p'
  for _, runner in ipairs(M.runners) do
    if path:match(runner.pattern) then
      runner.run()
      return
    end
  end
end

return M
