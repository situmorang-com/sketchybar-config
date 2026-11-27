
local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local popup = require("helpers.popup")

sbar.add("item", "widgets.disk_to_ram_gap", {
    position = "right",
    width = settings.paddings,
    label = { drawing = false },
    icon = { drawing = false }
})

local ram = sbar.add("graph", "widgets.ram", 42, {
    position = "right",
    graph = { color = colors.green },
    background = {
        height = 22,
        color = { alpha = 0 },
        border_color = { alpha = 0 },
        drawing = true,
    },
    icon = {
        string = "􀫦",
        color = colors.white,
    },
    label = {
        string = "ram ??%",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        align = "right",
        padding_right = 0,
        width = 0,
        y_offset = 4,
    },
    padding_right = settings.paddings + 6,
    popup = { align = "center" },
})

local ram_card = popup.register(ram)
local ram_title = popup.title(ram_card, "widgets.ram.popup.title", "Memory")
local ram_details = popup.row(ram_card, "widgets.ram.popup.used", "Used", "--", { mono = true })
local ram_pressure = popup.row(ram_card, "widgets.ram.popup.pressure", "Pressure", "--")
popup.divider(ram_card, "widgets.ram.popup.divider")
local ram_top = {}
for i = 1, 5 do
    ram_top[i] = popup.row(ram_card, "widgets.ram.popup.top." .. i, "", "", { mono = true, key_width = 150 })
end

local function apply_usage(usage, used_gb, total_gb)
    local color = colors.green
    if usage > 85 then
        color = colors.red
    elseif usage > 70 then
        color = colors.orange
    elseif usage > 50 then
        color = colors.yellow
    end

    ram:push({ usage / 100 })
    sbar.animate("tanh", 15, function()
        ram:set({
            graph = { color = color },
            icon = { color = color },
            label = "ram " .. math.floor(usage) .. "%",
        })
    end)

    ram_details:set({
        label = { string = string.format("%.1f / %.0f GB", used_gb, total_gb) }
    })
    ram_title:set({ label = { string = math.floor(usage) .. "%", color = color } })
    local level = usage > 85 and "High" or usage > 70 and "Elevated" or "Normal"
    ram_pressure:set({ label = { string = level, color = color } })
end

-- The cpu_load helper reads memory in the same pass as the CPU (via
-- kern.memorystatus_level, the number `memory_pressure` prints), so this rides
-- on its cpu_update event instead of spawning three processes every 5 seconds.
ram:subscribe("cpu_update", function(env)
    local usage = tonumber(env.mem_used)
    local total_gb = tonumber(env.mem_total_gb) or 0
    if not usage or usage < 0 then return end
    apply_usage(usage, usage / 100 * total_gb, total_gb)
end)

-- Top memory users, refreshed each time the card opens.
ram_card.on_open = function()
    sbar.exec([[ps -Aceo rss=,comm= -m | head -5 | awk '{kb=$1; $1=""; sub(/^ /,""); printf "%s|%.1f GB\n", substr($0,1,22), kb/1048576}']], function(out)
        local i = 0
        for line in out:gmatch("[^\n]+") do
            i = i + 1
            if i > 5 then break end
            local name, size = line:match("([^|]*)|(.*)")
            ram_top[i]:set({ drawing = true, icon = { string = name }, label = { string = size } })
        end
        for j = i + 1, 5 do ram_top[j]:set({ drawing = false }) end
    end)
end
popup.note(ram_card, "widgets.ram.popup.hint", "Right-click for Activity Monitor", {
    align = "center", size = 10.0, color = popup.faint,
})
-- Left-click: the card. Right-click: Activity Monitor.
popup.click_to_toggle(ram_card, { ram }, function()
    sbar.exec("open -a 'Activity Monitor'")
end)

sbar.add("bracket", "widgets.ram.bracket", { ram.name }, {
    background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
    blur_radius = 20,
})

sbar.add("item", "widgets.ram.padding", {
    position = "right",
    width = settings.group_paddings
})
