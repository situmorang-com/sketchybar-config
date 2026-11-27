-- Keeps the right-hand widgets clear of the notch.
--
-- The right side changes width as its values change (Wi-Fi speeds during a big
-- download, the brew count, battery time), so no fixed spacing is safe. Every
-- couple of seconds this measures where the leftmost widget actually starts on
-- the built-in display and, if it is within MARGIN of the notch, takes the
-- lowest-priority widget off that display. When there is room again (with some
-- slack so it doesn't flicker) the widget comes back.
--
-- A hidden widget is only hidden on the built-in display: it stays on every
-- external display, which has no notch. So with a monitor attached you get the
-- full set there and a compact set on the laptop screen.
--
-- helpers/sysevents provides the notch's position and the built-in display's id
-- (notch_update). Hides and restores are written to the log (helpers/log.lua).

local settings = require("settings")
local log = require("helpers.log")

local MARGIN = 12     -- points to keep between the widgets and the notch
local SLACK = 20      -- extra room needed before a hidden widget comes back

-- Hidden first to last. Each group lists every bar item that makes up the
-- widget; its popup items are left alone.
local GROUPS = {
    { name = "disk", bracket = "widgets.disk.bracket",
      items = { "widgets.disk.free", "widgets.disk.bracket", "widgets.disk.padding", "widgets.disk_to_ram_gap" } },
    { name = "ram", bracket = "widgets.ram.bracket",
      items = { "widgets.ram", "widgets.ram.bracket", "widgets.ram.padding" } },
    { name = "mic", bracket = "widgets.mic.bracket",
      items = { "widgets.mic", "widgets.mic.bracket", "widgets.mic.padding" } },
    { name = "cpu", bracket = "widgets.cpu.bracket",
      items = { "widgets.cpu", "widgets.cpu.bracket", "widgets.cpu.padding" } },
}

-- The right-side widgets in bar order, leftmost first; the first one drawn on
-- the built-in display gives the group's left edge.
local LEFT_TO_RIGHT = {
    "widgets.cpu.bracket", "widgets.ram.bracket", "widgets.disk.bracket",
    "widgets.mic.bracket", "widgets.vpn.bracket", "widgets.wifi.bracket",
    "widgets.volume.bracket", "widgets.battery.bracket",
}

local notch = {
    right = 0,      -- the notch's right edge, global x; 0 when there is none
    key = nil,      -- "display-<arrangement id>" of the built-in display
    frame_x = 0,
    frame_w = 0,
    others = {},    -- arrangement ids of every other display
    all = {},       -- arrangement ids of every display
}
local hidden = {}   -- stack of { group = <GROUPS entry>, width = <points> }
local settling = false

local touched = false

local function apply(group, visible)
    touched = true
    local props
    if visible then
        -- There is no display value that means "all" again once one is set
        -- ("all" and 0 both become display 0, which never draws), so list them.
        props = { drawing = true, display = table.concat(notch.all, ",") }
    elseif #notch.others > 0 then
        props = { drawing = true, display = table.concat(notch.others, ",") }
    else
        props = { drawing = false }
    end
    for _, name in ipairs(group.items) do sbar.set(name, props) end
end

local function rect_on_builtin(name)
    local q = sbar.query(name)
    local rect = q and q.bounding_rects and q.bounding_rects[notch.key]
    if not rect or rect.origin[1] < -9000 then return nil end
    local x = rect.origin[1]
    -- Rects come back in global coordinates; convert if one ever doesn't.
    if x < notch.frame_x or x > notch.frame_x + notch.frame_w then x = x + notch.frame_x end
    return x, rect.size[1]
end

local function left_edge()
    for _, name in ipairs(LEFT_TO_RIGHT) do
        local x = rect_on_builtin(name)
        if x then return x end
    end
end

local function is_hidden(group)
    for _, h in ipairs(hidden) do
        if h.group == group then return true end
    end
    return false
end

local check

local function settle()
    settling = true
    sbar.delay(0.6, function()
        settling = false
        check()
    end)
end

check = function()
    if settling or notch.right <= 0 or not notch.key then return end
    local x = left_edge()
    if not x then return end
    local gap = x - notch.right

    if gap < MARGIN then
        for _, group in ipairs(GROUPS) do
            if not is_hidden(group) then
                local _, w = rect_on_builtin(group.bracket)
                local width = (w or 80) + settings.group_paddings + 10
                apply(group, false)
                table.insert(hidden, { group = group, width = width })
                log.write("notch", string.format("hid %s on the built-in display (%.0fpt from the notch)", group.name, gap))
                settle()
                return
            end
        end
    elseif #hidden > 0 then
        local top = hidden[#hidden]
        if gap - top.width > MARGIN + SLACK then
            table.remove(hidden)
            apply(top.group, true)
            log.write("notch", string.format("restored %s (%.0fpt free)", top.group.name, gap))
            settle()
        end
    end
end

local fit = sbar.add("item", "widgets.fit", {
    drawing = false,
    updates = true, -- hidden items get no events otherwise
})

sbar.add("event", "notch_update")

fit:subscribe("notch_update", function(env)
    notch.right = tonumber(env.NOTCH_RIGHT) or 0
    local builtin = tonumber(env.BUILTIN) or 0
    notch.key, notch.others, notch.all = nil, {}, {}
    local displays = sbar.query("displays")
    for _, d in ipairs(type(displays) == "table" and displays or {}) do
        table.insert(notch.all, d["arrangement-id"])
        if d.DirectDisplayID == builtin then
            notch.key = "display-" .. d["arrangement-id"]
            notch.frame_x, notch.frame_w = d.frame.x, d.frame.w
        else
            table.insert(notch.others, d["arrangement-id"])
        end
    end

    if notch.right <= 0 or not notch.key then
        -- No notch on screen (lid closed, or an external display only): show all.
        hidden = {}
    end
    -- The set of displays may have changed, so re-apply every widget's displays
    -- once any has been touched (an untouched widget already shows everywhere).
    if touched then
        for _, group in ipairs(GROUPS) do apply(group, not is_hidden(group)) end
    end
    check()
end)

-- cpu_update fires every 2 seconds from the cpu_load helper; widths change on
-- that timescale, so it doubles as the clock for re-measuring.
fit:subscribe({ "cpu_update", "display_change", "system_woke" }, function()
    check()
end)
