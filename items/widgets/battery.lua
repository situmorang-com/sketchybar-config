local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local battery_percentage = sbar.add("item", "widgets.battery.percentage", {
    position = "right",
    padding_left = -30,
    icon = { drawing = false },
    label = {
        string = "??%",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        align = "left",
        width = -30,
        y_offset = 4,
    },
    update_freq = 180,
})

local battery_time = sbar.add("item", "widgets.battery.time", {
    position = "right",
    padding_left = -5,
    icon = { drawing = false },
    label = {
        string = "??h",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Regular"],
            size = 9.0,
        },
        align = "left",
        width = 30,
        y_offset = -4,
    },
})

local battery_icon = sbar.add("item", "widgets.battery.icon", {
    position = "right",
    icon = {
        string = icons.battery._100,
        padding_right = settings.paddings + 0,
        font = {
            style = settings.font.style_map["Regular"],
            size = 19.0,
        }
    },
    label = { drawing = false }
})

local remaining_time = sbar.add("item", {
    position = "popup." .. battery_icon.name,
    icon = {
        string = "Time remaining:",
        width = 30,
        align = "left"
    },
    label = {
        string = "??:??h",
        width = 0,
        align = "right"
    },
})

local last_time_label = "??h"

battery_percentage:subscribe({ "routine", "power_source_change", "system_woke" }, function()
    sbar.exec("pmset -g batt", function(batt_info)
        local icon = icons.battery._0
        local label = "??%"

        local charge = batt_info:match("(%d+)%%")
        if charge then
            label = charge .. "%"
            charge = tonumber(charge)
        end

        local color = colors.green
        local charging = batt_info:find("AC Power") ~= nil

        if charging then
            icon = icons.battery.charging
        else
            if charge and charge > 80 then
                icon = icons.battery._100
            elseif charge and charge > 60 then
                icon = icons.battery._75
            elseif charge and charge > 40 then
                icon = icons.battery._50
            elseif charge and charge > 20 then
                icon = icons.battery._25
                color = colors.orange
            else
                icon = icons.battery._0
                color = colors.red
            end
        end

        battery_icon:set({ icon = { string = icon, color = color } })
        battery_percentage:set({ label = { string = label } })

        local time_label = "--"
        local remaining = batt_info:match("(%d+:%d+)%s+remaining")
        if remaining then
            time_label = remaining .. "h"
        elseif charging then
            time_label = "AC"
        elseif batt_info:match("no estimate") then
            time_label = "--"
        end

        last_time_label = time_label
        battery_time:set({ label = { string = time_label } })
    end)
end)

battery_percentage:subscribe("mouse.clicked", function()
    battery_icon:set({ popup = { drawing = "toggle" } })
    remaining_time:set({ label = { string = last_time_label } })
end)

battery_time:subscribe("mouse.clicked", function()
    battery_icon:set({ popup = { drawing = "toggle" } })
    remaining_time:set({ label = { string = last_time_label } })
end)

battery_icon:subscribe("mouse.clicked", function()
    battery_icon:set({ popup = { drawing = "toggle" } })
    remaining_time:set({ label = { string = last_time_label } })
end)

sbar.add("bracket", "widgets.battery.bracket", {
    battery_icon.name,
    battery_percentage.name,
    battery_time.name
}, {
    background = { color = colors.bg1 }
})

sbar.add("item", "widgets.battery.padding", {
    position = "right",
    width = settings.group_paddings
})
