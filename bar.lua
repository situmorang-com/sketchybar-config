local colors = require("colors")

-- Equivalent to the --bar domain
sbar.bar({
  height = 30,
  color = colors.transparent,
  border_color = colors.transparent,
  blur_radius = 0,
  y_offset = 2,
  -- macOS 27 keeps an invisible MenuBarAgent window over the menu-bar strip
  -- while the menu bar is auto-hidden, and it swallows clicks on anything
  -- underneath (FelixKratz/SketchyBar#852). The installed binary is built with
  -- patches/pr892-menubar-reveal.patch (FelixKratz/SketchyBar#892), which lifts
  -- the bar above that window while the menu bar is hidden and drops it back
  -- when macOS reveals the menu bar, so it wants topmost off. See
  -- patches/README.md for how to rebuild it after a brew upgrade.
  topmost = "off",
  padding_right = 4,
  padding_left = 4,
})

-- The PR #892 build lets the native menu bar slide in at the top edge, so the
-- menubar_hotcorner helper (needed with the old always-above patch, kept in
-- patches/disabled/) isn't started any more.
