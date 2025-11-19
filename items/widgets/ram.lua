local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

sbar.add("item", "widgets.disk_to_ram_gap", {
    position = "right",
    width = settings.group_paddings + settings.paddings + 26,
    label = { drawing = false },
    icon = { drawing = false }
})

local ram = sbar.add("item", "widgets.ram", {
    position = "right",
    icon = {
        string = "􀫦", -- memory chip icon
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
    },
    padding_right = settings.paddings + 6,
    update_freq = 5,
    popup = { align = "center" }
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

ram:subscribe("routine", function(env)
    -- Get total memory first
    sbar.exec("sysctl -n hw.memsize | awk '{print $1 / 1024 / 1024 / 1024}'", function(total_gb_str)
        local total_gb = tonumber(total_gb_str) or 0

        -- Get memory statistics using vm_stat
        sbar.exec("memory_pressure | grep 'System-wide memory free percentage:' | awk '{print 100-$5}' | sed 's/%//'",
            function(result)
                local usage = tonumber(result)
                local used_gb = 0

                if not usage then
                    -- Fallback method using vm_stat
                    sbar.exec(
                        "vm_stat | grep 'Pages active\\|Pages wired' | awk '{sum += $3} END {print sum * 16384 / 1024 / 1024 / 1024}'",
                        function(used_gb_str)
                            used_gb = tonumber(used_gb_str) or 0
                            usage = math.floor((used_gb / total_gb) * 100)

                            local color = colors.green
                            if usage > 50 then
                                color = colors.yellow
                            elseif usage > 70 then
                                color = colors.orange
                            elseif usage > 85 then
                                color = colors.red
                            end

                            ram:set({
                                icon = { color = color },
                                label = "ram " .. usage .. "%",
                            })

                            ram_details:set({
                                label = string.format("%.1f GB / %.0f GB", used_gb, total_gb)
                            })
                        end)
                    return
                end

                used_gb = (usage / 100) * total_gb

                local color = colors.green
                if usage > 50 then
                    color = colors.yellow
                elseif usage > 70 then
                    color = colors.orange
                elseif usage > 85 then
                    color = colors.red
                end

                ram:set({
                    icon = { color = color },
                    label = "ram " .. math.floor(usage) .. "%",
                })

                ram_details:set({
                    label = string.format("%.1f GB / %.0f GB", used_gb, total_gb)
                })
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
