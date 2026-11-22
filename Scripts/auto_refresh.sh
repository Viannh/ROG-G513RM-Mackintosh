#!/bin/sh
# Auto-switch internal display refresh rate on ASUS ROG Strix G513RM:
#   AC Power      -> 300 Hz
#   Battery Power -> 60 Hz
#
# Usage:
#   sh Scripts/auto_refresh.sh                  # Auto switch based on pmset (cached)
#   sh Scripts/auto_refresh.sh --force          # Auto switch, ignore cache
#   sh Scripts/auto_refresh.sh 60|300           # Manual refresh rate switch
#   sh Scripts/auto_refresh.sh --install-agent  # Install user LaunchAgent (runs every 8s)
set -eu

if [ "${1:-}" = "--install-agent" ]; then
    BIN_DIR="$HOME/.local/bin"
    SCRIPT_DST="$BIN_DIR/auto-refresh-g513rm.sh"
    AGENT_DIR="$HOME/Library/LaunchAgents"
    AGENT_PLIST="$AGENT_DIR/com.rog.g513rm.autorefresh.plist"

    mkdir -p "$BIN_DIR" "$AGENT_DIR"
    cp "$0" "$SCRIPT_DST"
    chmod +x "$SCRIPT_DST"

    cat > "$AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.rog.g513rm.autorefresh</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DST</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>8</integer>
    <key>StandardOutPath</key>
    <string>/tmp/g513rm-autorefresh.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/g513rm-autorefresh.log</string>
</dict>
</plist>
EOF
    launchctl bootout "gui/$(id -u)/com.rog.g513rm.autorefresh" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$AGENT_PLIST"
    echo "[OK] Installed and started LaunchAgent: $AGENT_PLIST"
    exit 0
fi

STATE_FILE="/tmp/g513rm_power_state"
ARG="${1:-auto}"

if [ "$ARG" = "60" ] || [ "$ARG" = "300" ]; then
    TARGET_HZ="$ARG"
    POWER_STATE="MANUAL_$ARG"
else
    PS_OUT="$(pmset -g ps | head -n 1)"
    case "$PS_OUT" in
        *"AC Power"*)
            POWER_STATE="AC"
            TARGET_HZ="300"
            ;;
        *)
            POWER_STATE="BATTERY"
            TARGET_HZ="60"
            ;;
    esac

    if [ "$ARG" != "--force" ] && [ -f "$STATE_FILE" ]; then
        LAST_STATE="$(cat "$STATE_FILE" 2>/dev/null || true)"
        if [ "$LAST_STATE" = "$POWER_STATE" ]; then
            exit 0
        fi
    fi
fi

RESULT=$(/usr/bin/osascript -l JavaScript - "$TARGET_HZ" <<'JXA' 2>&1
ObjC.import("CoreGraphics");
ObjC.import("Foundation");

function run(argv) {
  var target = parseFloat(argv[0]);
  var did = $.CGMainDisplayID();
  var cur = $.CGDisplayCopyDisplayMode(did);
  if (!cur) return "ERROR: no current display mode";
  var curW = $.CGDisplayModeGetWidth(cur);
  var curH = $.CGDisplayModeGetHeight(cur);
  var curR = $.CGDisplayModeGetRefreshRate(cur);

  if (Math.abs(curR - target) < 1.0) {
    return "OK: already " + curW + "x" + curH + "@" + curR.toFixed(2) + "Hz";
  }

  var modes = $.CGDisplayCopyAllDisplayModes(did, $());
  if (!modes) return "ERROR: could not list modes";
  var arr = ObjC.castRefToObject(modes);
  var best = null;
  var fallback = null;

  for (var i = 0; i < arr.count; i++) {
    var m = arr.objectAtIndex(i);
    if (!$.CGDisplayModeIsUsableForDesktopGUI(m)) continue;
    var w = $.CGDisplayModeGetWidth(m);
    var h = $.CGDisplayModeGetHeight(m);
    var r = $.CGDisplayModeGetRefreshRate(m);
    if (w === curW && h === curH && Math.abs(r - target) < 1.0) {
      var flags = $.CGDisplayModeGetIOFlags(m);
      if ((flags & 0x2000000) !== 0) {
        best = m;
        break;
      }
      if (!fallback) fallback = m;
    }
  }

  var chosen = best || fallback;
  if (!chosen) return "ERROR: mode " + curW + "x" + curH + "@" + target + "Hz not found";

  var err = $.CGDisplaySetDisplayMode(did, chosen, $());
  if (err !== 0) return "ERROR: CGDisplaySetDisplayMode returned " + err;

  var after = $.CGDisplayCopyDisplayMode(did);
  return "SWITCHED: " + curW + "x" + curH + " " + curR.toFixed(2) + "Hz -> " + $.CGDisplayModeGetRefreshRate(after).toFixed(2) + "Hz";
}
JXA
)

echo "$RESULT"
case "$RESULT" in
    OK:*|SWITCHED:*)
        if [ "$ARG" != "60" ] && [ "$ARG" != "300" ]; then
            printf '%s\n' "$POWER_STATE" > "$STATE_FILE"
        fi
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
