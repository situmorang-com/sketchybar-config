local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local popup = require("helpers.popup")

local popup_width = popup.WIDTH

local volume_percent = sbar.add("item", "widgets.volume1", {
  position = "right",
  icon = { drawing = false },
  label = {
    string = "??%",
    padding_left = -1,
    font = { family = settings.font.numbers }
  },
})

local volume_icon = sbar.add("item", "widgets.volume2", {
  position = "right",
  padding_right = -1,
  icon = {
    string = icons.volume._100,
    width = 0,
    align = "left",
    color = colors.grey,
    font = {
      style = settings.font.style_map["Regular"],
      size = 14.0,
    },
  },
  label = {
    width = 25,
    align = "left",
    font = {
      style = settings.font.style_map["Regular"],
      size = 14.0,
    },
  },
})

local volume_bracket = sbar.add("bracket", "widgets.volume.bracket", {
  volume_icon.name,
  volume_percent.name
}, {
  background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
  blur_radius = 20,
})

-- Card: volume slider, then the output devices (click one to switch).
local volume_card = popup.register(volume_bracket)
local volume_title = popup.title(volume_card, "widgets.volume.popup.title", "Sound")

sbar.add("item", "widgets.volume.padding", {
  position = "right",
  width = settings.group_paddings
})

local volume_slider = sbar.add("slider", popup_width - 24, {
  position = "popup." .. volume_bracket.name,
  padding_left = 18,
  padding_right = 18,
  slider = {
    highlight_color = colors.white,
    background = {
      height = 6,
      corner_radius = 3,
      color = colors.with_alpha(colors.white, 0.18),
    },
    knob = {
      string = "􀀁",
      drawing = true,
      color = colors.white,
    },
  },
  background = { color = colors.transparent, height = 30 },
  click_script = 'osascript -e "set volume output volume $PERCENTAGE"'
})

volume_percent:subscribe("volume_change", function(env)
  local volume = tonumber(env.INFO)
  local icon = icons.volume._0
  if volume > 60 then
    icon = icons.volume._100
  elseif volume > 30 then
    icon = icons.volume._66
  elseif volume > 10 then
    icon = icons.volume._33
  elseif volume > 0 then
    icon = icons.volume._10
  end

  local lead = ""
  if volume < 10 then
    lead = "0"
  end

  volume_icon:set({ label = icon })
  volume_percent:set({ label = lead .. volume .. "%" })
  volume_slider:set({ slider = { percentage = volume } })
  volume_title:set({ label = { string = volume .. "%" } })
end)

local devices_header = popup.note(volume_card, "widgets.volume.popup.devices", "Output", {
  style = "Semibold", size = 11.0, color = popup.dim,
})

volume_card.on_close = function()
  sbar.remove('/volume.device\\.*/')
end

local current_audio_device = "None"
volume_card.on_open = function()
  sbar.remove('/volume.device\\.*/')
  sbar.exec("SwitchAudioSource -t output -c", function(result)
    current_audio_device = result:sub(1, -2)
    sbar.exec("SwitchAudioSource -a -t output", function(available)
      local counter = 0
      for device in string.gmatch(available, '[^\r\n]+') do
        local selected = current_audio_device == device
        sbar.add("item", "volume.device." .. counter, {
          position = "popup." .. volume_bracket.name,
          width = popup_width,
          padding_left = 6,
          padding_right = 6,
          background = { height = 24, color = colors.transparent },
          icon = {
            string = selected and "✓" or "",
            color = colors.blue,
            font = popup.font("text", "Bold", 12.0),
            width = 22,
            align = "center",
            padding_left = 6,
          },
          label = {
            string = device,
            color = selected and colors.white or popup.dim,
            font = popup.font("text", selected and "Semibold" or "Regular", 12.0),
            width = popup_width - 40,
            max_chars = 30,
          },
          click_script = 'SwitchAudioSource -s "' .. device .. '" && sketchybar --set /volume.device\\.*/ label.color=' .. popup.dim .. ' icon.string="" --set $NAME label.color=' .. colors.white .. ' icon.string="✓"',
        })
        counter = counter + 1
      end
    end)
  end)
end

local function volume_scroll(env)
  local delta = env.INFO.delta
  if not (env.INFO.modifier == "ctrl") then delta = delta * 10.0 end

  sbar.exec('osascript -e "set volume output volume (output volume of (get volume settings) + ' .. delta .. ')"')
end

popup.click_to_toggle(volume_card, { volume_icon, volume_percent }, function()
  sbar.exec("open /System/Library/PreferencePanes/Sound.prefpane")
end)
volume_icon:subscribe("mouse.scrolled", volume_scroll)
volume_percent:subscribe("mouse.scrolled", volume_scroll)
