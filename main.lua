--- @since 25.12.29

local path_sep = package.config:sub(1, 1)

local is_dir_path = function(path)
  local last = path:sub(-1)
  return last == "/" or last == "\\"
end

local get_hovered_path = ya.sync(function(_)
  local h = cx.active.current.hovered
  if h then
    local path = tostring(h.url)
    if h.cha.is_dir then
      return path .. path_sep
    end
    return path
  else
    return ""
  end
end)

local get_state_attr = ya.sync(function(state, attr)
  return state[attr]
end)

local set_bookmarks = ya.sync(function(state, path, value)
  state.bookmarks[path] = value
end)

local save_to_file = function(mb_path, bookmarks)
  local parent = mb_path:match("^(.*)[/\\][^/\\]*$")
  if parent and parent ~= "" then
    fs.create("dir_all", Url(parent))
  end

  local file, open_err = io.open(mb_path, "w")
  if file == nil then
    return false, open_err
  end

  local array = {}
  for _, item in pairs(bookmarks) do
    table.insert(array, item)
  end

  table.sort(array, function(x, y)
    return x["tag"] < y["tag"]
  end)

  for _, item in ipairs(array) do
    file:write(string.format("%s\t%s\n", item.tag, item.path))
  end
  file:close()

  return true
end

local notify_save_error = function(err)
  ya.notify({
    title = "Bookmarks",
    content = "Failed to save bookmarks: " .. tostring(err),
    timeout = 3,
    level = "error",
  })
end

local pick_bookmark = function(cli, mb_path)
  local permit = ui.hide()
  local cmd = string.format("%s < %s", cli, ya.quote(mb_path))
  local handle = io.popen(cmd, "r")
  local result = ""
  if handle then
    result = handle:read("*all") or ""
    handle:close()
  end
  permit:drop()

  -- strip trailing newlines only, so paths with leading/trailing spaces stay intact
  result = result:gsub("[\r\n]+$", "")
  local _, path = string.match(result, "([^\t]*)\t(.*)")
  return path
end

local action_search = function(bookmarks, path)
  if path == nil or #path == 0 then
    return
  end

  local bookmark = bookmarks[path]
  if bookmark == nil then
    ya.notify({
      title = "Bookmarks",
      content = 'Bookmark not found for "' .. path .. '"',
      timeout = 2,
      level = "warn",
    })
    return
  end

  if is_dir_path(path) then
    ya.emit("cd", { path })
  else
    ya.emit("reveal", { path })
  end

  ya.notify({
    title = "Bookmarks",
    content = 'Jump to "' .. bookmark.tag .. '"',
    timeout = 2,
    level = "info",
  })
end

local action_save = function(mb_path, bookmarks, path)
  if path == nil or #path == 0 then
    return
  end

  local path_obj = bookmarks[path]
  -- check tag
  local tag = path_obj and path_obj.tag or path:match(".*[\\/]([^\\/]+)[\\/]?$")
  local title = path_obj and "Edit tag (alias name)" or "Tag (alias name)"
  while true do
    local value, event = ya.input({
      title = title,
      value = tag,
      pos = { "top-center", y = 3, w = 40 },
    })
    if event ~= 1 then
      return
    end
    tag = value or ""
    if #tag == 0 then
      ya.notify({
        title = "Bookmarks",
        content = "Empty tag",
        timeout = 2,
        level = "info",
      })
    else
      -- check the tag
      local tag_obj = nil
      for _, item in pairs(bookmarks) do
        if item.tag == tag then
          tag_obj = item
          break
        end
      end
      if tag_obj == nil or tag_obj.path == path then
        break
      end
      ya.notify({
        title = "Bookmarks",
        content = "Duplicated tag",
        timeout = 2,
        level = "info",
      })
    end
  end

  -- save
  set_bookmarks(path, { tag = tag, path = path })
  bookmarks = get_state_attr("bookmarks")
  local ok, err = save_to_file(mb_path, bookmarks)
  if not ok then
    notify_save_error(err)
    return
  end
  ya.notify({
    title = "Bookmarks",
    content = '"' .. tag .. '" saved',
    timeout = 2,
    level = "info",
  })
end

local action_delete = function(mb_path, bookmarks, path)
  if path == nil or #path == 0 then
    return
  end

  local bookmark = bookmarks[path]
  if bookmark == nil then
    ya.notify({
      title = "Bookmarks",
      content = 'Bookmark not found for "' .. path .. '"',
      timeout = 2,
      level = "warn",
    })
    return
  end

  set_bookmarks(path, nil)
  bookmarks = get_state_attr("bookmarks")
  local ok, err = save_to_file(mb_path, bookmarks)
  if not ok then
    notify_save_error(err)
    return
  end
  ya.notify({
    title = "Bookmarks",
    content = '"' .. bookmark.tag .. '" deleted',
    timeout = 2,
    level = "info",
  })
end

return {
  setup = function(state, options)
    local home = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
    state.path = options.path
      or (ya.target_family() == "windows" and (os.getenv("APPDATA") or home) .. "\\yazi\\config\\bookmark")
      or (home .. "/.config/yazi/bookmark")
    state.cli = options.cli or "fzf"

    -- init the bookmarks
    local bookmarks = {}
    for _, item in pairs(options.bookmarks or {}) do
      bookmarks[item.path] = { tag = item.tag, path = item.path }
    end

    -- load the config
    local file = io.open(state.path, "r")
    if file ~= nil then
      for line in file:lines() do
        local tag, path = string.match(line, "(.-)\t(.*)")
        if tag and path then
          bookmarks[path] = { tag = tag, path = path }
        end
      end
      file:close()
    end

    -- create bookmarks file so the finder has input
    local ok, err = save_to_file(state.path, bookmarks)
    if not ok then
      notify_save_error(err)
    end
    state.bookmarks = bookmarks
  end,

  entry = function(_, job)
    local action = job.args[1]
    if not action then
      return
    end

    local mb_path, cli, bookmarks = get_state_attr("path"), get_state_attr("cli"), get_state_attr("bookmarks")
    if action == "save" then
      action_save(mb_path, bookmarks, get_hovered_path())
    elseif action == "search" then
      action_search(bookmarks, pick_bookmark(cli, mb_path))
    elseif action == "delete" then
      action_delete(mb_path, bookmarks, pick_bookmark(cli, mb_path))
    end
  end,
}
