local colors = require("colors")
local settings = require("settings")

local disk_free = sbar.add("item", "widgets.disk.free", {
    position = "right",
    update_freq = 30,
    icon = {
        string = "􀨪",
        color = colors.white,
        padding_left = settings.paddings + 6,
        padding_right = settings.paddings,
    },
    label = {
        string = "?? GB",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        padding_right = settings.paddings + 6,
    },
})

local disk_bracket = sbar.add("bracket", "widgets.disk.bracket", {
    disk_free.name
}, {
    background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
    blur_radius = 20,
    popup = { align = "center" }
})

local disk_details = sbar.add("item", {
    position = "popup." .. disk_bracket.name,
    icon = {
        string = "Used:",
        width = 60,
        align = "left"
    },
    label = {
        string = "??? GB / ??? GB",
        width = 150,
        align = "right"
    },
})

local monitored_folders = {
    {
        name = "WA:",
        path = "/Users/edmundsitumorang/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media"
    },
    {
        name = "Downloads:",
        path = "/Users/edmundsitumorang/Downloads"
    },
    {
        name = "Developer:",
        path = "/Users/edmundsitumorang/Library/Developer"
    },
    {
        name = "Docker:",
        path = "/Users/edmundsitumorang/Library/Containers/com.docker.docker"
    },
    {
        name = "Caches:",
        path = "/Users/edmundsitumorang/Library/Caches"
    },
}

for _, folder in ipairs(monitored_folders) do
    folder.item = sbar.add("item", {
        position = "popup." .. disk_bracket.name,
        click_script = "open \"" .. folder.path .. "\"",
        icon = {
            string = folder.name,
            width = 90,
            align = "left"
        },
        label = {
            string = "click to calculate",
            width = 150,
            align = "right"
        },
    })
end

disk_free:subscribe("routine", function(env)
    -- The Data volume reflects user-available storage on modern macOS/APFS.
    sbar.exec("df -k /System/Volumes/Data | awk 'NR==2 {print $5, $4, $3, $2}' | sed 's/%//'", function(result)
        local parts = {}
        for part in result:gmatch("%S+") do
            table.insert(parts, part)
        end

        local used_pct = tonumber(parts[1])
        local available_kb = tonumber(parts[2])
        local used_kb = tonumber(parts[3])
        local total_kb = tonumber(parts[4])

        local available = "?? GB"
        local used = "?? GB"
        local total = "?? GB"
        if available_kb then
            available = string.format("%.1f GB", available_kb / 1024 / 1024)
        end
        if used_kb then
            used = string.format("%.1f GB", used_kb / 1024 / 1024)
        end
        if total_kb then
            total = string.format("%.1f GB", total_kb / 1024 / 1024)
        end

        local free_pct = used_pct and (100 - used_pct) or 100

        local color = colors.green
        if free_pct < 10 then
            color = colors.red
        elseif free_pct < 20 then
            color = colors.orange
        end

        disk_free:set({
            icon = { color = color },
            label = available,
        })

        disk_details:set({
            icon = { string = "Used:" },
            label = used .. " / " .. total
        })
    end)
end)

local function toggle_disk_popup()
    disk_bracket:set({ popup = { drawing = "toggle" } })
    for _, folder in ipairs(monitored_folders) do
        local monitored_folder = folder
        monitored_folder.item:set({ label = "calculating..." })
        sbar.exec("du -sh \"" .. monitored_folder.path .. "\" 2>/dev/null | awk '{print $1}'", function(result)
            local size = result:gsub("%s+", "")
            if size == "" then
                size = "n/a"
            end
            monitored_folder.item:set({ label = size })
        end)
    end
end

disk_free:subscribe("mouse.clicked", toggle_disk_popup)
sbar.add("item", "widgets.disk.padding", {
    position = "right",
    width = settings.group_paddings
})
