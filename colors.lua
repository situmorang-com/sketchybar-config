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
  popup = {
    bg = 0x5e1c1c2e,            -- ~37% opacity frosted popup
    border = 0x20ffffff,        -- ~12% opacity white border
  },
  bg1 = 0x2d1c1c2e,             -- Match glass
  bg2 = 0x331c1c2e,             -- Slightly more opaque variant

  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then return color end
    return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
  end,
}
