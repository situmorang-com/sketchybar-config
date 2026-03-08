local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

-- Padding item required because of bracket
sbar.add("item", { width = 5 })

local apple = sbar.add("item", {
  icon = {
    font = { size = 16.0 },
    string = icons.apple,
    padding_right = 8,
    padding_left = 8,
  },
  label = { drawing = false },
  background = {
    color = colors.transparent,
    border_width = 0,
  },
  padding_left = 1,
  padding_right = 1,
  click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0"
})

-- iOS frosted glass island
sbar.add("bracket", { apple.name }, {
  background = {
    color = colors.glass,
    height = 30,
    border_color = colors.glass_border,
    border_width = 1,
    corner_radius = 14,
  },
  blur_radius = 20,
})

-- Padding item required because of bracket
sbar.add("item", { width = 7 })
