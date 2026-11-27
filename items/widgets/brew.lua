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

-- The card can't scroll natively, so the full list lives here and VISIBLE
-- rows show a window onto it; scrolling over the card moves the window.
local VISIBLE = 8
local packages = {}   -- { name = ..., from = ..., to = ... } for every outdated package
local offset = 0      -- index of the first visible package, minus one
local rows = {}
for i = 1, VISIBLE do
    rows[i] = popup.row(brew_card, "widgets.brew.popup.line." .. i, "", "", {
        mono = true, key_width = 130, max_chars = 14,
    })
    rows[i]:set({ drawing = false, icon = { max_chars = 18 } })
end
local scroll_hint = popup.note(brew_card, "widgets.brew.popup.scroll", "", {
    drawing = false, align = "center", size = 10.0, color = popup.dim,
})

local function render_rows()
    local n = #packages
    offset = math.max(0, math.min(offset, n - VISIBLE))
    for i = 1, VISIBLE do
        local p = packages[offset + i]
        if p then
            rows[i]:set({
                drawing = true,
                icon = { string = p.name, color = colors.white },
                label = { string = p.to, color = popup.dim },
            })
        else
            rows[i]:set({ drawing = false })
        end
    end
    if n > VISIBLE then
        local more = offset + VISIBLE < n and " · scroll for more" or ""
        scroll_hint:set({
            drawing = true,
            icon = { string = string.format("%d–%d of %d%s", offset + 1, offset + VISIBLE, n, more) },
        })
    else
        scroll_hint:set({ drawing = false })
    end
end

local function on_scroll(env)
    local delta = tonumber(env.INFO and env.INFO.delta) or 0
    if delta == 0 or #packages <= VISIBLE then return end
    -- Wheel or trackpad up shows earlier packages. A fast trackpad swipe sends
    -- large deltas, so move at most 3 rows per event to keep it readable.
    local rows_moved = math.min(3, math.max(1, math.floor(math.abs(delta))))
    local step = delta > 0 and -rows_moved or rows_moved
    offset = offset + step
    render_rows()
end
for i = 1, VISIBLE do rows[i]:subscribe("mouse.scrolled", on_scroll) end
scroll_hint:subscribe("mouse.scrolled", on_scroll)
popup_header:subscribe("mouse.scrolled", on_scroll)

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
  # --verbose lines look like "cmake (4.5.0) < 4.5.1"; print the count, then
  # one "name|installed|latest" line per package.
  OUTDATED=$(/usr/bin/perl -e '$SIG{CHLD} = "DEFAULT"; exec @ARGV' "$BREW" outdated --verbose 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "?|brew outdated failed"
    exit 0
  fi
  if [ -z "$OUTDATED" ]; then
    echo "0|"
  else
    echo "$(echo "$OUTDATED" | wc -l | tr -d ' ')|"
    echo "$OUTDATED" | sed -E 's/^([^ ]+) \((.*)\) [<!=]+ (.*)$/\1|\2|\3/'
  fi
]]

local log = require("helpers.log")
local have_count = false

-- A failed check keeps the last count on screen, greyed out; "?" only appears
-- when there has never been a successful check.
local function check_failed(result)
    log.write("brew", "outdated check failed: " .. (type(result) == "string" and result:sub(1, 80) or "no output"))
    brew_icon:set({ icon = { color = colors.grey } })
    brew_count:set({ label = { string = have_count and tostring(outdated_count) or "?", color = colors.grey } })
end

local function update_brew()
    sbar.exec(brew_script, function(result)
        if type(result) ~= "string" or result:match("^%s*$") then
            check_failed(result)
            return
        end

        local count_str = result:match("^([^|]*)")
        local count = tonumber(count_str)
        if not count then
            check_failed(result)
            return
        end
        have_count = true

        -- Update count label with color
        local color = colors.green
        if count > 20 then
            color = colors.red
        elseif count > 10 then
            color = colors.orange
        elseif count > 5 then
            color = colors.yellow
        end

        sbar.animate("tanh", 15, function()
            brew_icon:set({ icon = { color = color } })
            brew_count:set({ label = { string = tostring(count), color = color } })
        end)
        outdated_count = count
        brew_button:set({ label = { string = count > 0 and ("Upgrade all (" .. count .. ")") or "Check for updates" } })

        packages = {}
        for line in result:gmatch("[^\n]+") do
            local name, from, to = line:match("^([^|]+)|([^|]*)|(.*)$")
            if name then
                table.insert(packages, { name = name, from = from, to = to })
            end
        end

        if count == 0 then
            popup_header:set({ label = { string = "Up to date", color = colors.green } })
            packages = { { name = "Everything is up to date", from = "", to = "" } }
            render_rows()
            rows[1]:set({ icon = { color = colors.green } })
        else
            popup_header:set({ label = { string = count .. " outdated", color = color } })
            render_rows()
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
