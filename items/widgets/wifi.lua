local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local popup = require("helpers.popup")

-- Execute the event provider binary which provides the event "network_update"
-- for the network interface "en0", which is fired every 2.0 seconds.
sbar.exec("killall network_load >/dev/null; $CONFIG_DIR/helpers/event_providers/network_load/bin/network_load en0 network_update 2.0")


local wifi_up = sbar.add("item", "widgets.wifi1", {
  position = "right",
  padding_left = -5,
  width = 0,
  icon = {
    padding_right = 0,
    font = {
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    string = icons.wifi.upload,
  },
  label = {
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    color = colors.red,
    string = "??? Bps",
  },
  y_offset = 4,
})

local wifi_down = sbar.add("item", "widgets.wifi2", {
  position = "right",
  padding_left = -5,
  icon = {
    padding_right = 0,
    font = {
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    string = icons.wifi.download,
  },
  label = {
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    color = colors.blue,
    string = "??? Bps",
  },
  y_offset = -4,
})

local wifi = sbar.add("item", "widgets.wifi.padding", {
  position = "right",
  label = { drawing = false },
})

-- Background around the item
local wifi_bracket = sbar.add("bracket", "widgets.wifi.bracket", {
  wifi.name,
  wifi_up.name,
  wifi_down.name
}, {
  background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
  blur_radius = 20,
})

-- Card: network details; click a value to copy it.
local wifi_card = popup.register(wifi_bracket)
local wifi_title = popup.title(wifi_card, "widgets.wifi.popup.title", "Wi-Fi")
local ssid = popup.row(wifi_card, "widgets.wifi.popup.ssid", "Network", "…", { key_width = 80, max_chars = 22 })
popup.divider(wifi_card, "widgets.wifi.popup.divider")
local hostname = popup.row(wifi_card, "widgets.wifi.popup.hostname", "Hostname", "…", { key_width = 80, max_chars = 22 })
local ip = popup.row(wifi_card, "widgets.wifi.popup.ip", "IP address", "…", { key_width = 80, mono = true })
local mask = popup.row(wifi_card, "widgets.wifi.popup.mask", "Subnet mask", "…", { key_width = 80, mono = true })
local router = popup.row(wifi_card, "widgets.wifi.popup.router", "Router", "…", { key_width = 80, mono = true })
popup.note(wifi_card, "widgets.wifi.popup.hint", "Click to copy · Right-click icon for networks", {
  align = "center", size = 10.0, color = popup.faint,
})

sbar.add("item", { position = "right", width = settings.group_paddings })

wifi_up:subscribe("network_update", function(env)
  local up_color = (env.upload == "000 Bps") and colors.grey or colors.red
  local down_color = (env.download == "000 Bps") and colors.grey or colors.blue
  wifi_up:set({
    icon = { color = up_color },
    label = {
      string = env.upload,
      color = up_color
    }
  })
  wifi_down:set({
    icon = { color = down_color },
    label = {
      string = env.download,
      color = down_color
    }
  })
end)

wifi:subscribe({"wifi_change", "system_woke"}, function(env)
  sbar.exec("ipconfig getifaddr en0", function(ip)
    local connected = not (ip == "")
    wifi:set({
      icon = {
        string = connected and icons.wifi.connected or icons.wifi.disconnected,
        color = connected and colors.white or colors.red,
      },
    })
  end)
end)

wifi_card.on_open = function()
  sbar.exec("networksetup -getcomputername", function(result)
    hostname:set({ label = { string = result:gsub("%s+$", "") } })
  end)
  sbar.exec("ipconfig getifaddr en0", function(result)
    local addr = result:gsub("%s+$", "")
    ip:set({ label = { string = addr ~= "" and addr or "—" } })
    wifi_title:set({ label = {
      string = addr ~= "" and "Connected" or "Offline",
      color = addr ~= "" and colors.green or colors.red,
    } })
  end)
  -- macOS redacts the SSID for apps without Location permission, so ask the
  -- WeatherLocator helper (which has it) to read it via CoreWLAN.
  sbar.exec([[F="${TMPDIR:-/tmp}/sketchybar_wifi_ssid"; rm -f "$F"
    open -g -j "$CONFIG_DIR/helpers/weather_locator/WeatherLocator.app" --args --ssid "$F"
    for _ in $(seq 1 20); do [ -e "$F" ] && break; sleep 0.25; done
    cat "$F" 2>/dev/null]], function(result)
    local name = result:gsub("%s+$", "")
    ssid:set({ label = { string = name ~= "" and name or "—" } })
  end)
  sbar.exec("networksetup -getinfo Wi-Fi | awk -F 'Subnet mask: ' '/^Subnet mask: / {print $2}'", function(result)
    mask:set({ label = { string = result:gsub("%s+$", "") } })
  end)
  sbar.exec("networksetup -getinfo Wi-Fi | awk -F 'Router: ' '/^Router: / {print $2}'", function(result)
    router:set({ label = { string = result:gsub("%s+$", "") } })
  end)
end
-- Right-click: open the Wi-Fi network list in System Settings.
popup.click_to_toggle(wifi_card, { wifi, wifi_up, wifi_down }, function()
  sbar.exec("open 'x-apple.systempreferences:com.apple.wifi-settings-extension'")
end)

local function copy_label_to_clipboard(env)
  local label = sbar.query(env.NAME).label.value
  sbar.exec("echo \"" .. label .. "\" | pbcopy")
  sbar.set(env.NAME, { label = { string = icons.clipboard, align="center" } })
  sbar.delay(1, function()
    sbar.set(env.NAME, { label = { string = label, align = "right" } })
  end)
end

ssid:subscribe("mouse.clicked", copy_label_to_clipboard)
hostname:subscribe("mouse.clicked", copy_label_to_clipboard)
ip:subscribe("mouse.clicked", copy_label_to_clipboard)
mask:subscribe("mouse.clicked", copy_label_to_clipboard)
router:subscribe("mouse.clicked", copy_label_to_clipboard)
