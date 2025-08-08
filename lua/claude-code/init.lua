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
	full_screen_keymap = "<leader>Cf",
}

-- Terminal instances storage
local claude_terminals = {}
local next_instance_id = 1
local last_toggled_id = 1
local full_screen_terminal = nil
local original_terminal_state = {}
local terminal_state_cache = {}
local open_terminals_count = 0
local last_known_open_state = {}

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
		last_known_open_state[instance_id] = false -- Initialize as closed

		return instance_id, terminal
	end

	-- Toggle specific terminal instance
	_G.toggle_claude_code = function(instance_id)
		instance_id = instance_id or last_toggled_id

		-- Fast path: If we have a valid terminal ID, use it directly
		if claude_terminals[instance_id] then
			claude_terminals[instance_id]:toggle()
			terminal_state_cache[instance_id] = nil -- Clear cache
			last_toggled_id = instance_id
			return instance_id
		end

		-- Slow path: Create new terminal
		instance_id = _G.create_claude_terminal()
		claude_terminals[instance_id]:toggle()
		terminal_state_cache[instance_id] = nil -- Clear cache
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
		local current_buf = vim.api.nvim_get_current_buf()

		-- Fast path: Check last toggled terminal first
		local terminal = claude_terminals[last_toggled_id]
		if terminal and terminal.bufnr == current_buf then
			-- Only check is_open if bufnr matches
			if terminal:is_open() then
				return last_toggled_id, terminal
			end
		end

		-- Check other terminals only if not the last toggled one
		for id, term in pairs(claude_terminals) do
			if id ~= last_toggled_id and term.bufnr == current_buf and term:is_open() then
				return id, term
			end
		end
		return nil, nil
	end

	-- Cache terminal state to avoid repeated is_open() calls
	local function cache_terminal_state(id, state)
		terminal_state_cache[id] = state
	end

	local function is_terminal_open_cached(id)
		local terminal = claude_terminals[id]
		if not terminal then return false end

		-- Only check is_open if we don't have a cached state or if state might be stale
		if terminal_state_cache[id] == nil then
			terminal_state_cache[id] = terminal:is_open()
		end
		return terminal_state_cache[id]
	end

	-- Update active terminal order
	local function update_active_order()
		active_terminal_order = {}
		-- Use a temporary table to collect open terminals
		local open_count = 0
		for id, terminal in pairs(claude_terminals) do
			local is_open = is_terminal_open_cached(id)
			if is_open then
				open_count = open_count + 1
				active_terminal_order[open_count] = id
			end
		end
		-- Only sort if we have multiple terminals
		if open_count > 1 then
			table.sort(active_terminal_order)
		end
	end

	-- Toggle/hide current terminal
	_G.toggle_current_terminal = function()
		local focused_id, focused_terminal = get_focused_terminal()

		if focused_id and focused_terminal then
			-- Close the currently focused terminal
			focused_terminal:close()
			terminal_state_cache[focused_id] = nil -- Clear cache
			last_closed_terminal = focused_id
			update_active_order()
		else
			-- No focused terminal, restore last closed or create new
			if last_closed_terminal and claude_terminals[last_closed_terminal] then
				claude_terminals[last_closed_terminal]:toggle()
				terminal_state_cache[last_closed_terminal] = nil -- Clear cache
				update_active_order()
			else
				-- Create first terminal if none exist
				if not claude_terminals[1] then
					_G.create_claude_terminal()
				end
				claude_terminals[1]:toggle()
				terminal_state_cache[1] = nil -- Clear cache
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
				is_open = is_terminal_open_cached(id)
			})
		end

		table.sort(terminals, function(a, b) return a.id < b.id end)

		-- Custom previewer for terminal buffers
		local terminal_previewer = previewers.new_buffer_previewer({
			define_preview = function(self, entry, status)
				local terminal = claude_terminals[entry.id]
				if not terminal or not terminal.bufnr or not vim.api.nvim_buf_is_valid(terminal.bufnr) then
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false,
						{ "Terminal not available" })
					return
				end

				local lines = vim.api.nvim_buf_get_lines(terminal.bufnr, 0, -1, false)
				if #lines == 0 then
					lines = { "Terminal is empty" }
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
						display = string.format("%d: %s %s", entry.id, entry.name,
							entry.is_open and "(open)" or "(closed)"),
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

	-- Toggle full-screen for current terminal
	_G.toggle_claude_code_fullscreen = function()
		local focused_id, focused_terminal = get_focused_terminal()

		if not focused_id or not focused_terminal then
			vim.notify("No Claude Code terminal is currently focused", vim.log.levels.WARN)
			return
		end

		if full_screen_terminal then
			-- We're in full-screen mode, restore original state
			local original_state = original_terminal_state[full_screen_terminal]
			if original_state and claude_terminals[full_screen_terminal] then
				local terminal = claude_terminals[full_screen_terminal]

				-- Close full-screen terminal
				terminal:close()

				-- Restore original terminal with original settings
				local restored_terminal = Terminal:new({
					cmd = config.cmd,
					direction = original_state.direction or config.direction,
					size = original_state.size or config.size,
					dir = config.dir,
					close_on_exit = config.close_on_exit,
					start_in_insert = config.start_in_insert,
					auto_scroll = config.auto_scroll,
					display_name = "Claude Code " .. full_screen_terminal,
					-- Keep the same buffer if possible
					bufnr = terminal.bufnr,
				})

				claude_terminals[full_screen_terminal] = restored_terminal
				restored_terminal:toggle()

				-- Clear state after restoring
				original_terminal_state[full_screen_terminal] = nil
				terminal_state_cache[full_screen_terminal] = nil -- Clear cache
				full_screen_terminal = nil
			end
		else
			-- Enter full-screen mode
			local current_terminal = claude_terminals[focused_id]
			if current_terminal then
				-- Store original state
				original_terminal_state[focused_id] = {
					direction = config.direction,
					size = config.size,
				}

				-- Close current terminal
				current_terminal:close()

				-- Create full-screen terminal
				local fullscreen_terminal = Terminal:new({
					cmd = config.cmd,
					direction = "float",
					float_opts = {
						border = "single",
						width = vim.o.columns,
						height = vim.o.lines,
						row = 0,
						col = 0,
					},
					dir = config.dir,
					close_on_exit = config.close_on_exit,
					start_in_insert = config.start_in_insert,
					auto_scroll = config.auto_scroll,
					display_name = "Claude Code " .. focused_id .. " (Full Screen)",
					-- Keep the same buffer if possible
					bufnr = current_terminal.bufnr,
				})

				claude_terminals[focused_id] = fullscreen_terminal
				fullscreen_terminal:toggle()
				terminal_state_cache[focused_id] = nil -- Clear cache
				full_screen_terminal = focused_id

				-- Display instance ID in fullscreen mode
				vim.schedule(function()
					if fullscreen_terminal.bufnr and vim.api.nvim_buf_is_valid(fullscreen_terminal.bufnr) then
						vim.api.nvim_buf_set_var(fullscreen_terminal.bufnr, "claude_instance_id", focused_id)
						vim.api.nvim_buf_set_lines(fullscreen_terminal.bufnr, 0, 0, false, {
							"",
							"┌" .. string.rep("─", vim.o.columns - 2) .. "┐",
							"│ Claude Code Instance ID: " .. focused_id .. string.rep(" ", vim.o.columns - 28 - #tostring(focused_id)) .. "│",
							"└" .. string.rep("─", vim.o.columns - 2) .. "┘",
							""
						})
					end
				end)
			end
		end
	end

	-- Kill specific terminal instance
	_G.kill_claude_terminal = function(instance_id)
		instance_id = instance_id or last_toggled_id
		if not claude_terminals[instance_id] then
			vim.notify("Claude Code terminal " .. instance_id .. " does not exist", vim.log.levels.WARN)
			return false
		end

		local terminal = claude_terminals[instance_id]
		if terminal:is_open() then
			terminal:close()
		end
		claude_terminals[instance_id] = nil
		terminal_state_cache[instance_id] = nil
		last_known_open_state[instance_id] = nil
		
		-- Update last_toggled_id if we killed the active one
		if last_toggled_id == instance_id then
			last_toggled_id = 1
		end
		
		vim.notify("Killed Claude Code terminal " .. instance_id, vim.log.levels.INFO)
		return true
	end

	-- Select and kill terminal with telescope
	_G.kill_claude_terminal_select = function()
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

		local terminals = {}
		for id, terminal in pairs(claude_terminals) do
			table.insert(terminals, {
				id = id,
				name = terminal.display_name or ("Claude Code " .. id),
				terminal = terminal,
				is_open = is_terminal_open_cached(id)
			})
		end

		table.sort(terminals, function(a, b) return a.id < b.id end)

		pickers.new({}, {
			prompt_title = "Kill Claude Code Terminal",
			finder = finders.new_table({
				results = terminals,
				entry_maker = function(entry)
					return {
						value = entry,
						display = string.format("%d: %s %s", entry.id, entry.name,
							entry.is_open and "(open)" or "(closed)"),
						ordinal = tostring(entry.id) .. " " .. entry.name,
						id = entry.id
					}
				end
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						_G.kill_claude_terminal(selection.id)
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

	vim.api.nvim_create_user_command("ClaudeCodeKill", function(opts)
		local args = opts.args
		if args == "" then
			_G.kill_claude_terminal_select()
		else
			local instance_id = tonumber(args)
			if instance_id then
				_G.kill_claude_terminal(instance_id)
			else
				vim.notify("Usage: :ClaudeCodeKill [instance_id]", vim.log.levels.ERROR)
			end
		end
	end, {
		desc = "Kill Claude Code terminal",
		nargs = "?"
	})

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

	vim.keymap.set({ "n", "t" }, "<leader>ck", function()
		_G.kill_claude_terminal_select()
	end, { desc = "Kill Claude Code terminal" })

	-- Full-screen toggle keymap (configurable)
	vim.keymap.set({ "n", "t" }, config.full_screen_keymap, function()
		_G.toggle_claude_code_fullscreen()
	end, { desc = "Toggle Claude Code terminal full-screen" })

	-- Additional commands
	vim.api.nvim_create_user_command("ClaudeCodeFull", function()
		_G.toggle_claude_code_fullscreen()
	end, { desc = "Toggle Claude Code terminal full-screen mode" })

	vim.api.nvim_create_user_command("ClaudeCodeKill", function()
		_G.kill_claude_terminal_select()
	end, { desc = "Kill Claude Code terminal" })
end


_G.send_selection_to_claude = function(instance_id, reg)
	instance_id = instance_id or last_toggled_id
	local term = claude_terminals[instance_id]
	if not term then
		-- Create a new terminal if none exists
		instance_id = _G.create_claude_terminal()
		term = claude_terminals[instance_id]
		if not term then
			vim.notify("Failed to create Claude Code terminal", vim.log.levels.ERROR)
			return
		end
	end

	local text = nil

	-- Prefer provided register or helper register 'z' (used by visual mapping)
	if reg and reg ~= "" then
		text = vim.fn.getreg(reg)
	elseif vim.fn.getreg('z') ~= "" then
		text = vim.fn.getreg('z')
		-- clear helper register
		vim.fn.setreg('z', {})
	else
		local function get_visual_selection()
			local vmode = vim.fn.mode()
			if vmode ~= 'v' and vmode ~= 'V' and vmode ~= '\22' then
				return nil
			end
			local s = vim.fn.getpos("'<")
			local e = vim.fn.getpos("'>")
			local start_line = s[2]
			local start_col = s[3]
			local end_line = e[2]
			local end_col = e[3]
			local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
			if #lines == 0 then return "" end
			lines[1] = string.sub(lines[1], start_col, -1)
			lines[#lines] = string.sub(lines[#lines], 1, end_col)
			return table.concat(lines, "\n")
		end

		text = get_visual_selection()
		if not text then
			text = vim.api.nvim_get_current_line()
		else
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>" , true, false, true), 'n', true)
		end
	end

	if text == nil or text == "" then
		vim.notify("No text to send", vim.log.levels.WARN)
		return
	end

	if term:is_open() then
		term:send(text, false)
	else
		term:toggle()
		vim.defer_fn(function()
			if term and term.send then term:send(text, false) end
		end, 50)
	end
end

vim.api.nvim_create_user_command("ClaudeCodeSend", function(opts)
	local id = tonumber(opts.args)
	_G.send_selection_to_claude(id)
end, { nargs = "?", desc = "Send selection or current line to Claude Code terminal" })

vim.keymap.set({ "n", "t" }, "<leader>cs", function()
	_G.send_selection_to_claude()
end, { desc = "Send current line or selection to Claude Code terminal" })

vim.keymap.set("v", "<leader>cs", function()
	-- Yank visual selection into helper register 'z' then send from it (works with float diagnostics)
	vim.cmd('silent! normal! "zy')
	_G.send_selection_to_claude(nil, 'z')
end, { desc = "Send visual selection to Claude Code terminal" })

return M
