-- Shared popup ("card") behaviour and styling for every SketchyBar widget.
--
-- Behaviour, like a native macOS menu:
--   * only one card is open at a time; opening one closes the others
--   * clicking anywhere outside SketchyBar closes it (helpers/popup_watcher
--     triggers `popup_click_outside`)
--   * switching app, workspace or Space, or the Mac going to sleep, closes it
--   * clicking the widget again toggles it
--
-- Usage:
--   local popup = require("helpers.popup")
--   local card = popup.register(bracket, { on_open = fn, on_close = fn })
--   popup.click_to_toggle(card, { item_a, item_b })
--
-- Look: rows built with popup.title / popup.row / popup.divider / popup.note
-- share one set of fonts, colours and spacing. The card background (glass,
-- blur, radius, shadow) comes from the popup defaults in default.lua.

local colors = require("colors")
local settings = require("settings")

local M = {}

M.WIDTH = 240
M.dim = colors.with_alpha(colors.white, 0.55)
M.faint = colors.with_alpha(colors.white, 0.35)

local cards = {}   -- owner name -> card
local open = {}    -- owner name -> card, for the cards currently showing

local function font(kind, style, size)
  return {
    family = kind == "num" and settings.font.numbers or settings.font.text,
    style = settings.font.style_map[style],
    size = size,
  }
end
M.font = font

function M.is_open(card) return open[card.owner.name] ~= nil end

function M.hide(card)
  if not open[card.owner.name] then return end
  open[card.owner.name] = nil
  card.owner:set({ popup = { drawing = false } })
  if card.on_close then card.on_close() end
end

function M.hide_all(except)
  for _, card in pairs(open) do
    if card ~= except then M.hide(card) end
  end
end

function M.show(card)
  M.hide_all(card)
  if open[card.owner.name] then return end
  open[card.owner.name] = card
  card.owner:set({ popup = { drawing = true } })
  if card.on_open then card.on_open() end
end

function M.toggle(card)
  if M.is_open(card) then M.hide(card) else M.show(card) end
end

-- owner: the item or bracket the popup belongs to ("popup.<owner name>").
function M.register(owner, opts)
  opts = opts or {}
  owner:set({ popup = { align = opts.align or "center" } })
  local card = { owner = owner, on_open = opts.on_open, on_close = opts.on_close }
  cards[owner.name] = card
  return card
end

-- Left-click on any of `items` toggles the card. `on_right` (optional) runs
-- for right-clicks instead.
function M.click_to_toggle(card, items, on_right)
  for _, item in ipairs(items) do
    item:subscribe("mouse.clicked", function(env)
      if env.BUTTON == "right" and on_right then
        M.hide(card)
        on_right(env)
      else
        M.toggle(card)
      end
    end)
  end
end

-- ── Row builders ─────────────────────────────────────────────────────────

local function base(card, name, extra)
  local props = {
    position = "popup." .. card.owner.name,
    width = M.WIDTH,
    padding_left = 6,
    padding_right = 6,
    background = { height = 24, color = colors.transparent },
  }
  for k, v in pairs(extra or {}) do props[k] = v end
  if name then return sbar.add("item", name, props) end
  return sbar.add("item", props)
end

-- Bold heading with an optional dim value on the right.
function M.title(card, name, text, opts)
  opts = opts or {}
  return base(card, name, {
    background = { height = 30, color = colors.transparent },
    icon = {
      string = text,
      color = colors.white,
      font = font("text", "Bold", 13.0),
      width = M.WIDTH - 90,
      align = "left",
      padding_left = 10,
    },
    label = {
      string = opts.value or "",
      color = M.dim,
      font = font("text", "Semibold", 11.0),
      width = 90 - 12,
      align = "right",
      padding_right = 10,
    },
  })
end

-- "Key ............ value" row. opts.key_width moves the split.
function M.row(card, name, key, value, opts)
  opts = opts or {}
  local kw = opts.key_width or math.floor(M.WIDTH * 0.45)
  return base(card, name, {
    click_script = opts.click_script,
    icon = {
      string = key,
      color = M.dim,
      font = font("text", "Regular", 12.0),
      width = kw,
      align = "left",
      padding_left = 10,
    },
    label = {
      string = value or "--",
      color = colors.white,
      font = font(opts.mono and "num" or "text", "Semibold", 12.0),
      width = M.WIDTH - kw - 12,
      align = "right",
      padding_right = 10,
      max_chars = opts.max_chars,
    },
  })
end

-- Single line of text spanning the card (lists, footers).
function M.note(card, name, text, opts)
  opts = opts or {}
  return base(card, name, {
    drawing = opts.drawing,
    click_script = opts.click_script,
    icon = {
      string = text or "",
      color = opts.color or M.dim,
      font = font("text", opts.style or "Regular", opts.size or 12.0),
      width = M.WIDTH - 12,
      align = opts.align or "left",
      padding_left = 10,
      padding_right = 10,
      max_chars = opts.max_chars,
    },
    label = { drawing = false },
  })
end

-- Hairline separator.
function M.divider(card, name)
  return base(card, name, {
    padding_left = 16,
    padding_right = 16,
    width = M.WIDTH,
    icon = { drawing = false },
    label = { drawing = false },
    background = {
      height = 1,
      color = colors.with_alpha(colors.white, 0.12),
      y_offset = -2,
    },
  })
end

-- ── Global closers ───────────────────────────────────────────────────────

sbar.add("event", "popup_click_outside")

local closer = sbar.add("item", "popup.closer", {
  drawing = false,
  updates = true,
  width = 0,
})

closer:subscribe({
  "popup_click_outside",
  "front_app_switched",
  "aerospace_workspace_change",
  "space_change",
  "display_change",
  "system_will_sleep",
}, function()
  if next(open) then M.hide_all() end
end)

-- Open a card from outside, e.g. a keyboard shortcut:
--   sketchybar --trigger popup_open OWNER=widgets.disk.bracket
sbar.add("event", "popup_open")
closer:subscribe("popup_open", function(env)
  local card = cards[env.OWNER or ""]
  if card then M.show(card) end
end)

sbar.exec("killall popup_watcher >/dev/null 2>&1; $CONFIG_DIR/helpers/popup_watcher/bin/popup_watcher")

return M
