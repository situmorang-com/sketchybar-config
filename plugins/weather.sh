#!/bin/bash

# Fetch location from IP
CITY="Unknown"
LOC=$(/usr/bin/curl -s --connect-timeout 2 --max-time 3 "https://ipinfo.io/json" 2>/dev/null)

if echo "$LOC" | /usr/bin/grep -q '"loc"'; then
  LATLON=$(echo "$LOC" | /usr/bin/sed -n 's/.*"loc": *"\([^"]*\)".*/\1/p')
  LAT=$(echo "$LATLON" | /usr/bin/cut -d, -f1)
  LON=$(echo "$LATLON" | /usr/bin/cut -d, -f2)
  CITY=$(echo "$LOC" | /usr/bin/sed -n 's/.*"city": *"\([^"]*\)".*/\1/p')
fi

# Fallback to ip-api.com
if [ -z "$LAT" ] || [ -z "$LON" ]; then
  LOC=$(/usr/bin/curl -s --connect-timeout 2 --max-time 3 "http://ip-api.com/json" 2>/dev/null)
  LAT=$(echo "$LOC" | /usr/bin/sed -n 's/.*"lat": *\([0-9.e\-]*\).*/\1/p')
  LON=$(echo "$LOC" | /usr/bin/sed -n 's/.*"lon": *\([0-9.e\-]*\).*/\1/p')
  CITY=$(echo "$LOC" | /usr/bin/sed -n 's/.*"city": *"\([^"]*\)".*/\1/p')
fi

if [ -z "$LAT" ] || [ -z "$LON" ]; then
  echo "ERROR"
  exit 1
fi

# Fetch weather from Open-Meteo
WEATHER=$(/usr/bin/curl -s --connect-timeout 2 --max-time 3 "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&temperature_unit=celsius" 2>/dev/null)

if [ -z "$WEATHER" ]; then
  echo "ERROR"
  exit 1
fi

TEMP=$(echo "$WEATHER" | /usr/bin/sed -n 's/.*"temperature_2m": *\([0-9.\-]*\).*/\1/p')
FEELS=$(echo "$WEATHER" | /usr/bin/sed -n 's/.*"apparent_temperature": *\([0-9.\-]*\).*/\1/p')
HUMID=$(echo "$WEATHER" | /usr/bin/sed -n 's/.*"relative_humidity_2m": *\([0-9]*\).*/\1/p')
WIND=$(echo "$WEATHER" | /usr/bin/sed -n 's/.*"wind_speed_10m": *\([0-9.\-]*\).*/\1/p')
CODE=$(echo "$WEATHER" | /usr/bin/sed -n 's/.*"weather_code": *\([0-9]*\).*/\1/p')

echo "${TEMP}|${FEELS}|${HUMID}|${WIND}|${CODE}|${CITY}"
