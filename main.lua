local path_sep = package.config:sub(1, 1)

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

local set_state_attr = ya.sync(function(state, attr, value)
  state[attr] = value
end)

local set_bookmarks = ya.sync(function(state, path, value)
  state.bookmarks[path] = value
end)

local sort_bookmarks = function(bookmarks, reverse)
  reverse = reverse or false
  table.sort(bookmarks, function(x, y)
    return x["tag"] < y["tag"]
  end)
  if reverse then
    local n = #bookmarks
    for i = 1, math.floor(n / 2) do
      bookmarks[i], bookmarks[n - i + 1] = bookmarks[n - i + 1], bookmarks[i]
    end
  end
  return bookmarks
end

local save_to_file = function(mb_path, bookmarks)
  local file = io.open(mb_path, "w")
  if file == nil then
    return
  end
  local array = {}
  for _, item in pairs(bookmarks) do
    table.insert(array, item)
  end
  sort_bookmarks(array, false)
  for _, item in ipairs(array) do
    file:write(string.format("%s\t%s\n", item.tag, item.path))
  end
  file:close()
end

local fzf_find = function(cli, mb_path)
  local permit = ui.hide()
  local cmd = string.format('%s < "%s"', cli, mb_path)
  local handle = io.popen(cmd, "r")
  local result = ""
  if handle then
    -- strip
    result = string.gsub(handle:read("*all") or "", "^%s*(.-)%s*$", "%1")
    handle:close()
  end
  permit:drop()
  local _, path = string.match(result or "", "(.-)\t(.*)")
  return path
end

local action_jump = function(bookmarks, path)
  if path == nil then
    return
  end
  local tag = bookmarks[path].tag
  if string.sub(path, -1) == path_sep then
    ya.emit("cd", { path })
  else
    ya.emit("reveal", { path })
  end
  ya.notify({
    title = "Bookmarks",
    content = 'Jump to "' .. tag .. '"',
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
  while true do
    local value, event = ya.input({
      title = "Tag (alias name)",
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
  save_to_file(mb_path, bookmarks)
  ya.notify({
    title = "Bookmarks",
    content = '"' .. tag .. '" saved"',
    timeout = 2,
    level = "info",
  })
end

return {
  setup = function(state, options)
    state.path = options.path
      or (ya.target_family() == "windows" and os.getenv("APPDATA") .. "\\yazi\\config\\bookmark")
      or (os.getenv("HOME") .. "/.config/yazi/bookmark")
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
    -- create bookmarks file to enable fzf
    save_to_file(state.path, bookmarks)
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
    elseif action == "jump_by_fzf" then
      action_jump(bookmarks, fzf_find(cli, mb_path))
    end
  end,
}
