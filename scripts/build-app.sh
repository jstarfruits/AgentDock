#!/bin/sh
# Agent Dock を .app バンドルとしてビルドする。
# バンドル化により UNUserNotificationCenter(クリックでアプリが前面化する通知)が
# 使えるようになり、アクセシビリティ権限の対象も安定する。
set -eu
cd "$(dirname "$0")/.."

swift build -c release

APP="build/AgentDock.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/AgentDock "$APP/Contents/MacOS/AgentDock"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# SwiftPM resource bundle (localized strings) — Bundle.module looks for it
# inside Contents/Resources of the app bundle
cp -R .build/release/AgentDock_AgentDock.bundle "$APP/Contents/Resources/"

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
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleLocalizations</key>
	<array>
		<string>en</string>
		<string>ja</string>
	</array>
	<key>CFBundleAllowMixedLocalizations</key>
	<true/>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
EOF

codesign --force -s - "$APP"

echo "built: $APP"

# --install で /Applications へ配置(起動中なら終了してから差し替える)
if [ "${1:-}" = "--install" ]; then
    pkill -x AgentDock 2>/dev/null || true
    sleep 1
    rm -rf /Applications/AgentDock.app
    cp -R "$APP" /Applications/AgentDock.app
    echo "installed: /Applications/AgentDock.app"
    open /Applications/AgentDock.app
else
    echo "起動: open $APP"
    echo "インストール: $0 --install"
fi
