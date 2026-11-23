#!/bin/bash
# Builds WeatherLocator.app next to this script, signed with the same local
# certificate as sketchybar so the Location permission survives rebuilds.
set -euo pipefail
cd "$(dirname "$0")"
APP=WeatherLocator.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
swiftc -O main.swift -o "$APP/Contents/MacOS/WeatherLocator"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.sketchybar.weatherlocator</string>
  <key>CFBundleName</key><string>WeatherLocator</string>
  <key>CFBundleExecutable</key><string>WeatherLocator</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>NSLocationUsageDescription</key><string>Shows the weather for where you are in SketchyBar.</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>Shows the weather for where you are in SketchyBar.</string>
</dict></plist>
PLIST
codesign --force --sign "sketchybar-local" "$APP"
echo "built $PWD/$APP"
