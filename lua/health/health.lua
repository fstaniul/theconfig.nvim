--[[
--
-- This file is not required for your own configuration,
-- but helps people determine if their system is setup correctly.
--
--]]

local check_version = function()
  local verstr = tostring(vim.version())
  if not vim.version.ge then
    vim.health.error(string.format("Neovim out of date: '%s'. Upgrade to latest stable or nightly", verstr))
    return
  end

  if vim.version.ge(vim.version(), '0.11') then
    vim.health.ok(string.format("Neovim version is: '%s'", verstr))
  else
    vim.health.error(string.format("Neovim out of date: '%s'. Upgrade to latest stable or nightly", verstr))
  end
end

local check_external_reqs = function()
  for _, exe in ipairs { 'git', 'make', 'unzip', 'rg', 'copilot', 'opencode' } do
    local is_executable = vim.fn.executable(exe) == 1
    if is_executable then
      vim.health.ok(string.format("Found executable: '%s'", exe))
    else
      vim.health.warn(string.format("Could not find executable: '%s'", exe))
    end
  end

  return true
end

local check_golangci_lint_version = function()
  if not vim.fn.executable 'golangci-lint' == 1 then
    vim.health.warn(string.format("Could not find executable: '%s'", exe))
    return
  end

  local version = vim.fn.system 'golangci-lint version --format short'
  if vim.version.lt(version, '2') then vim.health.warn(string.format('golangci-lint is outdated, update to version >=2: golangci-lint version %s', version)) end
end

return {
  check = function()
    vim.health.start 'theconfig.nvim'

    vim.health.info [[NOTE: Not every warning is a 'must-fix' in `:checkhealth`

    Fix only warnings for plugins and languages you intend to use.
    Mason will give warnings for languages that are not installed.
    You do not need to install, unless you want to use those languages!]]

    local uv = vim.uv or vim.loop
    vim.health.info('System Information: ' .. vim.inspect(uv.os_uname()))

    check_version()
    check_external_reqs()
    check_golangci_lint_version()
  end,
}
