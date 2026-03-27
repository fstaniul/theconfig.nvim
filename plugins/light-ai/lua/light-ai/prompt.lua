---Replaces {{ key }} placeholders in a template string with values from vars.
---Tags with no matching key are left untouched.
---@param template string
---@param vars table<string, string>
---@return string
local function render_prompt(template, vars)
  return (template:gsub('{{%s*(.-)%s*}}', function(key) return vars[key] or ('{{' .. key .. '}}') end))
end

---@class PromptProvider
---@field template string  Prompt template containing {{ prompt }} and any other {{ placeholders }}.
local PromptProvider = {}
PromptProvider.__index = PromptProvider

---Creates a new PromptProvider with the given template.
---The template must contain at least a {{ prompt }} placeholder where the
---user's input will be inserted. Any other {{ placeholders }} will be
---substituted from the vars table passed to render().
---
---Example template:
---  You are a Lua expert.\n\nTask: {{ prompt }}\n\nFile: {{ filename }}
---
---@param template string
---@return PromptProvider
function PromptProvider.new(template)
  assert(type(template) == 'string' and template ~= '', 'template must be a non-empty string')
  return setmetatable({ template = template }, PromptProvider)
end

---Renders the template by substituting {{ prompt }} with the user's prompt
---and any additional {{ placeholders }} with values from vars.
---@param prompt string           The user's raw prompt text.
---@param vars? table<string, string>  Extra variables to substitute.
---@return string
function PromptProvider:render(prompt, vars)
  local all_vars = vim.tbl_extend('force', vars or {}, { prompt = prompt })
  return render_prompt(self.template, all_vars)
end

return PromptProvider
