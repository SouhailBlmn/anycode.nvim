local M = {}

-- Configuration
local config = {
	size = 100,
	direction = "vertical",
	close_on_exit = false,
	start_in_insert = true,
	auto_scroll = true,
	autochdir = false,
	cmd = "claude",
	dir = "git_dir",
}

-- Terminal instances storage
local claude_terminals = {}
local next_instance_id = 1
local last_toggled_id = 1

-- Setup function
function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})

	-- Ensure toggleterm is available
	local ok, toggleterm = pcall(require, "toggleterm")
	if not ok then
		vim.notify("toggleterm.nvim is required for claude-code-terminal", vim.log.levels.ERROR)
		return
	end

	require("toggleterm").setup {
		size = config.size,
		direction = config.direction,
		persist_size = true,
		start_in_insert = true,
		shell = vim.o.shell,
		auto_scroll = true,
		autochdir = false,
	}

	local Terminal = require("toggleterm.terminal").Terminal

	-- Create new terminal instance
	_G.create_claude_terminal = function(opts)
		local instance_id = next_instance_id
		next_instance_id = next_instance_id + 1
		
		local terminal_opts = vim.tbl_deep_extend("force", {
			cmd = config.cmd,
			direction = config.direction,
			size = config.size,
			dir = config.dir,
			close_on_exit = config.close_on_exit,
			start_in_insert = config.start_in_insert,
			auto_scroll = config.auto_scroll,
			display_name = "Claude Code " .. instance_id,
		}, opts or {})
		
		local terminal = Terminal:new(terminal_opts)
		claude_terminals[instance_id] = terminal
		
		return instance_id, terminal
	end

	-- Toggle specific terminal instance
	_G.toggle_claude_code = function(instance_id)
		instance_id = instance_id or last_toggled_id
		
		-- If no specific ID given and last toggled is closed, try to find any open one
		if not instance_id or instance_id == last_toggled_id then
			local any_open = false
			for id, terminal in pairs(claude_terminals) do
				if terminal:is_open() then
					any_open = true
					break
				end
			end
			
			-- If no terminals are open, use last_toggled_id
			if not any_open then
				instance_id = last_toggled_id
			end
		end
		
		if not claude_terminals[instance_id] then
			instance_id = _G.create_claude_terminal()
		end
		
		claude_terminals[instance_id]:toggle()
		last_toggled_id = instance_id
		return instance_id
	end

	-- Create new terminal without auto-toggle
	_G.new_claude_code = function()
		local instance_id = _G.create_claude_terminal()
		return instance_id
	end

	-- List all terminals
	_G.list_claude_terminals = function()
		local terminals = {}
		for id, terminal in pairs(claude_terminals) do
			terminals[id] = {
				id = id,
				name = terminal.display_name or ("Claude Code " .. id),
				is_open = terminal:is_open()
			}
		end
		return terminals
	end

	-- Close specific terminal
	_G.close_claude_terminal = function(instance_id)
		instance_id = instance_id or 1
		if claude_terminals[instance_id] then
			if claude_terminals[instance_id]:is_open() then
				claude_terminals[instance_id]:close()
			end
			claude_terminals[instance_id] = nil
		end
	end

	-- Create initial terminal
	_G.create_claude_terminal()

	-- Terminal focus tracking
	local open_terminals = {}
	local active_terminal_order = {}
	local last_closed_terminal = nil
	
	-- Track which terminal is currently focused
	local function get_focused_terminal()
		local current_win = vim.api.nvim_get_current_win()
		local current_buf = vim.api.nvim_get_current_buf()
		
		for id, terminal in pairs(claude_terminals) do
			if terminal.bufnr == current_buf and terminal:is_open() then
				return id, terminal
			end
		end
		return nil, nil
	end
	
	-- Update active terminal order
	local function update_active_order()
		active_terminal_order = {}
		for id, terminal in pairs(claude_terminals) do
			if terminal:is_open() then
				table.insert(active_terminal_order, id)
			end
		end
		table.sort(active_terminal_order)
	end

	-- Toggle/hide current terminal
	_G.toggle_current_terminal = function()
		local focused_id = get_focused_terminal()
			
		if focused_id then
			-- Close the currently focused terminal
			claude_terminals[focused_id]:close()
			last_closed_terminal = focused_id
			update_active_order()
		else
			-- No focused terminal, restore last closed or create new
			if last_closed_terminal and claude_terminals[last_closed_terminal] then
				claude_terminals[last_closed_terminal]:toggle()
				update_active_order()
			else
				-- Create first terminal if none exist
				if not claude_terminals[1] then
					_G.create_claude_terminal()
				end
				claude_terminals[1]:toggle()
				update_active_order()
			end
		end
	end

	-- Create new terminal and keep it open
	_G.create_and_open_terminal = function()
		local instance_id = _G.create_claude_terminal()
		claude_terminals[instance_id]:toggle()
		update_active_order()
		return instance_id
	end

	-- Telescope picker for terminals (unchanged)
	_G.select_claude_terminal = function()
		local has_telescope, telescope = pcall(require, "telescope")
		if not has_telescope then
			vim.notify("Telescope.nvim is required for terminal selection", vim.log.levels.ERROR)
			return
		end
		
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")
		local previewers = require("telescope.previewers")
		
		local terminals = {}
		for id, terminal in pairs(claude_terminals) do
			table.insert(terminals, {
				id = id,
				name = terminal.display_name or ("Claude Code " .. id),
				terminal = terminal,
				is_open = terminal:is_open()
			})
		end
		
		table.sort(terminals, function(a, b) return a.id < b.id end)
		
		-- Custom previewer for terminal buffers
		local terminal_previewer = previewers.new_buffer_previewer({
			define_preview = function(self, entry, status)
				local terminal = claude_terminals[entry.id]
				if not terminal or not terminal.bufnr or not vim.api.nvim_buf_is_valid(terminal.bufnr) then
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"Terminal not available"})
					return
				end
				
				local lines = vim.api.nvim_buf_get_lines(terminal.bufnr, 0, -1, false)
				if #lines == 0 then
					lines = {"Terminal is empty"}
				end
				
				-- Limit preview to 50 lines for performance
				local preview_lines = {}
				for i = 1, math.min(50, #lines) do
					table.insert(preview_lines, lines[i])
				end
				
				vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_lines)
				vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'claude-code-terminal')
			end
		})
		
		pickers.new({}, {
			prompt_title = "Claude Code Terminals",
			finder = finders.new_table({
				results = terminals,
				entry_maker = function(entry)
					return {
						value = entry,
						display = string.format("%d: %s %s", entry.id, entry.name, entry.is_open and "(open)" or "(closed)"),
						ordinal = tostring(entry.id) .. " " .. entry.name,
						id = entry.id
					}
				end
			}),
			previewer = terminal_previewer,
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						_G.toggle_claude_code(selection.id)
					end
				end)
				return true
			end
		}):find()
	end

	-- Create user commands
	vim.api.nvim_create_user_command("ClaudeCode", function(opts)
		local args = opts.args
		if args == "" then
			_G.toggle_current_terminal()
		else
			local instance_id = tonumber(args)
			if instance_id then
				_G.toggle_claude_code(instance_id)
			else
				vim.notify("Usage: :ClaudeCode [instance_id]", vim.log.levels.ERROR)
			end
		end
	end, { 
		desc = "Toggle current Claude Code terminal",
		nargs = "?"
	})

	vim.api.nvim_create_user_command("ClaudeCodeNew", function()
		_G.create_and_open_terminal()
	end, { desc = "Create and open new Claude Code terminal" })

	vim.api.nvim_create_user_command("ClaudeCodeList", function()
		_G.select_claude_terminal()
	end, { desc = "Select Claude Code terminal with telescope" })


	-- Keymaps
	vim.keymap.set({ "n", "t" }, "<leader>cc", function()
		_G.toggle_current_terminal()
	end, { desc = "Toggle current Claude Code terminal" })

	vim.keymap.set({ "n", "t" }, "<leader>cC", function()
		_G.create_and_open_terminal()
	end, { desc = "Create and open new Claude Code terminal" })

	vim.keymap.set({ "n", "t" }, "<leader>cl", function()
		_G.select_claude_terminal()
	end, { desc = "Select Claude Code terminal" })
end

return M