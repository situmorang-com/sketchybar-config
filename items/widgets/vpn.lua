local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local vpn = sbar.add("item", "widgets.vpn", {
    position = "right",
    icon = {
        string = "􀙨", -- shield icon for VPN
        color = colors.grey,
    },
    label = {
        string = "vpn",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        padding_right = 0,
        drawing = false, -- hide by default when not connected
    },

    padding_right = settings.paddings + 6,
    update_freq = 5,
})

vpn:subscribe("routine", function(env)
    -- Check for NordVPN specifically
    sbar.exec("pgrep -x NordVPN", function(nordvpn_running)
        if nordvpn_running and nordvpn_running ~= "" then
            -- NordVPN app is running, check connection status
            sbar.exec("ifconfig | grep -A 3 'utun' | grep 'inet ' | head -n1", function(vpn_interface)
                if vpn_interface and vpn_interface ~= "" then
                    -- VPN tunnel is active
                    vpn:set({
                        icon = {
                            color = colors.green,
                            drawing = true,
                        },
                        label = {
                            string = "NordVPN",
                            drawing = true,
                        },
                        background = { drawing = true },
                    })
                    return
                end
            end)
        end
    end)

    -- Check for built-in VPN connections
    sbar.exec("scutil --nc list | grep Connected | head -n1", function(result)
        if result and result ~= "" then
            -- VPN is connected, extract the VPN name
            local vpn_name = result:match('"([^"]+)"')
            if not vpn_name then
                vpn_name = "VPN"
            end

            vpn:set({
                icon = {
                    color = colors.green,
                    drawing = true,
                },
                label = {
                    string = vpn_name,
                    drawing = true,
                },
                background = { drawing = true },
            })
        else
            -- Check if any VPN interface exists as fallback
            sbar.exec("ifconfig | grep -E 'utun|tap|tun' | grep 'flags=' | head -n1", function(vpn_check)
                if not vpn_check or vpn_check == "" then
                    -- No VPN detected, hide the widget
                    vpn:set({
                        icon = {
                            color = colors.grey,
                            drawing = false,
                        },
                        label = { drawing = false },
                        background = { drawing = false },
                    })
                end
            end)
        end
    end)
end)

vpn:subscribe("mouse.clicked", function(env)
    -- Use helper script to toggle NordVPN connection
    sbar.exec("$CONFIG_DIR/helpers/toggle_nordvpn.sh")
end)

sbar.add("bracket", "widgets.vpn.bracket", { vpn.name }, {
    background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
    blur_radius = 20,
})

sbar.add("item", "widgets.vpn.padding", {
    position = "right",
    width = settings.group_paddings
})
