local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local popup = require("helpers.popup")

-- Weather condition icons (SF Symbols) mapped from WMO weather codes
local weather_icons = {
    [0]  = "􀆮",  -- Clear sky - sun.max.fill
    [1]  = "􀆮",  -- Mainly clear
    [2]  = "􀇕",  -- Partly cloudy - cloud.sun.fill
    [3]  = "􀇃",  -- Overcast - cloud.fill
    [45] = "􀇋",  -- Fog - cloud.fog.fill
    [48] = "􀇋",  -- Depositing rime fog
    [51] = "􀇅",  -- Light drizzle - cloud.drizzle.fill
    [53] = "􀇅",  -- Moderate drizzle
    [55] = "􀇅",  -- Dense drizzle
    [56] = "􀇅",  -- Light freezing drizzle
    [57] = "􀇅",  -- Dense freezing drizzle
    [61] = "􀇇",  -- Slight rain - cloud.rain.fill
    [63] = "􀇇",  -- Moderate rain
    [65] = "􀇉",  -- Heavy rain - cloud.heavyrain.fill
    [66] = "􀇇",  -- Light freezing rain
    [67] = "􀇉",  -- Heavy freezing rain
    [71] = "􀇏",  -- Slight snowfall - cloud.snow.fill
    [72] = "􀇏",  -- Moderate snowfall
    [73] = "􀇏",  -- Heavy snowfall
    [77] = "􀇏",  -- Snow grains
    [80] = "􀇇",  -- Slight rain showers
    [81] = "􀇉",  -- Moderate rain showers
    [82] = "􀇉",  -- Violent rain showers
    [85] = "􀇏",  -- Slight snow showers
    [86] = "􀇏",  -- Heavy snow showers
    [95] = "􀇟",  -- Thunderstorm - cloud.bolt.fill
    [96] = "􀇟",  -- Thunderstorm with slight hail
    [99] = "􀇟",  -- Thunderstorm with heavy hail
}

local weather_descriptions = {
    [0]  = "Clear sky",
    [1]  = "Mainly clear",
    [2]  = "Partly cloudy",
    [3]  = "Overcast",
    [45] = "Fog",
    [48] = "Freezing fog",
    [51] = "Light drizzle",
    [53] = "Drizzle",
    [55] = "Dense drizzle",
    [56] = "Freezing drizzle",
    [57] = "Dense freezing drizzle",
    [61] = "Slight rain",
    [63] = "Moderate rain",
    [65] = "Heavy rain",
    [66] = "Freezing rain",
    [67] = "Heavy freezing rain",
    [71] = "Light snow",
    [72] = "Moderate snow",
    [73] = "Heavy snow",
    [77] = "Snow grains",
    [80] = "Rain showers",
    [81] = "Moderate showers",
    [82] = "Heavy showers",
    [85] = "Light snow showers",
    [86] = "Heavy snow showers",
    [95] = "Thunderstorm",
    [96] = "Thunderstorm + hail",
    [99] = "Severe thunderstorm",
}

local weather_icon = sbar.add("item", "widgets.weather.icon", {
    position = "right",
    padding_left = 0,
    icon = {
        string = "􀆮",
        color = colors.yellow,
        padding_left = 4,
        padding_right = 0,
        font = {
            style = settings.font.style_map["Regular"],
            size = 16.0,
        },
    },
    label = { drawing = false },
    update_freq = 1800, -- every 30 minutes
})

local weather_temp = sbar.add("item", "widgets.weather.temp", {
    position = "right",
    padding_left = 0,
    padding_right = 0,
    icon = { drawing = false },
    label = {
        string = "--°",
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

local weather_bracket = sbar.add("bracket", "widgets.weather.bracket", {
    weather_icon.name,
    weather_temp.name,
}, {
    background = { color = colors.glass, border_color = colors.glass_border, border_width = 1, corner_radius = 14, height = 30 },
    blur_radius = 20,
    popup = { align = "center" },
})

-- ── Popup card ────────────────────────────────────────────────────────────
-- Header (big icon + temperature), condition with today's high/low, place,
-- a hairline, then the detail rows. Opening/closing is handled by
-- helpers/popup.lua (click outside, app/workspace switch, or click the card).

local POPUP_W = popup.WIDTH
local dim = colors.with_alpha(colors.white, 0.55)
local faint = colors.with_alpha(colors.white, 0.35)
local popup_pos = "popup." .. weather_bracket.name

-- Card look (translucent glass, radius, blur, shadow) comes from the shared
-- popup style in default.lua / colors.lua.

local function text_font(style, size)
    return { family = settings.font.text, style = settings.font.style_map[style], size = size }
end

local function num_font(style, size)
    return { family = settings.font.numbers, style = settings.font.style_map[style], size = size }
end

local popup_header = sbar.add("item", "widgets.weather.popup.header", {
    position = popup_pos,
    width = POPUP_W,
    padding_left = 6,
    padding_right = 6,
    background = { height = 54 },
    icon = {
        string = "􀆮",
        color = colors.yellow,
        font = { style = settings.font.style_map["Regular"], size = 34.0 },
        padding_left = 10,
        padding_right = 10,
    },
    label = {
        string = "--°",
        color = colors.white,
        font = text_font("Bold", 34.0),
        padding_left = 0,
    },
})

local popup_condition = sbar.add("item", "widgets.weather.popup.condition", {
    position = popup_pos,
    width = POPUP_W,
    padding_left = 6,
    padding_right = 6,
    background = { height = 20 },
    icon = {
        string = "--",
        color = colors.white,
        font = text_font("Semibold", 14.0),
        width = POPUP_W - 100,
        align = "left",
        padding_left = 10,
    },
    label = {
        string = "",
        color = dim,
        font = num_font("Semibold", 12.0),
        width = 100 - 12,
        align = "right",
        padding_right = 10,
    },
})

local popup_place = sbar.add("item", "widgets.weather.popup.place", {
    position = popup_pos,
    width = POPUP_W,
    padding_left = 6,
    padding_right = 6,
    background = { height = 20 },
    icon = {
        string = "--",
        color = dim,
        font = text_font("Regular", 12.0),
        width = POPUP_W - 70,
        align = "left",
        padding_left = 10,
    },
    label = {
        string = "",
        font = text_font("Bold", 9.0),
        width = 70 - 12,
        align = "right",
        padding_right = 10,
    },
})

sbar.add("item", "widgets.weather.popup.divider", {
    position = popup_pos,
    width = POPUP_W,
    padding_left = 16,
    padding_right = 16,
    icon = { drawing = false },
    label = { drawing = false },
    background = {
        height = 1,
        color = colors.with_alpha(colors.white, 0.12),
        y_offset = -2,
    },
})

local function detail_row(key, title)
    return sbar.add("item", "widgets.weather.popup." .. key, {
        position = popup_pos,
        width = POPUP_W,
        padding_left = 6,
        padding_right = 6,
        background = { height = 22 },
        icon = {
            string = title,
            color = dim,
            font = text_font("Regular", 12.0),
            width = POPUP_W / 2,
            align = "left",
            padding_left = 10,
        },
        label = {
            string = "--",
            color = colors.white,
            font = num_font("Semibold", 12.0),
            width = POPUP_W / 2 - 12,
            align = "right",
            padding_right = 10,
        },
    })
end

local popup_feels_like = detail_row("feels", "Feels like")
local popup_humidity = detail_row("humidity", "Humidity")
local popup_rain = detail_row("rain", "Chance of rain")
local popup_wind = detail_row("wind", "Wind")
local popup_pm25 = detail_row("pm25", "PM2.5")
popup_pm25:set({ icon = { width = 60 }, label = { width = POPUP_W - 60 - 12 } })

local popup_footer = sbar.add("item", "widgets.weather.popup.footer", {
    position = popup_pos,
    width = POPUP_W,
    padding_left = 6,
    padding_right = 6,
    background = { height = 22 },
    icon = {
        string = "",
        color = faint,
        font = text_font("Regular", 10.0),
        width = POPUP_W - 12,
        align = "center",
    },
    label = { drawing = false },
})

local popup_items = {
    popup_header, popup_condition, popup_place, popup_feels_like,
    popup_humidity, popup_rain, popup_wind, popup_pm25, popup_footer,
}

local function temp_color_for(t)
    if t >= 35 then return colors.red
    elseif t >= 28 then return colors.orange
    elseif t >= 20 then return colors.yellow
    elseif t >= 10 then return colors.green
    elseif t >= 0 then return colors.blue
    end
    return colors.magenta
end

local function round(x)
    local n = tonumber(x)
    if not n then return nil end
    return math.floor(n + 0.5)
end

-- US AQI bands (falls back to PM2.5 µg/m³ breakpoints if AQI is missing).
local function aqi_level(aqi, pm)
    local v = aqi
    if not v and pm then
        v = pm <= 9 and 0 or pm <= 35.4 and 51 or pm <= 55.4 and 101
            or pm <= 125.4 and 151 or pm <= 225.4 and 201 or 301
    end
    v = v or 0
    if v <= 50 then return { text = "Good", color = colors.green }
    elseif v <= 100 then return { text = "Moderate", color = colors.yellow }
    elseif v <= 150 then return { text = "Sensitive", color = colors.orange }
    elseif v <= 200 then return { text = "Unhealthy", color = colors.red }
    elseif v <= 300 then return { text = "Very unhealthy", color = colors.magenta }
    end
    return { text = "Hazardous", color = 0xffb0303f }
end

local source_badge = {
    gps = { text = "● GPS", color = colors.green },
    fixed = { text = "● FIXED", color = colors.blue },
    ip = { text = "● IP · APPROX", color = colors.orange },
}

local fetch_weather
local retries = 0

-- A failed fetch (network not back after wake, VPN reconnecting) would
-- otherwise leave N/A up until the next 30-minute refresh.
local function fail()
    weather_temp:set({ label = { string = "N/A" } })
    if retries < 5 then
        retries = retries + 1
        fetch_weather(30 * retries)
    end
end

local function apply_weather(result)
    if not result or result:match("^ERROR") or result:match("^%s*$") then
        fail()
        return
    end

    -- temp|feels|humid|wind|code|place|max|min|rain|source|pm25|aqi
    local f = {}
    for field in (result:gsub("%s+$", "") .. "|"):gmatch("([^|]*)|") do
        f[#f + 1] = field
    end
    local temp, feels, humid, wind, code, place, tmax, tmin, rain, source, pm25, aqi =
        table.unpack(f, 1, 12)

    if not tonumber(temp) then
        fail()
        return
    end
    retries = 0

    local weather_code = tonumber(code) or 0
    local icon = weather_icons[weather_code] or "􀆮"
    local description = weather_descriptions[weather_code] or "Unknown"
    local t = round(temp)
    local color = temp_color_for(t)

    weather_icon:set({ icon = { string = icon, color = color } })
    weather_temp:set({ label = { string = t .. "°", color = color } })

    local hi, lo = round(tmax), round(tmin)
    local badge = source_badge[source] or source_badge.ip
    if place == nil or place == "" then place = "Unknown" end

    popup_header:set({ icon = { string = icon, color = color }, label = { string = t .. "°" } })
    popup_condition:set({
        icon = { string = description },
        label = { string = (hi and lo) and ("H " .. hi .. "°  L " .. lo .. "°") or "" },
    })
    popup_place:set({
        icon = { string = place },
        label = { string = badge.text, color = badge.color },
    })
    popup_feels_like:set({ label = { string = (round(feels) or "--") .. "°" } })
    popup_humidity:set({ label = { string = (humid ~= "" and humid or "--") .. "%" } })
    popup_rain:set({ label = { string = (rain ~= "" and rain or "--") .. "%" } })
    popup_wind:set({ label = { string = (round(wind) or "--") .. " km/h" } })
    local pm = round(pm25)
    if pm then
        local level = aqi_level(tonumber(aqi), tonumber(pm25))
        popup_pm25:set({
            drawing = true,
            label = { string = pm .. " µg/m³ · " .. level.text, color = level.color },
        })
    else
        popup_pm25:set({ drawing = false })
    end
    popup_footer:set({ icon = { string = "Updated " .. os.date("%H:%M") } })
end

function fetch_weather(delay)
    local cmd = "$CONFIG_DIR/plugins/weather.sh"
    if delay then cmd = "sleep " .. delay .. "; " .. cmd end
    sbar.exec(cmd, apply_weather)
end

weather_icon:subscribe({ "routine", "forced" }, function() fetch_weather() end)

-- On wake, delay the fetch so it doesn't pile on with other wake handlers.
weather_icon:subscribe("system_woke", function() fetch_weather(10) end)

fetch_weather()

local card = popup.register(weather_bracket)
popup.click_to_toggle(card, { weather_icon, weather_temp })
-- Clicking the card itself closes it too.
for _, item in ipairs(popup_items) do
    item:subscribe("mouse.clicked", function() popup.hide(card) end)
end

sbar.add("item", "widgets.weather.padding", {
    position = "right",
    width = settings.group_paddings,
})
