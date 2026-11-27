-- A small log for things that go wrong quietly: a widget's command failing, a
-- fetch timing out, a widget hidden to keep clear of the notch.
--
--   ~/.local/state/sketchybar/sketchybar.log   (rotated to .log.1 at 256 KB)
--
-- Watch it with:  tail -f ~/.local/state/sketchybar/sketchybar.log
--
-- Usage:
--   local log = require("helpers.log")
--   log.write("weather", "fetch failed, keeping last reading")
--   log.exec("disk", "df -k /", function(result, exit_code) ... end)

local M = {}

M.dir = os.getenv("HOME") .. "/.local/state/sketchybar"
M.file = M.dir .. "/sketchybar.log"
local MAX_BYTES = 256 * 1024

os.execute("mkdir -p '" .. M.dir .. "'")

function M.write(source, message)
  local f = io.open(M.file, "a")
  if not f then return end
  local size = f:seek("end")
  if size and size > MAX_BYTES then
    f:close()
    os.rename(M.file, M.file .. ".1")
    f = io.open(M.file, "a")
    if not f then return end
  end
  local text = tostring(message):gsub("%s+$", ""):gsub("\n", " ⏎ ")
  f:write(os.date("%Y-%m-%d %H:%M:%S"), " [", source, "] ", text, "\n")
  f:close()
end

-- sbar.exec that records a non-zero exit, with the command and the start of
-- its output, before handing the result on.
function M.exec(source, command, callback)
  sbar.exec(command, function(result, exit_code)
    if exit_code and exit_code ~= 0 then
      local out = type(result) == "string" and result:sub(1, 160) or ""
      M.write(source, "exit " .. exit_code .. " from `" .. command:sub(1, 120) .. "` " .. out)
    end
    if callback then callback(result, exit_code) end
  end)
end

-- Read and write a small value that should survive a sketchybar restart (the
-- last good weather reading, for example).
function M.load_state(name)
  local f = io.open(M.dir .. "/" .. name, "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

function M.save_state(name, value)
  local f = io.open(M.dir .. "/" .. name, "w")
  if not f then return end
  f:write(value)
  f:close()
end

return M
