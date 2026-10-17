# bookmark.yazi

A [Yazi](https://github.com/sxyazi/yazi) plugin for bookmark management, supporting the following features

- Persistent bookmarks. No bookmarks are lost after you close yazi.
- Support fuzzy search through an external finder such as [fzf](https://github.com/junegunn/fzf) or [skim](https://github.com/lotabout/skim).
- Delete bookmarks through the same finder.
- Configure your bookmarks using Lua language.

## Installation

> [!NOTE]
> Yazi >= 25.12.29.

```sh
# Linux/macOS
git clone https://github.com/Jacky-Lzx/bookmark.yazi.git ~/.config/yazi/plugins/bookmark.yazi

# Windows
git clone https://github.com/Jacky-Lzx/bookmark.yazi.git $env:APPDATA\yazi\config\plugins\bookmark.yazi

# Or install it with the Yazi package manager
ya pkg add Jacky-Lzx/bookmark
```

## Usage

Add this to your `init.lua`

```lua
-- You can configure your bookmarks by lua language
local bookmarks = {}

local path_sep = package.config:sub(1, 1)
local home_path = ya.target_family() == "windows" and os.getenv("USERPROFILE") or os.getenv("HOME")
local config_home = os.getenv("YAZI_CONFIG_HOME")
  or ((os.getenv("XDG_CONFIG_HOME") or (home_path .. "/.config")) .. "/yazi")

if ya.target_family() == "windows" then
  table.insert(bookmarks, {
    tag = "Scoop Local",
    path = (os.getenv("SCOOP") or home_path .. "\\scoop") .. "\\",
  })
  table.insert(bookmarks, {
    tag = "Scoop Global",
    path = (os.getenv("SCOOP_GLOBAL") or "C:\\ProgramData\\scoop") .. "\\",
  })
end
table.insert(bookmarks, {
  tag = "Desktop",
  path = home_path .. path_sep .. "Desktop" .. path_sep,
})

require("bookmark"):setup {
  -- Optional, the path ending with a path separator represents a folder.
  bookmarks = bookmarks,
  -- Optional, the command line of the fuzzy finder (fzf, sk, ...).
  cli = "fzf",
  -- Optional, the path of bookmarks.
  path = config_home .. "/bookmark",
}
```

Add this to your `keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on = [ "u", "a" ]
run = "plugin bookmark -- save"
desc = "Add bookmark"

[[mgr.prepend_keymap]]
on = [ "u", "G" ]
run = "plugin bookmark -- search"
desc = "Search bookmark"

[[mgr.prepend_keymap]]
on = [ "u", "d" ]
run = "plugin bookmark -- delete"
desc = "Delete bookmark"
```

## Actions

| Action   | Description                                                                                 |
| -------- | ------------------------------------------------------------------------------------------- |
| `save`   | Add or update a bookmark for the hovered file or folder.                                    |
| `search` | Pick a bookmark with the configured finder, then `cd` to it (folder) or `reveal` it (file). |
| `delete` | Pick a bookmark with the configured finder and delete it.                                   |

## Configuration options

| Option      | Type     | Default                   | Description                                                  |
| ----------- | -------- | ------------------------- | ------------------------------------------------------------ |
| `bookmarks` | `table`  | `{}`                      | Bookmarks defined in Lua, each with a `tag` and `path`.      |
| `cli`       | `string` | `"fzf"`                   | The fuzzy finder command line used by `search` and `delete`. |
| `path`      | `string` | `~/.config/yazi/bookmark` | The file where bookmarks are persisted.                      |

Bookmarks are stored as `tag<TAB>path`, one per line, sorted by tag. A `path` ending with the path separator is treated as a folder.

On Windows the default `path` is `%APPDATA%\yazi\config\bookmark`.
