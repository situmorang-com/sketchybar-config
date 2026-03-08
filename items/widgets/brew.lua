local colors = require("colors")
local settings = require("settings")

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

-- Pre-create static popup items (header + 10 package lines)
local popup_header = sbar.add("item", {
    position = "popup." .. brew_bracket.name,
    icon = {
        string = "Outdated packages:",
        width = 200,
        align = "left",
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Bold"],
            size = 12.0,
        },
    },
    label = { drawing = false },
})

local max_popup_lines = 10
local popup_lines = {}
for i = 1, max_popup_lines do
    popup_lines[i] = sbar.add("item", {
        position = "popup." .. brew_bracket.name,
        drawing = false,
        icon = {
            string = "",
            width = 200,
            align = "left",
            font = {
                family = settings.font.text,
                style = settings.font.style_map["Regular"],
                size = 11.0,
            },
        },
        label = { drawing = false },
    })
end

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
  OUTDATED=$($BREW outdated --quiet 2>/dev/null)
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
        local count = tonumber(count_str) or 0

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

        if count == 0 then
            -- Show "all up to date" in first line, hide rest
            popup_header:set({ icon = { string = "Homebrew status:" } })
            popup_lines[1]:set({
                drawing = true,
                icon = { string = "  Everything up to date!", color = colors.green },
            })
            for i = 2, max_popup_lines do
                popup_lines[i]:set({ drawing = false })
            end
        else
            popup_header:set({ icon = { string = "Outdated packages (" .. count .. "):" } })

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
                    icon = { string = "  " .. packages[i], color = colors.white },
                })
            end

            -- Show overflow message if needed
            if count > display_count then
                popup_lines[display_count + 1]:set({
                    drawing = true,
                    icon = { string = "  +" .. (count - display_count) .. " more...", color = colors.grey },
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

brew_icon:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
        sbar.exec("open -a Terminal 'brew upgrade'")
    else
        brew_bracket:set({ popup = { drawing = "toggle" } })
    end
end)

brew_count:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
        sbar.exec("open -a Terminal 'brew upgrade'")
    else
        brew_bracket:set({ popup = { drawing = "toggle" } })
    end
end)

sbar.add("item", "widgets.brew.padding", {
    position = "right",
    width = settings.group_paddings,
})
