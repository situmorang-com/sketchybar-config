local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

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

-- Popup items for weather details
local popup_location = sbar.add("item", {
    position = "popup." .. weather_bracket.name,
    icon = {
        string = "Location:",
        width = 80,
        align = "left",
    },
    label = {
        string = "--",
        width = 120,
        align = "right",
    },
})

local popup_condition = sbar.add("item", {
    position = "popup." .. weather_bracket.name,
    icon = {
        string = "Condition:",
        width = 80,
        align = "left",
    },
    label = {
        string = "--",
        width = 120,
        align = "right",
    },
})

local popup_feels_like = sbar.add("item", {
    position = "popup." .. weather_bracket.name,
    icon = {
        string = "Feels like:",
        width = 80,
        align = "left",
    },
    label = {
        string = "--°",
        width = 120,
        align = "right",
    },
})

local popup_humidity = sbar.add("item", {
    position = "popup." .. weather_bracket.name,
    icon = {
        string = "Humidity:",
        width = 80,
        align = "left",
    },
    label = {
        string = "--%",
        width = 120,
        align = "right",
    },
})

local popup_wind = sbar.add("item", {
    position = "popup." .. weather_bracket.name,
    icon = {
        string = "Wind:",
        width = 80,
        align = "left",
    },
    label = {
        string = "-- km/h",
        width = 120,
        align = "right",
    },
})

local function fetch_weather()
    sbar.exec("$CONFIG_DIR/plugins/weather.sh", function(result)
        if not result or result:match("^ERROR") or result:match("^%s*$") then
            weather_temp:set({ label = { string = "N/A" } })
            return
        end

        -- Parse pipe-delimited result: temp|feels|humid|wind|code|city
        local temp, feels_like, humidity, wind, code, city = result:match("([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")

        if not temp or temp == "" then
            weather_temp:set({ label = { string = "N/A" } })
            return
        end

        local weather_code = tonumber(code) or 0
        local icon = weather_icons[weather_code] or "􀆮"
        local description = weather_descriptions[weather_code] or "Unknown"

        -- Color temperature based on value
        local temp_num = tonumber(temp) or 0
        local temp_color = colors.white
        if temp_num >= 35 then
            temp_color = colors.red
        elseif temp_num >= 28 then
            temp_color = colors.orange
        elseif temp_num >= 20 then
            temp_color = colors.yellow
        elseif temp_num >= 10 then
            temp_color = colors.green
        elseif temp_num >= 0 then
            temp_color = colors.blue
        else
            temp_color = colors.magenta
        end

        -- Round temperature
        local temp_rounded = math.floor(tonumber(temp) + 0.5)

        weather_icon:set({
            icon = { string = icon, color = temp_color },
        })
        weather_temp:set({
            label = { string = temp_rounded .. "°", color = temp_color },
        })

        -- Update popup details
        local city_name = city and city:match("^%s*(.-)%s*$") or "Unknown"
        if city_name == "" then city_name = "Unknown" end
        popup_location:set({ label = { string = city_name } })
        popup_condition:set({ label = { string = description } })
        popup_feels_like:set({ label = { string = math.floor(tonumber(feels_like or 0) + 0.5) .. "°C" } })
        popup_humidity:set({ label = { string = (humidity or "--") .. "%" } })
        popup_wind:set({ label = { string = (wind or "--") .. " km/h" } })
    end)
end

weather_icon:subscribe("routine", function()
    fetch_weather()
end)

-- On wake, delay the fetch so it doesn't pile on with other wake handlers
weather_icon:subscribe("system_woke", function()
    sbar.exec("(sleep 10 && $CONFIG_DIR/plugins/weather.sh) &", function(result)
        if result and not result:match("^ERROR") and not result:match("^%s*$") then
            -- Re-parse and update (same logic as fetch_weather callback)
            local temp, feels_like, humidity, wind, code, city = result:match("([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
            if temp and temp ~= "" then
                local weather_code = tonumber(code) or 0
                local icon = weather_icons[weather_code] or "􀆮"
                local description = weather_descriptions[weather_code] or "Unknown"
                local temp_num = tonumber(temp) or 0
                local temp_color = colors.white
                if temp_num >= 35 then temp_color = colors.red
                elseif temp_num >= 28 then temp_color = colors.orange
                elseif temp_num >= 20 then temp_color = colors.yellow
                elseif temp_num >= 10 then temp_color = colors.green
                elseif temp_num >= 0 then temp_color = colors.blue
                else temp_color = colors.magenta end
                local temp_rounded = math.floor(tonumber(temp) + 0.5)
                weather_icon:set({ icon = { string = icon, color = temp_color } })
                weather_temp:set({ label = { string = temp_rounded .. "°", color = temp_color } })
                local city_name = city and city:match("^%s*(.-)%s*$") or "Unknown"
                if city_name == "" then city_name = "Unknown" end
                popup_location:set({ label = { string = city_name } })
                popup_condition:set({ label = { string = description } })
                popup_feels_like:set({ label = { string = math.floor(tonumber(feels_like or 0) + 0.5) .. "°C" } })
                popup_humidity:set({ label = { string = (humidity or "--") .. "%" } })
                popup_wind:set({ label = { string = (wind or "--") .. " km/h" } })
            end
        end
    end)
end)

-- Also fetch on first load
fetch_weather()

weather_icon:subscribe("mouse.clicked", function()
    weather_bracket:set({ popup = { drawing = "toggle" } })
end)

weather_temp:subscribe("mouse.clicked", function()
    weather_bracket:set({ popup = { drawing = "toggle" } })
end)

sbar.add("item", "widgets.weather.padding", {
    position = "right",
    width = settings.group_paddings,
})
