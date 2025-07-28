# claude-code.nvim

A Neovim plugin that launches Claude Code in a right-side panel, similar to Cursor's interface.

## Features

- 🚀 Launches Claude Code in a vertical split on the right
- 📏 Configurable size (default: 100 columns for vertical, 100 lines for horizontal)
- ⚡ Toggle from both normal and terminal modes
- 🔧 Simple setup with sensible defaults
- 📦 Works with toggleterm.nvim

## Screenshot

![Claude Code Terminal Interface]()

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "SouhailBlmn/claude-code.nvim",
  dependencies = { "akinsho/toggleterm.nvim" },
  config = function()
    require("claude-code").setup({
      size = 100,
      direction = "vertical"
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "SouhailBlmn/claude-code.nvim",
  requires = { "akinsho/toggleterm.nvim" },
  config = function()
    require("claude-code").setup({
      size = 100,
      direction = "vertical"
    })
  end,
}
```

## Usage

- **Command**: `:ClaudeCode`
- **Keymap**: `<leader>cc` (works from both normal and terminal modes)

## Configuration

You can customize the plugin by passing options to the setup function:

```lua
require("claude-code").setup({
  size = 100,           -- Terminal size in columns for vertical, lines for horizontal
  direction = "vertical", -- "vertical" or "horizontal"
  cmd = "claude",       -- Command to launch Claude Code
  dir = "git_dir",      -- Directory to open in
  close_on_exit = false,
  start_in_insert = true,
  auto_scroll = true,
  autochdir = false,
})
```

## Requirements

- Neovim 0.8+
- [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim)
- Claude Code CLI installed and in PATH

## License

MIT
