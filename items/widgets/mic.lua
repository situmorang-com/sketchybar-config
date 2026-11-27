local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local mic = sbar.add("item", "widgets.mic", {
    position = "right",
    icon = {
        string = "􀊰",
        color = colors.green,
    },
    label = {
        drawing = false,
    },

    padding_right = settings.paddings + 6,
})

-- helpers/sysevents watches the default input device through CoreAudio and
-- sends mic_update whenever its volume or mute changes (or the input device
-- itself changes), so nothing here polls.
sbar.add("event", "mic_update")

local last_volume = 50 -- restored when unmuting

mic:subscribe("mic_update", function(env)
    local muted = env.MUTED == "1"
    local volume = tonumber(env.VOLUME)
    if volume and volume > 0 then last_volume = volume end
    sbar.animate("tanh", 10, function()
        mic:set({
            icon = {
                string = muted and "􀊲" or "􀊰",
                color = muted and colors.red or colors.green,
            },
        })
    end)
end)

mic:subscribe("mouse.clicked", function()
    sbar.exec("osascript -e 'input volume of (get volume settings)'", function(result)
        if tonumber(result) == 0 then
            sbar.exec("osascript -e 'set volume input volume " .. last_volume .. "'")
        else
            sbar.exec("osascript -e 'set volume input volume 0'")
        end
    end)
end)

sbar.add("bracket", "widgets.mic.bracket", { mic.name }, {
    background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
    blur_radius = 20,
})

sbar.add("item", "widgets.mic.padding", {
    position = "right",
    width = settings.group_paddings
})
