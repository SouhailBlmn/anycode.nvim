# anycode.nvim

A Neovim plugin that launches multiple CLI coding agent terminals with intuitive management, similar to Cursor's interface. Supports any CLI coding agent like Claude Code, Aider, or custom agents.

## Features

- 🚀 **Multiple Terminals**: Create unlimited coding agent instances
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
  "SouhailBlmn/anycode.nvim",
  dependencies = {
    "akinsho/toggleterm.nvim",
    "nvim-telescope/telescope.nvim" -- Optional, for terminal picker
  },
  config = function()
    require("anycode").setup({
      size = 100,
      direction = "vertical"
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "SouhailBlmn/anycode.nvim",
  requires = {
    "akinsho/toggleterm.nvim",
    "nvim-telescope/telescope.nvim" -- Optional, for terminal picker
  },
  config = function()
    require("anycode").setup({
      size = 100,
      direction = "vertical"
    })
  end,
}
```

## Usage

### **Intuitive Terminal Management**

#### **Create Terminals**
- **`<leader>aa`** - Toggle current terminal (smart behavior)
- **`<leader>aA`** - Create and open new terminal
- **`:AnyCode`** - Toggle current terminal
- **`:AnyCodeNew`** - Create and open new terminal

#### **Manage Multiple Terminals**
- **`<leader>al`** - Telescope picker with live previews
- **`:AnyCodeList`** - Lists all terminals with preview

### **Usage Flow Example**

1. **Start**: Press `<leader>aa` → Opens terminal 1
2. **Create more**: Press `<leader>aA` → Creates and opens terminal 2
3. **Create more**: Press `<leader>aA` → Creates and opens terminal 3
4. **Close current**: Press `<leader>aa` → Hides terminal you're in
5. **Close next**: Press `<leader>aa` → Hides next active terminal
6. **Restore**: After all closed, `<leader>aa` → Reopens last closed terminal

### **From Inside Terminals**
- **`<leader>aa`** - Closes the terminal you're currently in
- **`<leader>aA`** - Creates new terminal (keeps current one open)
- **`<leader>al`** - Opens telescope picker to select any terminal

## Configuration

You can customize the plugin by passing options to the setup function:

```lua
require("anycode").setup({
  size = 100,           -- Terminal size in columns for vertical, lines for horizontal
  direction = "vertical", -- "vertical" or "horizontal"
  cmd = "anycode",       -- Command to launch your coding agent (anycode, aider, etc.)
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
- Your preferred CLI coding agent installed and in PATH (AnyCode, Aider, etc.)

## Keymaps Summary

| Keymap | Mode | Action |
|--------|------|--------|
| `<leader>aa` | Normal/Terminal | Toggle current terminal |
| `<leader>aA` | Normal/Terminal | Create and open new terminal |
| `<leader>al` | Normal/Terminal | Telescope terminal picker |
| `<leader>as` | Normal/Visual/Terminal | Send current line or visual selection to coding agent terminal |

## Commands Summary

| Command | Action |
|---------|--------|
| `:AnyCode` | Toggle current terminal |
| `:AnyCodeNew` | Create and open new terminal |
| `:AnyCodeList` | Telescope terminal picker |
| `:AnyCodeSend [id]` | Send current line or visual selection to specified or last-toggled coding agent terminal |

## License

MIT
