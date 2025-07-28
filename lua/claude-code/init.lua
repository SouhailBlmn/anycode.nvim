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

-- Terminal instance
local claude_terminal = nil

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
		size = config.size, -- Set default terminal size
		direction = config.direction,
		persist_size = true, -- Keep terminal size consistent
		start_in_insert = true, -- Start in insert mode
		shell = vim.o.shell, -- Use default shell
		auto_scroll = true, -- Scroll to bottom on output
		autochdir = false, -- Do not auto-change directory
	}



	local Terminal = require("toggleterm.terminal").Terminal

	-- Create the terminal
	claude_terminal = Terminal:new({
		cmd = config.cmd,
		direction = config.direction,
		size = config.size,
		dir = config.dir,
		close_on_exit = config.close_on_exit,
		start_in_insert = config.start_in_insert,
		auto_scroll = config.auto_scroll,
		count = 99,
		display_name = "Claude Code",
	})

	-- Create global toggle function
	_G._toggle_claude_code = function()
		if claude_terminal then
			claude_terminal:toggle()
		end
	end

	-- Create user command
	vim.api.nvim_create_user_command("ClaudeCode", function()
		_G._toggle_claude_code()
	end, { desc = "Toggle Claude Code in right-side panel" })

	-- Set up keymaps for both normal and terminal modes
	vim.keymap.set({ "n", "t" }, "<leader>cc", function()
		_G._toggle_claude_code()
	end, { desc = "Toggle Claude Code" })
end

return M
