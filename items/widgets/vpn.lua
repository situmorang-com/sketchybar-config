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
        drawing = false, -- shown only while a VPN is up
    },

    padding_right = settings.paddings + 6,
    update_freq = 5,
})

sbar.add("event", "vpn_update")

-- helpers/vpn_status.sh prints "<on|connecting|off>|<label>"; WARP is checked
-- first, then any connected macOS VPN service (NordVPN registers as one).
local state_colors = {
    on = colors.green,
    connecting = colors.yellow,
    off = colors.grey,
}

local function update_vpn()
    sbar.exec("$CONFIG_DIR/helpers/vpn_status.sh", function(result)
        local state, name = (result or ""):match("^(%a+)|([^\n]*)")
        state = state_colors[state] and state or "off"
        vpn:set({
            icon = { color = state_colors[state], drawing = true },
            label = { string = name or "", drawing = state ~= "off" },
        })
    end)
end

vpn:subscribe({ "routine", "vpn_update", "system_woke", "forced" }, update_vpn)

vpn:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
        sbar.exec("$CONFIG_DIR/helpers/toggle_nordvpn.sh")
    else
        vpn:set({ icon = { color = colors.yellow } })
        sbar.exec("$CONFIG_DIR/helpers/toggle_warp.sh")
    end
end)

sbar.add("bracket", "widgets.vpn.bracket", { vpn.name }, {
    background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
    blur_radius = 20,
})

sbar.add("item", "widgets.vpn.padding", {
    position = "right",
    width = settings.group_paddings
})
