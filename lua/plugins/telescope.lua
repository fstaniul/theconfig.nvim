return { -- Fuzzy Finder (files, lsp, etc)
  'nvim-telescope/telescope.nvim',
  -- By default, Telescope is included and acts as your picker for everything.

  -- If you would like to switch to a different picker (like snacks, or fzf-lua)
  -- you can disable the Telescope plugin by setting enabled to false and enable
  -- your replacement picker by requiring it explicitly (e.g. 'custom.plugins.snacks')

  -- Note: If you customize your config for yourself,
  -- it’s best to remove the Telescope plugin config entirely
  -- instead of just disabling it here, to keep your config clean.
  enabled = true,
  event = 'VimEnter',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { -- If encountering errors, see telescope-fzf-native README for installation instructions
      'nvim-telescope/telescope-fzf-native.nvim',

      -- `build` is used to run some command when the plugin is installed/updated.
      -- This is only run then, not every time Neovim starts up.
      build = 'make',

      -- `cond` is a condition used to determine whether this plugin should be
      -- installed and loaded.
      cond = function() return vim.fn.executable 'make' == 1 end,
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },

    -- Useful for getting pretty icons, but requires a Nerd Font.
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    'folke/trouble.nvim',
  },
  config = function()
    -- Telescope is a fuzzy finder that comes with a lot of different things that
    -- it can fuzzy find! It's more than just a "file finder", it can search
    -- many different aspects of Neovim, your workspace, LSP, and more!
    --
    -- The easiest way to use Telescope, is to start by doing something like:
    --  :Telescope help_tags
    --
    -- After running this command, a window will open up and you're able to
    -- type in the prompt window. You'll see a list of `help_tags` options and
    -- a corresponding preview of the help.
    --
    -- Two important keymaps to use while in Telescope are:
    --  - Insert mode: <c-/>
    --  - Normal mode: ?
    --
    -- This opens a window that shows you all of the keymaps for the current
    -- Telescope picker. This is really useful to discover what Telescope can
    -- do as well as how to actually do it!

    -- [[ Configure Telescope ]]
    -- See `:help telescope` and `:help telescope.setup()`
    local open_with_trouble = require('trouble.sources.telescope').open

    -- Use this to add more results without clearing the trouble list
    local add_to_trouble = require('trouble.sources.telescope').add

    require('telescope').setup {
      defaults = {
        mappings = {
          i = {
            ['<c-t>'] = open_with_trouble,
            ['<c-s-t>'] = add_to_trouble,
          },
          n = {
            ['<c-t>'] = open_with_trouble,
            ['<c-s-t>'] = add_to_trouble,
          },
        },
      },
      extensions = {
        ['ui-select'] = { require('telescope.themes').get_dropdown() },
      },
    }

    -- Enable Telescope extensions if they are installed
    pcall(require('telescope').load_extension, 'fzf')
    pcall(require('telescope').load_extension, 'ui-select')

    -- When opening Telescope from the dashboard, close the dashboard and open
    -- a scratch buffer first. This ensures Trouble (and other tools) have a
    -- real editing window to open files into, instead of hijacking the picker.
    vim.api.nvim_create_autocmd('User', {
      pattern = 'TelescopeFindPre',
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        local ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
        if ft == 'snacks_dashboard' then
          -- Replace the dashboard window with an empty scratch buffer
          vim.cmd 'enew'
          local new_buf = vim.api.nvim_get_current_buf()
          vim.api.nvim_set_option_value('buftype', 'nofile', { buf = new_buf })
          vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = new_buf })
          vim.api.nvim_set_option_value('buflisted', false, { buf = new_buf })
        end
      end,
    })

    -- See `:help telescope.builtin`
    local builtin = require 'telescope.builtin'

    local function get_git_root()
      local dot_git_path = vim.fn.finddir('.git', '.;')
      return vim.fn.fnamemodify(dot_git_path, ':h')
    end

    ---@type table<string, boolean>
    local is_inside_work_tree = {}
    local function is_git_repo()
      local cwd = vim.uv.cwd() or vim.fn.getcwd()
      if is_inside_work_tree[cwd] == nil then
        vim.fn.system 'git rev-parse --is-inside-work-tree'
        is_inside_work_tree[cwd] = vim.v.shell_error == 0
      end
      return is_inside_work_tree[cwd]
    end

    local function find_files_from_project_git_root()
      local opts = {}
      if is_git_repo() then opts = {
        cwd = get_git_root(),
      } end
      builtin.find_files(opts)
    end

    local function git_files_with_fallback()
      local opts = {
        cwd = vim.uv.cwd() or vim.fm.getcwd(),
      }

      if is_git_repo() then
        builtin.git_files(opts)
      else
        builtin.find_files(opts)
      end
    end

    local function search_multigrep(opts)
      local opts = opts or {}
      opts.cwd = opts.cwd or vim.uv.cwd()
      local pickers = require 'telescope.pickers'
      local finders = require 'telescope.finders'
      local sorters = require 'telescope.sorters'
      local conf = require('telescope.config').values
      local make_entry = require 'telescope.make_entry'

      local finder = finders.new_async_job {
        command_generator = function(prompt)
          if not prompt or prompt == '' then return nil end

          local pattern, glob = prompt:match '^(.*)  (.-)$'

          local args = {
            'rg',
            '--vimgrep',
            '--smart-case',
            '--hidden',
          }

          if pattern and glob then
            table.insert(args, '-e')
            table.insert(args, pattern)
            table.insert(args, '-g')
            table.insert(args, glob)
          else
            table.insert(args, '-e')
            table.insert(args, prompt)
          end

          return args
        end,
        entry_maker = make_entry.gen_from_vimgrep(opts),
        cwd = opts.cwd,
      }

      pickers
        .new(opts, {
          prompt_title = 'Multi Grep (rg with glob)',
          finder = finder,
          sorter = sorters.empty(),
          previewer = conf.grep_previewer(opts),
        })
        :find()
    end

    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    vim.keymap.set('n', '<leader>sf', find_files_from_project_git_root, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>st', builtin.treesitter, { desc = '[S]earch [T]reesitter symbols' })
    vim.keymap.set('n', '<C-P>', git_files_with_fallback, { desc = 'Search git files' })
    vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
    vim.keymap.set('n', '<leader>sb', builtin.buffers, { desc = '[S]earch [B]uffers' })
    vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
    vim.keymap.set('n', '<leader>sm', search_multigrep, { desc = '[S]earch [M]ultigrep' })
    vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
    vim.keymap.set('n', '<leader>so', builtin.oldfiles, { desc = '[S]earch Recent [O]ld Files' })
    vim.keymap.set(
      'n',
      '<leader>sa',
      function()
        builtin.find_files {
          cwd = get_git_root(),
          no_ignore = true,
          no_ignore_parent = true,
          hidden = { '.git' },
        }
      end,
      { desc = '[S]earch Recent [O]ld Files' }
    )
    vim.keymap.set('n', '<leader>s.', function() builtin.find_files { cwd = vim.fn.expand '%:p:h' } end, { desc = '[S]earch In Current Directory' })
    vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })

    -- This runs on LSP attach per buffer (see main LSP attach function in 'neovim/nvim-lspconfig' config for more info,
    -- it is better explained there). This allows easily switching between pickers if you prefer using something else!
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
      callback = function(event)
        local buf = event.buf

        -- Find references for the word under your cursor.
        vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })

        -- Jump to the implementation of the word under your cursor.
        -- Useful when your language has ways of declaring types without an actual implementation.
        vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })

        -- Jump to the definition of the word under your cursor.
        -- This is where a variable was first declared, or where a function is defined, etc.
        -- To jump back, press <C-t>.
        vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })

        -- Fuzzy find all the symbols in your current document.
        -- Symbols are things like variables, functions, types, etc.
        vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })

        -- Fuzzy find all the symbols in your current workspace.
        -- Similar to document symbols, except searches over your entire project.
        vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })

        -- Jump to the type of the word under your cursor.
        -- Useful when you're not sure what type a variable is and you want to see
        -- the definition of its *type*, not where it was *defined*.
        vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
      end,
    })

    -- Override default behavior and theme when searching
    vim.keymap.set('n', '<leader>/', function()
      -- You can pass additional configuration to Telescope to change the theme, layout, etc.
      builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
        winblend = 10,
        previewer = false,
      })
    end, { desc = '[/] Fuzzily search in current buffer' })

    -- It's also possible to pass additional configuration options.
    --  See `:help telescope.builtin.live_grep()` for information about particular keys
    vim.keymap.set(
      'n',
      '<leader>s/',
      function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end,
      { desc = '[S]earch [/] in Open Files' }
    )

    -- Shortcut for searching your Neovim configuration files
    vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
  end,
}
