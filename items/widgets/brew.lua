local colors = require("colors")
local settings = require("settings")
local popup = require("helpers.popup")

local brew_icon = sbar.add("item", "widgets.brew.icon", {
    position = "right",
    padding_left = 0,
    icon = {
        string = "􀐛", -- shippingbox.fill
        color = colors.white,
        padding_left = 4,
        padding_right = 0,
        font = {
            style = settings.font.style_map["Regular"],
            size = 15.0,
        },
    },
    label = { drawing = false },
    update_freq = 7200, -- every 2 hours
})

local brew_count = sbar.add("item", "widgets.brew.count", {
    position = "right",
    padding_left = 0,
    padding_right = 0,
    icon = { drawing = false },
    label = {
        string = "–",
        padding_left = 4,
        padding_right = 2,
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 12.0,
        },
        align = "right",
    },
})

local brew_bracket = sbar.add("bracket", "widgets.brew.bracket", {
    brew_icon.name,
    brew_count.name,
}, {
    background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
    blur_radius = 20,
    popup = { align = "center" },
})

-- Card: heading with the count, then up to 10 package lines.
local brew_card = popup.register(brew_bracket)
local popup_header = popup.title(brew_card, "widgets.brew.popup.title", "Homebrew")
popup.divider(brew_card, "widgets.brew.popup.divider")

local max_popup_lines = 10
local popup_lines = {}
for i = 1, max_popup_lines do
    popup_lines[i] = popup.note(brew_card, "widgets.brew.popup.line." .. i, "", {
        drawing = false, color = colors.white, max_chars = 34,
    })
end
-- Action button: "Upgrade all" when something is outdated, otherwise
-- "Check for updates". Upgrading runs in a Ghostty window so you can watch it.
local brew_button = sbar.add("item", "widgets.brew.popup.button", {
    position = "popup." .. brew_bracket.name,
    width = popup.WIDTH,
    padding_left = 12,
    padding_right = 12,
    icon = { drawing = false },
    label = {
        string = "Check for updates",
        color = colors.white,
        font = popup.font("text", "Semibold", 12.0),
        width = popup.WIDTH - 24,
        align = "center",
    },
    background = {
        height = 28,
        corner_radius = 9,
        color = colors.with_alpha(colors.blue, 0.35),
        border_width = 1,
        border_color = colors.with_alpha(colors.blue, 0.6),
    },
})
local outdated_count = 0

popup.note(brew_card, "widgets.brew.popup.hint", "Right-click the icon to upgrade too", {
    align = "center", size = 10.0, color = popup.faint,
})

-- Use full path to brew and output a simple format
local brew_script = [[
  BREW="/opt/homebrew/bin/brew"
  if [ ! -x "$BREW" ]; then
    BREW="/usr/local/bin/brew"
  fi
  if [ ! -x "$BREW" ]; then
    echo "0|brew not found"
    exit 0
  fi
  # sketchybar runs commands with SIGCHLD ignored, so children are auto-reaped and
  # brew's own subprocess calls crash ("undefined method 'exitstatus' for nil").
  # Restore the default disposition before exec'ing brew.
  OUTDATED=$(/usr/bin/perl -e '$SIG{CHLD} = "DEFAULT"; exec @ARGV' "$BREW" outdated --quiet 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "?|brew outdated failed"
    exit 0
  fi
  if [ -z "$OUTDATED" ]; then
    echo "0|All up to date!"
  else
    COUNT=$(echo "$OUTDATED" | wc -l | tr -d ' ')
    LIST=$(echo "$OUTDATED" | head -10 | tr '\n' ',')
    TOTAL=$(echo "$OUTDATED" | wc -l | tr -d ' ')
    echo "${COUNT}|${LIST}|${TOTAL}"
  fi
]]

local function update_brew()
    sbar.exec(brew_script, function(result)
        if not result or result:match("^%s*$") then
            brew_count:set({ label = { string = "?", color = colors.grey } })
            return
        end

        local count_str = result:match("^([^|]*)")
        local count = tonumber(count_str)
        if not count then
            brew_icon:set({ icon = { color = colors.grey } })
            brew_count:set({ label = { string = "?", color = colors.grey } })
            return
        end

        -- Update count label with color
        local color = colors.green
        if count > 20 then
            color = colors.red
        elseif count > 10 then
            color = colors.orange
        elseif count > 5 then
            color = colors.yellow
        end

        brew_icon:set({ icon = { color = color } })
        brew_count:set({ label = { string = tostring(count), color = color } })
        outdated_count = count
        brew_button:set({ label = { string = count > 0 and ("Upgrade all (" .. count .. ")") or "Check for updates" } })

        if count == 0 then
            -- Show "all up to date" in first line, hide rest
            popup_header:set({ label = { string = "Up to date", color = colors.green } })
            popup_lines[1]:set({
                drawing = true,
                icon = { string = "Everything is up to date", color = colors.green },
            })
            for i = 2, max_popup_lines do
                popup_lines[i]:set({ drawing = false })
            end
        else
            popup_header:set({ label = { string = count .. " outdated", color = color } })

            -- Parse comma-separated package list
            local pkg_list = result:match("^[^|]*|([^|]*)")
            local packages = {}
            if pkg_list then
                for pkg in pkg_list:gmatch("([^,]+)") do
                    local trimmed = pkg:match("^%s*(.-)%s*$")
                    if trimmed and trimmed ~= "" then
                        table.insert(packages, trimmed)
                    end
                end
            end

            -- Fill popup lines
            local display_count = math.min(#packages, max_popup_lines - 1)
            for i = 1, display_count do
                popup_lines[i]:set({
                    drawing = true,
                    icon = { string = "• " .. packages[i], color = colors.white },
                })
            end

            -- Show overflow message if needed
            if count > display_count then
                popup_lines[display_count + 1]:set({
                    drawing = true,
                    icon = { string = "+" .. (count - display_count) .. " more", color = popup.dim },
                })
                for i = display_count + 2, max_popup_lines do
                    popup_lines[i]:set({ drawing = false })
                end
            else
                for i = display_count + 1, max_popup_lines do
                    popup_lines[i]:set({ drawing = false })
                end
            end
        end
    end)
end

-- Only run on routine timer (every 2 hours), NOT on system_woke
-- brew outdated can take 30+ seconds and blocks the event loop on wake
brew_icon:subscribe("routine", function()
    update_brew()
end)

-- Fetch on first load
update_brew()

local function run_upgrade()
    popup.hide(brew_card)
    sbar.exec("open -na Ghostty --args -e $CONFIG_DIR/plugins/brew_upgrade.sh")
end

popup.click_to_toggle(brew_card, { brew_icon, brew_count }, run_upgrade)

brew_button:subscribe("mouse.clicked", function()
    if outdated_count > 0 then
        run_upgrade()
    else
        brew_button:set({ label = { string = "Checking…" } })
        update_brew()
    end
end)

-- Sent by plugins/brew_upgrade.sh when an upgrade finishes.
sbar.add("event", "brew_refresh")
brew_icon:subscribe("brew_refresh", function() update_brew() end)

sbar.add("item", "widgets.brew.padding", {
    position = "right",
    width = settings.group_paddings,
})
