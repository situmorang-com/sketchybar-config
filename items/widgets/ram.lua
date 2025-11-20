
local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

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

local ram_details = sbar.add("item", {
    position = "popup." .. ram.name,
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
        label = string.format("%.1f GB / %.0f GB", used_gb, total_gb)
    })
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

ram:subscribe("mouse.clicked", function(env)
    ram:set({ popup = { drawing = "toggle" } })
end)

sbar.add("bracket", "widgets.ram.bracket", { ram.name }, {
    background = { color = colors.bg1 }
})

sbar.add("item", "widgets.ram.padding", {
    position = "right",
    width = settings.group_paddings
})
