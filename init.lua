-- Require the sketchybar module
sbar = require("sketchybar")

-- Set the bar name, if you are using another bar instance than sketchybar
-- sbar.set_bar_name("bottom_bar")

-- While the config loads, sbar.animate just applies its changes. SbarLua ends
-- the open transaction when an animate block returns, which also ends
-- begin_config: weather.lua draws its saved reading at load, and from there on
-- every add and set was its own round trip to the bar (~10-25s instead of under
-- a second; measured 2026-11-27). There is nothing on screen to animate yet.
local animate = sbar.animate
local loading = true
sbar.animate = function(curve, duration, fn)
  if loading then return fn() end
  return animate(curve, duration, fn)
end

-- Bundle the entire initial configuration into a single message to sketchybar
sbar.begin_config()
require("bar")
require("default")
require("items")
sbar.end_config()
loading = false
require("helpers.log").write("sketchybar", "config loaded")

-- Workaround for an upstream sketchybar bug (v2.24.0): after the display
-- topology changes across sleep (closing the lid drops the built-in display),
-- the main thread can enter a runaway window-frame / CoreAnimation commit loop
-- (__window_apply_frame_block_invoke -> CA::Transaction::commit, pinned at
-- 35-45% CPU and climbing). That thread also services the mach port, so the
-- message port starves: the lua config stalls, `sketchybar --query` returns
-- nothing, and the bar freezes until the service is restarted.
--
-- Nudging the bar (display=main -> display=all -> --update) does not clear it;
-- once the loop is running, messages never get serviced. So restart the service
-- outright. The restart must NOT go through sketchybar itself for the same
-- reason -- it is driven by launchctl from a detached subshell, which keeps
-- running even after this process wedges.
local wake_handler = sbar.add("item", "wake_handler", {
  drawing = false,
  updates = true,
})

wake_handler:subscribe("system_woke", function(env)
  -- Detached (&) so the event loop is never blocked, and so the restart still
  -- happens if sketchybar wedges in the seconds right after wake. The script
  -- rate-limits itself so a wake event arriving just after startup cannot turn
  -- into a restart loop.
  sbar.exec("($CONFIG_DIR/helpers/wake_restart.sh >/dev/null 2>&1) &")
end)

-- Run the event loop of the sketchybar module (without this there will be no
-- callback functions executed in the lua module)
sbar.event_loop()
