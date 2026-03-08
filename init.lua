-- Require the sketchybar module
sbar = require("sketchybar")

-- Set the bar name, if you are using another bar instance than sketchybar
-- sbar.set_bar_name("bottom_bar")

-- Bundle the entire initial configuration into a single message to sketchybar
sbar.begin_config()
require("bar")
require("default")
require("items")
sbar.end_config()

-- Fix: Force bar to redraw after waking from sleep
-- Uses a background subshell so it does NOT block the event loop
local wake_handler = sbar.add("item", "wake_handler", {
  drawing = false,
  updates = true,
})

wake_handler:subscribe("system_woke", function(env)
  -- Run display refresh in background subshell (&) to avoid blocking
  sbar.exec("(sleep 2 && sketchybar --bar display=main && sleep 1 && sketchybar --bar display=all && sketchybar --update) &")
end)

-- Run the event loop of the sketchybar module (without this there will be no
-- callback functions executed in the lua module)
sbar.event_loop()
