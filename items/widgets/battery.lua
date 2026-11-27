local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local popup = require("helpers.popup")

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

-- Card: charge, time left, power source, health. Details refresh on open.
local battery_card = popup.register(battery_icon)
local battery_title = popup.title(battery_card, "widgets.battery.popup.title", "Battery")
local remaining_time = popup.row(battery_card, "widgets.battery.popup.time", "Time remaining", "--")
local power_source = popup.row(battery_card, "widgets.battery.popup.source", "Power source", "--")
popup.divider(battery_card, "widgets.battery.popup.divider")
local battery_health = popup.row(battery_card, "widgets.battery.popup.health", "Maximum capacity", "--")
local battery_cycles = popup.row(battery_card, "widgets.battery.popup.cycles", "Cycle count", "--")

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

        sbar.animate("tanh", 15, function()
            battery_icon:set({ icon = { string = icon, color = color } })
            battery_percentage:set({ label = { string = label } })
        end)

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

battery_card.on_open = function()
    remaining_time:set({ label = { string = last_time_label } })
    sbar.exec("pmset -g batt", function(info)
        local pct = info:match("(%d+)%%") or "--"
        local source = info:match("Now drawing from '([^']+)'") or "--"
        local state = info:match("%d+%%; ([%a ]+);") or ""
        battery_title:set({ label = { string = pct .. "%" .. (state ~= "" and (" · " .. state) or "") } })
        power_source:set({ label = { string = source } })
    end)
    sbar.exec([[ioreg -r -c AppleSmartBattery | tr ',{}' '\n\n\n' | sed -nE 's/^[ |]*"?(CycleCount|NominalChargeCapacity|DesignCapacity)"? *= *([0-9]+).*/\1=\2/p' | sort -u | awk -F= '{v[$1]=$2} END{printf "%s|%s|%s", v["CycleCount"], v["NominalChargeCapacity"], v["DesignCapacity"]}']], function(r)
        local cycles, maxcap, design = r:match("([^|]*)|([^|]*)|([^|]*)")
        local m, d = tonumber(maxcap), tonumber(design)
        battery_health:set({ label = { string = (m and d and d > 0) and (math.floor(m / d * 100 + 0.5) .. "%") or "--" } })
        battery_cycles:set({ label = { string = (cycles and cycles ~= "") and cycles or "--" } })
    end)
end
popup.click_to_toggle(battery_card, { battery_icon, battery_percentage, battery_time })

sbar.add("bracket", "widgets.battery.bracket", {
    battery_icon.name,
    battery_percentage.name,
    battery_time.name
}, {
    background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
    blur_radius = 20,
})

sbar.add("item", "widgets.battery.padding", {
    position = "right",
    width = settings.group_paddings
})
