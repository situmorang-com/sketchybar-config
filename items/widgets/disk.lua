local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local disk_percentage = sbar.add("item", "widgets.disk.percentage", {
    position = "right",
    padding_left = -5,
    width = 0,
    icon = { drawing = false },
    label = {
        string = "??%",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        width = 30,
        align = "left",
    },
    y_offset = 4,
    update_freq = 30,
})

local disk_free = sbar.add("item", "widgets.disk.free", {
    position = "right",
    padding_left = -5,
    width = 30,
    icon = {
        padding_right = 0,
        drawing = false
    },
    label = {
        string = "???GB",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        width = 30,
        align = "left",
    },
    y_offset = -4,
})

local disk_icon = sbar.add("item", "widgets.disk.icon", {
    position = "right",
    icon = {
        string = "􀨪", -- pie chart/disk icon
        color = colors.white,
        padding_right = settings.paddings + 6,
    },
    label = { drawing = false },
    update_freq = 30,
})

local disk_bracket = sbar.add("bracket", "widgets.disk.bracket", {
    disk_icon.name,
    disk_percentage.name,
    disk_free.name
}, {
    background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
    blur_radius = 20,
    popup = { align = "center" }
})

local disk_details = sbar.add("item", {
    position = "popup." .. disk_bracket.name,
    icon = {
        string = "Free:",
        width = 60,
        align = "left"
    },
    label = {
        string = "??? GB / ??? GB",
        width = 150,
        align = "right"
    },
})

disk_percentage:subscribe("routine", function(env)
    -- Get disk usage for root volume
    sbar.exec("df -H / | awk 'NR==2 {print $5, $4, $2}' | sed 's/%//'", function(result)
        local parts = {}
        for part in result:gmatch("%S+") do
            table.insert(parts, part)
        end

        local usage = tonumber(parts[1])
        local available = parts[2] or "???"
        local total = parts[3] or "???"

        -- Add B suffix if not present
        if available ~= "???" and not available:match("B$") then
            available = available .. "B"
        end
        if total ~= "???" and not total:match("B$") then
            total = total .. "B"
        end

        if not usage then
            usage = 0
        end

        -- df reports the free percentage in our setup, so derive used pct for coloring
        local used_pct = 100 - usage
        if used_pct < 0 then used_pct = 0 end

        local color = colors.green
        if used_pct > 85 then
            color = colors.red
        elseif used_pct > 70 then
            color = colors.orange
        elseif used_pct > 60 then
            color = colors.yellow
        end

        disk_icon:set({
            icon = { color = color },
        })
        disk_percentage:set({
            label = usage .. "%",
        })

        disk_free:set({
            label = available,
        })

        -- Update popup details
        disk_details:set({
            label = available .. " / " .. total
        })
    end)
end)

disk_free:subscribe("mouse.clicked", function(env)
    disk_bracket:set({ popup = { drawing = "toggle" } })
end)
disk_percentage:subscribe("mouse.clicked", function(env)
    disk_bracket:set({ popup = { drawing = "toggle" } })
end)



sbar.add("item", "widgets.disk.padding", {
    position = "right",
    width = settings.group_paddings
})
