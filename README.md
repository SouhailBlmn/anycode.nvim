# claude-code.nvim

A Neovim plugin that launches multiple Claude Code terminals with intuitive management, similar to Cursor's interface.

## Features

- 🚀 **Multiple Terminals**: Create unlimited Claude Code instances
- 📱 **Smart Toggle**: Close current terminal you're in, restore last closed
- 🔍 **Telescope Integration**: Visual terminal picker with live previews
- ⚡ **Context-Aware**: Works from both normal and terminal modes
- 📏 **Configurable**: Size, direction, and appearance options
- 🔄 **Stack-Based**: Remembers closing order for restoration

## Demo

https://github.com/user-attachments/assets/817c9ace-2c12-40b0-90fd-cb6fa61c9c68

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "SouhailBlmn/claude-code.nvim",
  dependencies = {
    "akinsho/toggleterm.nvim",
    "nvim-telescope/telescope.nvim" -- Optional, for terminal picker
  },
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
  requires = {
    "akinsho/toggleterm.nvim",
    "nvim-telescope/telescope.nvim" -- Optional, for terminal picker
  },
  config = function()
    require("claude-code").setup({
      size = 100,
      direction = "vertical"
    })
  end,
}
```

## Usage

### **Intuitive Terminal Management**

#### **Create Terminals**
- **`<leader>cc`** - Toggle current terminal (smart behavior)
- **`<leader>cC`** - Create and open new terminal
- **`:ClaudeCode`** - Toggle current terminal
- **`:ClaudeCodeNew`** - Create and open new terminal

#### **Manage Multiple Terminals**
- **`<leader>cl`** - Telescope picker with live previews
- **`:ClaudeCodeList`** - Lists all terminals with preview

### **Usage Flow Example**

1. **Start**: Press `<leader>cc` → Opens terminal 1
2. **Create more**: Press `<leader>cC` → Creates and opens terminal 2
3. **Create more**: Press `<leader>cC` → Creates and opens terminal 3
4. **Close current**: Press `<leader>cc` → Hides terminal you're in
5. **Close next**: Press `<leader>cc` → Hides next active terminal
6. **Restore**: After all closed, `<leader>cc` → Reopens last closed terminal

### **From Inside Terminals**
- **`<leader>cc`** - Closes the terminal you're currently in
- **`<leader>cC`** - Creates new terminal (keeps current one open)
- **`<leader>cl`** - Opens telescope picker to select any terminal

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
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for terminal picker)
- Claude Code CLI installed and in PATH

## Keymaps Summary

| Keymap | Mode | Action |
|--------|------|--------|
| `<leader>cc` | Normal/Terminal | Toggle current terminal |
| `<leader>cC` | Normal/Terminal | Create and open new terminal |
| `<leader>cl` | Normal/Terminal | Telescope terminal picker |

## Commands Summary

| Command | Action |
|---------|--------|
| `:ClaudeCode` | Toggle current terminal |
| `:ClaudeCodeNew` | Create and open new terminal |
| `:ClaudeCodeList` | Telescope terminal picker |

## License

MIT
