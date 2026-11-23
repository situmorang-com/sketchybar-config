return {
  black = 0xff181819,
  white = 0xffe2e2e3,
  red = 0xfffc5d7c,
  green = 0xff9ed072,
  blue = 0xff76cce0,
  yellow = 0xffe7c664,
  orange = 0xfff39660,
  magenta = 0xffb39df3,
  grey = 0xff7f8490,
  transparent = 0x00000000,

  -- iOS-style frosted glass colors
  glass = 0x2d1c1c2e,           -- ~18% opacity cool blue-grey (iPhone frosted glass)
  glass_border = 0x18ffffff,    -- ~9% opacity white, barely-there edge highlight
  glass_highlight = 0x08ffffff, -- ~3% opacity white, subtle inner glow

  bar = {
    bg = 0x00000000,            -- Fully transparent for floating islands
    border = 0x00000000,
  },
  -- macOS-style vibrancy: a thin dark tint over a heavy blur, so the
  -- desktop colours glow through like Control Centre / menus.
  popup = {
    bg = 0x4a1e1e24,            -- ~29% neutral dark tint (no blue cast)
    border = 0x2effffff,        -- ~18% white rim, the Mac "glass edge"
  },
  bg1 = 0x2d1c1c2e,             -- Match glass
  bg2 = 0x331c1c2e,             -- Slightly more opaque variant

  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then return color end
    return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
  end,
}
