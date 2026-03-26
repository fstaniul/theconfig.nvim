---@class CopilotProvider : _99.Providers.BaseProvider
local CopilotProvider = {}

--- @param query string
--- @param context _99.Prompt
--- @return string[]
function CopilotProvider._build_command(self, query, context)
  local tmp_dir = vim.fs.dirname(context.tmp_file)

  return {
    'copilot',
    '--allow-tool',
    'write,shell(cat:*)',
    '--add-dir',
    tmp_dir,
    '--model',
    context.model,
    '-p',
    query,
  }
end

--- @return string
function CopilotProvider._get_provider_name() return 'CopilotProvider' end

-- we're retuning the free model here, so we're not using tokens
--- @return string
function CopilotProvider._get_default_model() return 'claude-sonnet-4.6' end

function CopilotProvider.fetch_models(callback)
  -- hardocded list
  callback {
    'claude-sonnet-4.6',
    'claude-sonnet-4.5',
    'claude-haiku-4.5',
    'claude-opus-4.6',
    'claude-opus-4.6-fast',
    'claude-opus-4.5',
    'claude-sonnet-4',
    'gemini-3-pro-preview',
    'gpt-5.4',
    'gpt-5.3-codex',
    'gpt-5.2-codex',
    'gpt-5.2',
    'gpt-5.1-codex-max',
    'gpt-5.1-codex',
    'gpt-5.1',
    'gpt-5.1-codex-mini',
    'gpt-5-mini',
    'gpt-4.1',
  }
end

---@module 'lazy'
---@type LazyConfig
return {
  'ThePrimeagen/99',
  enabled = vim.g.enable_99,
  dependencies = {
    -- we use completion from blink
    'saghen/blink.cmp',
    'folke/snacks.nvim',
  },
  config = function()
    --- @type _99
    local _99 = require '99'

    setmetatable(CopilotProvider, { __index = _99.Providers.BaseProvider })

    -- For logging that is to a file if you wish to trace through requests
    -- for reporting bugs, i would not rely on this, but instead the provided
    -- logging mechanisms within 99. This is for more debugging purposes.
    local cwd = vim.uv.cwd()
    local basename = vim.fs.basename(cwd)

    local git_root = Snacks.git.get_root(cwd)
    print(vim.inspect(git_root))
    local tmp_dir
    if git_root ~= nil and git_root ~= '' then
      tmp_dir = git_root .. '/.tmp'
    else
      tmp_dir = './.tmp'
    end

    _99.setup {
      provider = CopilotProvider,
      logger = {
        level = _99.DEBUG,
        path = '/tmp/' .. basename .. '.99.debug',
        print_on_error = true,
      },
      -- When setting this to something that is not inside the CWD tools
      -- such as claude code or opencode will have permission issues
      -- and generation will fail refer to tool documentation to resolve
      -- https://opencode.ai/docs/permissions/#external-directories
      -- https://code.claude.com/docs/en/permissions#read-and-edit
      tmp_dir = tmp_dir,

      model = 'claude-sonnet-4.6',

      --- Completions: #rules and @files in the prompt buffer
      completion = {
        -- I am going to disable these until i understand the
        -- problem better.  Inside of cursor rules there is also
        -- application rules, which means i need to apply these
        -- differently
        -- cursor_rules = "<custom path to cursor rules>"

        --- A list of folders where you have your own SKILL.md
        --- Expected format:
        --- /path/to/dir/<skill_name>/SKILL.md
        ---
        --- Example:
        --- Input Path:
        --- "scratch/custom_rules/"
        ---
        --- Output Rules:
        --- {path = "scratch/custom_rules/vim/SKILL.md", name = "vim"},
        --- ... the other rules in that dir ...
        ---
        custom_rules = {
          -- 'scratch/custom_rules/',
        },

        --- Configure @file completion (all fields optional, sensible defaults)
        files = {
          enabled = true,
          max_file_size = 102400, -- bytes, skip files larger than this
          max_files = 5000, -- cap on total discovered files
          exclude = { '.env', '.env.*', 'node_modules', '.git' },
        },
        --- File Discovery:
        --- - In git repos: Uses `git ls-files` which automatically respects .gitignore
        --- - Non-git repos: Falls back to filesystem scanning with manual excludes
        --- - Both methods apply the configured `exclude` list on top of gitignore

        --- What autocomplete engine to use. Defaults to native (built-in) if not specified.
        source = 'blink', -- "native" (default), "cmp", or "blink"
      },

      --- WARNING: if you change cwd then this is likely broken
      --- ill likely fix this in a later change
      ---
      --- md_files is a list of files to look for and auto add based on the location
      --- of the originating request.  That means if you are at /foo/bar/baz.lua
      --- the system will automagically look for:
      --- /foo/bar/AGENT.md
      --- /foo/AGENT.md
      --- assuming that /foo is project root (based on cwd)
      md_files = {
        'AGENT.md',
      },
    }

    -- take extra note that i have visual selection only in v mode
    -- technically whatever your last visual selection is, will be used
    -- so i have this set to visual mode so i dont screw up and use an
    -- old visual selection
    --
    -- likely ill add a mode check and assert on required visual mode
    -- so just prepare for it now
    vim.keymap.set('v', '<leader>9v', function() _99.visual() end, { desc = '99 [V]isual Replace' })

    --- if you have a request you dont want to make any changes, just cancel it
    vim.keymap.set('n', '<leader>9x', function() _99.stop_all_requests() end, { desc = '99 Stop All Requests' })

    vim.keymap.set('n', '<leader>9s', function() _99.search() end, { desc = '99 [S]earch' })

    vim.keymap.set('n', '<leader>9l', function() _99.view_logs() end, { desc = '99 View [L]ogs' })

    vim.keymap.set('n', '<leader>9c', function() _99.vibe() end, { desc = '99 Vibe [C]ode' })

    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    local function select_model(callback)
      _99.get_provider().fetch_models(function(models, err)
        pickers
          .new({}, {
            prompt_title = 'Select model',
            finder = finders.new_table {
              results = models,
            },
            sorter = conf.generic_sorter {},
            attach_mappings = function(prompt_bufnr, map)
              actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()

                _99.set_model(selection[1])
                print('Selected model: ' .. selection[1])
              end)

              return true
            end,
          })
          :find()
      end)
    end

    vim.keymap.set('n', '<leader>9m', select_model, { desc = '99 Select [M]odel' })

    vim.api.nvim_create_user_command('UseOpenCode', function(opts)
      _99.set_provider(_99.Providers.OpenCodeProvider)
      _99.set_model 'github-copilot/claude-sonnet-4.6'
    end, {
      nargs = 0, -- 0 or more args ('0', '1', '?', '+', '*')
      desc = 'Use OpenCodeProvider for 99',
    })

    vim.api.nvim_create_user_command('UseCopilot', function(opts) _99.set_provider(CopilotProvider) end, {
      nargs = 0, -- 0 or more args ('0', '1', '?', '+', '*')
      desc = 'Use CopilotProvider for 99',
    })
  end,
}
