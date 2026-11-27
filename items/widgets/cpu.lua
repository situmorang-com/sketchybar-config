local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local popup = require("helpers.popup")

-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
sbar.exec("killall cpu_load >/dev/null; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0")

local cpu = sbar.add("graph", "widgets.cpu" , 42, {
  position = "right",
  graph = { color = colors.blue },
  background = {
    height = 22,
    color = { alpha = 0 },
    border_color = { alpha = 0 },
    drawing = true,
  },
  icon = { string = icons.cpu },
  label = {
    string = "cpu ??%",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    align = "right",
    padding_right = 0,
    width = 0,
    y_offset = 4
  },
  padding_right = settings.paddings + 6,
  popup = { align = "center" },
})

local cpu_card = popup.register(cpu)
local cpu_title = popup.title(cpu_card, "widgets.cpu.popup.title", "Processor")
local cpu_user = popup.row(cpu_card, "widgets.cpu.popup.user", "User", "--", { mono = true })
local cpu_sys = popup.row(cpu_card, "widgets.cpu.popup.sys", "System", "--", { mono = true })
popup.divider(cpu_card, "widgets.cpu.popup.divider")
local cpu_top = {}
for i = 1, 5 do
  cpu_top[i] = popup.row(cpu_card, "widgets.cpu.popup.top." .. i, "", "", { mono = true, key_width = 150 })
end
popup.note(cpu_card, "widgets.cpu.popup.hint", "Right-click for Activity Monitor", {
    align = "center", size = 10.0, color = popup.faint,
})

-- Top CPU users, like the RAM card's list. Percentages are per core, as in
-- Activity Monitor, so a busy app can show over 100%.
local function refresh_top()
  sbar.exec([[ps -Aceo %cpu=,comm= -r | head -5 | awk '{p=$1; $1=""; sub(/^ /,""); printf "%s|%.1f%%\n", substr($0,1,22), p}']], function(out)
    local i = 0
    for line in (type(out) == "string" and out or ""):gmatch("[^\n]+") do
      i = i + 1
      if i > 5 then break end
      local name, pct = line:match("([^|]*)|(.*)")
      cpu_top[i]:set({ drawing = true, icon = { string = name }, label = { string = pct } })
    end
    for j = i + 1, 5 do cpu_top[j]:set({ drawing = false }) end
  end)
end
-- Latest reading from cpu_update, so the card is filled the moment it opens.
local last = { load = 0, user = 0, sys = 0, color = colors.blue }

local function refresh_header()
  cpu_title:set({ label = { string = math.floor(last.load) .. "%", color = last.color } })
  cpu_user:set({ label = { string = last.user .. "%" } })
  cpu_sys:set({ label = { string = last.sys .. "%" } })
end

cpu_card.on_open = function()
  refresh_header()
  refresh_top()
end

cpu:subscribe("cpu_update", function(env)
  -- Also available: env.user_load, env.sys_load
  -- Clamp to 0..100: a negative value here serializes as a leading-dash token
  -- ("--push widgets.cpu -2935485.43"), which sketchybar parses as a domain.
  -- That desyncs the message batch and silently drops the --set commands
  -- batched behind it.
  local load = tonumber(env.total_load) or 0
  if load < 0 then
    load = 0
  elseif load > 100 then
    load = 100
  end
  cpu:push({ load / 100. })

  local color = colors.blue
  if load > 30 then
    if load < 60 then
      color = colors.yellow
    elseif load < 80 then
      color = colors.orange
    else
      color = colors.red
    end
  end

  sbar.animate("tanh", 15, function()
    cpu:set({
      graph = { color = color },
      label = "cpu " .. env.total_load .. "%",
    })
  end)

  last.load, last.color = load, color
  last.user, last.sys = tonumber(env.user_load) or 0, tonumber(env.sys_load) or 0
  if popup.is_open(cpu_card) then
    refresh_header()
    refresh_top() -- live while the card is open; nothing runs while it's closed
  end
end)

-- Left-click: the card. Right-click: Activity Monitor.
popup.click_to_toggle(cpu_card, { cpu }, function()
  sbar.exec("open -a 'Activity Monitor'")
end)

-- Background around the cpu item
sbar.add("bracket", "widgets.cpu.bracket", { cpu.name }, {
  background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
  blur_radius = 20,
})

-- Background around the cpu item
sbar.add("item", "widgets.cpu.padding", {
  position = "right",
  width = settings.group_paddings
})
