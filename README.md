<div align="center">

# CenterStage.nvim
##### Easy center your cursor.

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.8+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

</div>

# 

CenterStage is a plugin that keeps your screen with the cursor centered vertically, this implementation is new, so there are integrations and other behaviors that can generate bugs, if you find something, open an issue or a pull request.

⇁ The Problems
1. I like my buffer to be centered, the native way of neovim and setting vim.opt.scrolloff=999, but it has a behavior that I don't like, that when reaching the end of the file the cursor does not remain centered vertically.

## ⇁ The Solutions
1. The solution I found was to use scrolloff for most of the buffer, but at the end center it with my own logic. The solution currently implemented contains a bug that causes the cursor to blink to random locations before appearing in the correct location. I haven't found the cause of this.


## ⇁ Installation

* install using [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    'oaSakamoto/CenterStage.nvim',
    opts = {
      --Some ui plugins may behave strangely like telescope, set filetype to disable.
      --If you discover any other plugin that causes problems, please open an issue or make a pull request in config.lua
        disable_for_ft = {}  --Defaults { 'netrw', 'TelescopePrompt'}
    },
    config = function (_, opts)
        require('CenterStage').setup(opts)
    end
}
```

## ⇁ Contribution

If you have an idea for improvement or a feature that fits the plugin, open an issue or pull request using conventional commit.
