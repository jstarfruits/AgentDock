#!/bin/sh
# Agent Dock を .app バンドルとしてビルドする。
# バンドル化により UNUserNotificationCenter(クリックでアプリが前面化する通知)が
# 使えるようになり、アクセシビリティ権限の対象も安定する。
set -eu
cd "$(dirname "$0")/.."

swift build -c release

APP="build/AgentDock.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/AgentDock "$APP/Contents/MacOS/AgentDock"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>AgentDock</string>
	<key>CFBundleDisplayName</key>
	<string>Agent Dock</string>
	<key>CFBundleIdentifier</key>
	<string>com.agentdock.AgentDock</string>
	<key>CFBundleExecutable</key>
	<string>AgentDock</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
EOF

codesign --force -s - "$APP"

echo "built: $APP"
echo "起動: open $APP"
