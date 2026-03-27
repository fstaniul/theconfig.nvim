local AgentProvider = require('light-ai.agent').AgentProvider

---@class OpenCodeProvider : AgentProvider
local OpenCodeProvider = AgentProvider:extend()

---@return string
function OpenCodeProvider:get_provider_name() return 'opencode' end

---@return string
function OpenCodeProvider:get_default_model() return 'github-copilot/claude-sonnet-4.6' end

---Returns all models available to opencode by shelling out to `opencode models`.
---Results are cached after the first call.
---@return string[]
function OpenCodeProvider:get_available_models()
  if self._models_cache then return self._models_cache end

  local raw = vim.fn.system 'opencode models'
  local models = {}
  for line in raw:gmatch '[^\n]+' do
    local trimmed = vim.trim(line)
    if trimmed ~= '' then table.insert(models, trimmed) end
  end

  self._models_cache = models
  return models
end

---Builds the command list to invoke opencode non-interactively.
---@param prompt string
---@param context AgentContext
---@return string[]
function OpenCodeProvider:prepare_command(prompt, context)
  return {
    'opencode',
    'run',
    '--model',
    context.model,
    prompt,
  }
end

return OpenCodeProvider
