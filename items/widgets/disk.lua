local colors = require("colors")
local settings = require("settings")
local popup = require("helpers.popup")

local disk_free = sbar.add("item", "widgets.disk.free", {
    position = "right",
    update_freq = 30,
    icon = {
        string = "􀨪",
        color = colors.white,
        padding_left = settings.paddings + 6,
        padding_right = settings.paddings,
    },
    label = {
        string = "?? GB",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        padding_right = settings.paddings + 6,
    },
})

local disk_bracket = sbar.add("bracket", "widgets.disk.bracket", {
    disk_free.name
}, {
    background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
    blur_radius = 20,
    popup = { align = "center" }
})

local disk_card = popup.register(disk_bracket)
local disk_title = popup.title(disk_card, "widgets.disk.popup.title", "Storage")
local disk_details = popup.row(disk_card, "widgets.disk.popup.used", "Used", "--", { mono = true })
popup.divider(disk_card, "widgets.disk.popup.divider")

-- Folder sizes come from plugins/disk_scan.sh, which caches them:
--   pinned (WhatsApp, Downloads, DEV): re-measured at most every 15 min
--   largest other folders in ~ and ~/Library: re-scanned at most every 6 h
-- Scans run at background priority; the card always shows the cache at once.
local HOME = os.getenv("HOME")
local CACHE = HOME .. "/Library/Caches/sketchybar/"
local SCAN = "$CONFIG_DIR/plugins/disk_scan.sh"
local PINNED_NAMES = {
    [HOME .. "/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media"] = "WhatsApp",
    [HOME .. "/Downloads"] = "Downloads",
    [HOME .. "/DEV"] = "DEV",
}
-- Friendlier names for well-known big folders in the "largest" list.
local KNOWN_NAMES = {
    [HOME .. "/Library/CloudStorage"] = "OneDrive (CloudStorage)",
    [HOME .. "/Library/Application Support"] = "Application Support",
    [HOME .. "/Library/Caches"] = "Caches",
    [HOME .. "/Library/Containers"] = "App containers",
    [HOME .. "/.colima"] = "Colima (Docker VM)",
}
local TOP_ROWS = 6

local function section(name, text)
    return popup.note(disk_card, name, text, { style = "Semibold", size = 11.0, color = popup.dim })
end

local function folder_row(name)
    return popup.row(disk_card, name, "", "", { mono = true, key_width = 150, max_chars = 24 })
end

section("widgets.disk.popup.pinned", "★  Pinned")
local pinned_rows = {}
for i = 1, 3 do pinned_rows[i] = folder_row("widgets.disk.popup.pin." .. i) end
section("widgets.disk.popup.largest", "Largest folders")
local top_rows = {}
for i = 1, TOP_ROWS do top_rows[i] = folder_row("widgets.disk.popup.top." .. i) end

local scan_button = popup.note(disk_card, "widgets.disk.popup.scan", "", {
    align = "center", size = 10.0, color = popup.faint,
})

local function human(kb)
    if kb >= 1024 * 1024 then return string.format("%.1f GB", kb / 1024 / 1024) end
    if kb >= 1024 then return string.format("%.0f MB", kb / 1024) end
    return kb .. " KB"
end

local function display_name(path)
    if PINNED_NAMES[path] then return PINNED_NAMES[path] end
    if KNOWN_NAMES[path] then return KNOWN_NAMES[path] end
    return (path:gsub("^" .. HOME:gsub("%p", "%%%0") .. "/", ""))
end

local function size_color(kb)
    local gb = kb / 1024 / 1024
    if gb >= 50 then return colors.red elseif gb >= 20 then return colors.orange end
    return colors.white
end

-- Fill rows from a cache file ("<epoch>" then "<kb>|<path>" lines).
local function fill(file, rows, on_time)
    sbar.exec("cat '" .. CACHE .. file .. "' 2>/dev/null", function(out)
        local i, first = 0, true
        for line in out:gmatch("[^\n]+") do
            if first then
                first = false
                if on_time then on_time(tonumber(line)) end
            else
                local kb, path = line:match("^(-?%d+)|(.*)$")
                kb = tonumber(kb)
                if kb and i < #rows then
                    i = i + 1
                    local value, color = human(math.max(kb, 0)), size_color(kb)
                    if kb == -1 then value, color = "No access", popup.faint end
                    if kb == -2 then value, color = "Missing", popup.faint end
                    rows[i]:set({
                        drawing = true,
                        icon = { string = display_name(path) },
                        label = { string = value, color = color },
                        click_script = "open \"" .. path .. "\"",
                    })
                end
            end
        end
        if i == 0 and #rows > 0 then
            rows[1]:set({ drawing = true, icon = { string = "Scanning…" }, label = { string = "" } })
            i = 1
        end
        for j = i + 1, #rows do rows[j]:set({ drawing = false }) end
    end)
end

local function ago(epoch)
    if not epoch then return "never" end
    local mins = math.floor((os.time() - epoch) / 60)
    if mins < 1 then return "just now" end
    if mins < 60 then return mins .. " min ago" end
    return math.floor(mins / 60) .. " h ago"
end

local function refresh_rows()
    fill("disk_pinned.txt", pinned_rows)
    fill("disk_top.txt", top_rows, function(epoch)
        scan_button:set({ icon = { string = "Scanned " .. ago(epoch) .. " · Click to rescan" } })
    end)
end

-- Scans skip themselves when the cache is fresh, so these are cheap to call.
local function scan(force)
    local flag = force and " --force" or ""
    sbar.exec("(" .. SCAN .. " pinned" .. flag .. "; " .. SCAN .. " top" .. flag .. ") >/dev/null 2>&1 &")
end

scan_button:subscribe("mouse.clicked", function()
    scan_button:set({ icon = { string = "Rescanning in the background…" } })
    scan(true)
end)

sbar.add("event", "disk_scan_done")
disk_free:subscribe("disk_scan_done", function()
    if popup.is_open(disk_card) then refresh_rows() end
end)

disk_free:subscribe("routine", function(env)
    -- The Data volume reflects user-available storage on modern macOS/APFS.
    sbar.exec("df -k /System/Volumes/Data | awk 'NR==2 {print $5, $4, $3, $2}' | sed 's/%//'", function(result)
        local parts = {}
        for part in result:gmatch("%S+") do
            table.insert(parts, part)
        end

        local used_pct = tonumber(parts[1])
        local available_kb = tonumber(parts[2])
        local used_kb = tonumber(parts[3])
        local total_kb = tonumber(parts[4])

        local available = "?? GB"
        local used = "?? GB"
        local total = "?? GB"
        if available_kb then
            available = string.format("%.1f GB", available_kb / 1024 / 1024)
        end
        if used_kb then
            used = string.format("%.1f GB", used_kb / 1024 / 1024)
        end
        if total_kb then
            total = string.format("%.1f GB", total_kb / 1024 / 1024)
        end

        local free_pct = used_pct and (100 - used_pct) or 100

        local color = colors.green
        if free_pct < 10 then
            color = colors.red
        elseif free_pct < 20 then
            color = colors.orange
        end

        disk_free:set({
            icon = { color = color },
            label = available,
        })

        disk_details:set({ label = { string = used .. " / " .. total } })
        disk_title:set({ label = { string = available .. " free", color = color } })
    end)
end)

-- Folder sizes are measured each time the card opens.
disk_card.on_open = function()
    refresh_rows()
    scan(false)
end
popup.click_to_toggle(disk_card, { disk_free })

sbar.add("item", "widgets.disk.padding", {
    position = "right",
    width = settings.group_paddings
})
