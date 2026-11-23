
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
    update_freq = 5,
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
    ram:set({
        graph = { color = color },
        icon = { color = color },
        label = "ram " .. math.floor(usage) .. "%",
    })

    ram_details:set({
        label = { string = string.format("%.1f / %.0f GB", used_gb, total_gb) }
    })
    ram_title:set({ label = { string = math.floor(usage) .. "%", color = color } })
    local level = usage > 85 and "High" or usage > 70 and "Elevated" or "Normal"
    ram_pressure:set({ label = { string = level, color = color } })
end

local function read_vm_stat(total_gb)
    sbar.exec([[vm_stat | grep 'Pages active\|Pages wired' | awk '{sum += $3} END {print sum * 16384 / 1024 / 1024 / 1024}']],
        function(used_gb_str)
            local used_gb = tonumber(used_gb_str) or 0
            local usage_pct = total_gb > 0 and (used_gb / total_gb) * 100 or 0
            apply_usage(usage_pct, used_gb, total_gb)
        end)
end

ram:subscribe("routine", function(env)
    sbar.exec("sysctl -n hw.memsize | awk '{print $1 / 1024 / 1024 / 1024}'", function(total_gb_str)
        local total_gb = tonumber(total_gb_str) or 0

        sbar.exec([[memory_pressure | grep 'System-wide memory free percentage:' | awk '{print 100-$5}' | sed 's/%//']],
            function(result)
                local usage = tonumber(result)
                if usage then
                    local used_gb = (usage / 100) * total_gb
                    apply_usage(usage, used_gb, total_gb)
                else
                    read_vm_stat(total_gb)
                end
            end)
    end)
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
popup.click_to_toggle(ram_card, { ram })

sbar.add("bracket", "widgets.ram.bracket", { ram.name }, {
    background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
    blur_radius = 20,
})

sbar.add("item", "widgets.ram.padding", {
    position = "right",
    width = settings.group_paddings
})
