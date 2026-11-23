#!/bin/bash
# Prints one line for the weather widget:
#   temp|feels|humidity|wind|code|place|max|min|rain%|source|pm2.5|us_aqi
#
# Location, most accurate first:
#   1. Your Mac's Location Services, via helpers/weather_locator/WeatherLocator.app
#      (build it with helpers/weather_locator/build.sh; allow it under
#      System Settings > Privacy & Security > Location Services).
#   2. A fixed place in ~/.config/sketchybar/weather_location, one line:
#      lat,lon|Place name        e.g.  -6.2088,106.8456|Jakarta
#   3. Your public IP address. Least accurate: behind WARP or another VPN it
#      reports wherever the VPN exits (that is where "Depok" came from).

PATH="/opt/homebrew/bin:/usr/bin:/bin"
CACHE="${TMPDIR:-/tmp}/sketchybar_weather_location"
OVERRIDE="$HOME/.config/sketchybar/weather_location"
LOCATOR="$HOME/.config/sketchybar/helpers/weather_locator/WeatherLocator.app"
FIXFILE="${TMPDIR:-/tmp}/sketchybar_weather_fix"
LAT="" LON="" PLACE="" SOURCE=""

# 1. Location Services. A fix is cached for 30 minutes so the bar doesn't
#    wake the location radios more often than the weather refreshes.
if [ -n "$(find "$CACHE" -mmin -30 2>/dev/null)" ]; then
  IFS='|' read -r LATLON PLACE < "$CACHE"
  LAT=${LATLON%,*} LON=${LATLON#*,} SOURCE="gps"
elif [ -d "$LOCATOR" ]; then
  # Launched with `open` so macOS treats it as its own app with its own
  # Location permission; it writes its answer to $FIXFILE and quits.
  rm -f "$FIXFILE"
  open -g -j "$LOCATOR" --args "$FIXFILE" 2>/dev/null
  for _ in $(seq 1 30); do [ -s "$FIXFILE" ] && break; sleep 0.5; done
  FIX=$(cat "$FIXFILE" 2>/dev/null)
  if [[ "$FIX" =~ ^-?[0-9.]+,-?[0-9.]+\| ]]; then
    IFS='|' read -r LATLON _ACC SUB CITY <<< "$FIX"
    if [ -n "$SUB" ] && [ -n "$CITY" ] && [ "$SUB" != "$CITY" ]; then
      PLACE="$SUB, $CITY"
    else
      PLACE="${CITY:-$SUB}"
    fi
    LAT=${LATLON%,*} LON=${LATLON#*,} SOURCE="gps"
    echo "$LATLON|$PLACE" > "$CACHE"
  fi
fi

# 2. Fixed place.
if [ -z "$LAT" ] && [ -s "$OVERRIDE" ]; then
  IFS='|' read -r LATLON PLACE < "$OVERRIDE"
  LAT=${LATLON%,*} LON=${LATLON#*,} SOURCE="fixed"
fi

# 3. IP address.
if [ -z "$LAT" ]; then
  LOC=$(curl -s --connect-timeout 2 --max-time 3 "https://ipinfo.io/json")
  LATLON=$(jq -r '.loc // empty' <<< "$LOC" 2>/dev/null)
  if [ -n "$LATLON" ]; then
    LAT=${LATLON%,*} LON=${LATLON#*,}
    PLACE=$(jq -r '.city // empty' <<< "$LOC")
    SOURCE="ip"
  fi
fi
if [ -z "$LAT" ]; then
  LOC=$(curl -s --connect-timeout 2 --max-time 3 "http://ip-api.com/json")
  LAT=$(jq -r '.lat // empty' <<< "$LOC" 2>/dev/null)
  LON=$(jq -r '.lon // empty' <<< "$LOC" 2>/dev/null)
  PLACE=$(jq -r '.city // empty' <<< "$LOC" 2>/dev/null)
  SOURCE="ip"
fi

if [ -z "$LAT" ] || [ -z "$LON" ]; then
  echo "ERROR"
  exit 1
fi

WEATHER=$(curl -s --connect-timeout 2 --max-time 4 "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&forecast_days=1&timezone=auto")

LINE=$(jq -r '[.current.temperature_2m, .current.apparent_temperature,
               .current.relative_humidity_2m, .current.wind_speed_10m,
               .current.weather_code, .daily.temperature_2m_max[0],
               .daily.temperature_2m_min[0], .daily.precipitation_probability_max[0]]
              | map(. // "" | tostring) | join("|")' <<< "$WEATHER" 2>/dev/null)

if [ -z "$LINE" ] || [[ "$LINE" == "|"* ]]; then
  echo "ERROR"
  exit 1
fi

IFS='|' read -r TEMP FEELS HUMID WIND CODE MAX MIN RAIN <<< "$LINE"

# Air quality (Open-Meteo / CAMS model, hourly). Optional: blanks if it fails.
AIR=$(curl -s --connect-timeout 2 --max-time 4 "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${LAT}&longitude=${LON}&current=pm2_5,us_aqi")
IFS='|' read -r PM25 AQI <<< "$(jq -r '[.current.pm2_5, .current.us_aqi] | map(. // "" | tostring) | join("|")' <<< "$AIR" 2>/dev/null)"

echo "${TEMP}|${FEELS}|${HUMID}|${WIND}|${CODE}|${PLACE:-Unknown}|${MAX}|${MIN}|${RAIN}|${SOURCE}|${PM25}|${AQI}"
