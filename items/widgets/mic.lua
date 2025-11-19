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
    update_freq = 3,
})

mic:subscribe("routine", function(env)
    sbar.exec("osascript -e 'input volume of (get volume settings)'", function(result)
        local volume = tonumber(result)
        local is_muted = volume == 0

        if is_muted then
            mic:set({
                icon = {
                    string = "􀊲", -- muted mic icon
                    color = colors.red,
                },
            })
        else
            mic:set({
                icon = {
                    string = "􀊰", -- active mic icon
                    color = colors.green,
                },
            })
        end
    end)
end)

mic:subscribe("mouse.clicked", function(env)
    sbar.exec("osascript -e 'input volume of (get volume settings)'", function(result)
        local volume = tonumber(result)
        if volume == 0 then
            sbar.exec("osascript -e 'set volume input volume 50'")
        else
            sbar.exec("osascript -e 'set volume input volume 0'")
        end
        sbar.trigger("routine")
    end)
end)

sbar.add("bracket", "widgets.mic.bracket", { mic.name }, {
    background = { color = colors.bg1 }
})

sbar.add("item", "widgets.mic.padding", {
    position = "right",
    width = settings.group_paddings
})
