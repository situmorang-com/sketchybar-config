local colors = require("colors")

-- Equivalent to the --bar domain
sbar.bar({
  height = 30,
  color = colors.transparent,
  border_color = colors.transparent,
  blur_radius = 0,
  y_offset = 2,
  -- macOS 27 keeps an invisible full-width 44pt MenuBarAgent window across the
  -- top of the screen even while the menu bar is auto-hidden, and it swallows
  -- every click on anything underneath it (FelixKratz/SketchyBar#852). With
  -- topmost off the bar sits under it and no item click ever fires. Stock
  -- sketchybar's "on" uses the same window level as that agent (25), and on
  -- macOS 27.2 the agent recreates its window in front within seconds of every
  -- bar rebuild, so "on" alone doesn't hold either. The installed binary is
  -- built with patches/menubar-agent-level.patch, which puts "on" one level
  -- higher; see patches/README.md for how to rebuild it after a brew upgrade.
  topmost = "on",
  padding_right = 4,
  padding_left = 4,
})

-- Being above the agent also means the native menu bar can never slide in.
-- Park the pointer in the top-right corner to get it: this watcher drops and
-- hides the bar while the pointer stays in the menu-bar band or a menu is open.
sbar.exec("killall menubar_hotcorner >/dev/null; $CONFIG_DIR/helpers/menubar_hotcorner/bin/menubar_hotcorner")
