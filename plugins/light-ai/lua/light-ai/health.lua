local M = {}

local function check_writable_dir(dir)
  local stat = vim.uv.fs_stat(dir)
  if not stat then return ('temp_dir does not exist: %s'):format(dir) end
  if stat.type ~= 'directory' then return ('temp_dir is not a directory: %s'):format(dir) end

  local test_path = dir .. '/.light-ai-health-check'
  local fh = io.open(test_path, 'w')
  if fh then
    fh:close()
    os.remove(test_path)
    return nil
  else
    return ('temp_dir is not writable: %s'):format(dir)
  end
end

function M.check()
  vim.health.start 'light-ai'

  -- 1. opencode binary
  if vim.fn.executable 'opencode' == 1 then
    local version = vim.trim(vim.fn.system 'opencode --version 2>&1')
    vim.health.ok(('opencode found: %s'):format(version ~= '' and version or '(unknown version)'))
  else
    vim.health.error('opencode not found in PATH', { 'Install opencode and ensure it is on your PATH' })
  end

  -- 2. plugin config (setup() must have been called)
  local ok, ai = pcall(require, 'light-ai')
  if not ok then
    vim.health.error 'light-ai could not be loaded'
    return
  end

  local cfg = ai.get_config()

  if cfg.provider then
    vim.health.ok(('provider: %s'):format(cfg.provider:get_provider_name()))
  else
    vim.health.warn('no provider configured', { 'Call require("light-ai").setup() before using the plugin' })
  end

  if cfg.model and cfg.model ~= '' then
    vim.health.ok(('model: %s'):format(cfg.model))
  else
    vim.health.warn 'no model configured'
  end

  -- 3. temp_dir
  if not cfg.temp_dir or cfg.temp_dir == '' then
    vim.health.error('temp_dir not configured', { 'Pass opts.temp_dir to setup()' })
  else
    local err = check_writable_dir(cfg.temp_dir)
    if err then
      vim.health.error(err, { 'Ensure the directory exists and is writable' })
    else
      vim.health.ok(('temp_dir writable: %s'):format(cfg.temp_dir))
    end
  end

  -- 4. optional telescope (for M.preview_agents / M.pick_logs)
  if pcall(require, 'telescope') then
    vim.health.ok 'telescope.nvim found (preview_agents / pick_logs available)'
  else
    vim.health.warn('telescope.nvim not found', { 'Install telescope.nvim to use preview_agents and pick_logs' })
  end
end

return M
