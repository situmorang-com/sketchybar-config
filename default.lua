local settings = require("settings")
local colors = require("colors")

-- Equivalent to the --default domain
sbar.default({
  updates = "when_shown",
  icon = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 14.0
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
    background = { image = { corner_radius = 9 } },
  },
  label = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Semibold"],
      size = 13.0
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
  },
  background = {
    height = 24,
    corner_radius = 12,
    border_width = 0,
    color = colors.transparent,
    image = {
      corner_radius = 14,
      border_color = colors.transparent,
      border_width = 0
    }
  },
  popup = {
    background = {
      border_width = 1,
      corner_radius = 18,
      border_color = colors.popup.border,
      color = colors.popup.bg,
      shadow = { drawing = true, color = 0x66000000, distance = 6, angle = 90 },
    },
    blur_radius = 70,
    y_offset = 6,
  },
  padding_left = 5,
  padding_right = 5,
  scroll_texts = true,
})
