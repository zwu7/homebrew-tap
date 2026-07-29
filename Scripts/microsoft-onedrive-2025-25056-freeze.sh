#!/bin/bash
set -Eeuo pipefail
EXPECTED_SHORT_VERSION="25.056.0324"
BEGIN_MARKER="# BEGIN MICROSOFT ONEDRIVE 25.056 HARD FREEZE"
END_MARKER="# END MICROSOFT ONEDRIVE 25.056 HARD FREEZE"
HOST="oneclient.sfx.ms"
APP="/Applications/OneDrive.app"
UID_VALUE="$(id -u)"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
[ -f "$APP/Contents/Info.plist" ] || { echo "ERROR: OneDrive.app is missing." >&2; exit 1; }
ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || true)"
[ "$ACTUAL_VERSION" = "$EXPECTED_SHORT_VERSION" ] || { echo "ERROR: Expected $EXPECTED_SHORT_VERSION, found ${ACTUAL_VERSION:-unknown}." >&2; exit 1; }
/usr/bin/osascript -e 'tell application id "com.microsoft.OneDrive" to quit' >/dev/null 2>&1 || true
/usr/bin/pkill -f 'OneDriveStandaloneUpdater|OneDriveUpdater' >/dev/null 2>&1 || true
/bin/launchctl disable "gui/${UID_VALUE}/com.microsoft.OneDriveStandaloneUpdater" >/dev/null 2>&1 || true
/usr/bin/sudo /bin/launchctl disable "system/com.microsoft.OneDriveStandaloneUpdaterDaemon" >/dev/null 2>&1 || true
/usr/bin/sudo /bin/launchctl disable "system/com.microsoft.OneDriveUpdaterDaemon" >/dev/null 2>&1 || true
TMP_HOSTS="$(mktemp "${TMPDIR:-/tmp}/hosts.onedrive.XXXXXX")"
/usr/bin/awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '$0 == begin { skipping=1; next } $0 == end { skipping=0; next } !skipping { print }' /etc/hosts > "$TMP_HOSTS"
{
  printf '\n%s\n' "$BEGIN_MARKER"
  printf '0.0.0.0 %s\n' "$HOST"
  printf '::1 %s\n' "$HOST"
  printf '%s\n' "$END_MARKER"
} >> "$TMP_HOSTS"
/usr/bin/sudo /bin/cp /etc/hosts "/etc/hosts.onedrive-25-056-before-freeze-${TIMESTAMP}.bak"
/usr/bin/sudo /usr/bin/install -o root -g wheel -m 644 "$TMP_HOSTS" /etc/hosts
rm -f "$TMP_HOSTS"
/usr/bin/sudo /usr/bin/dscacheutil -flushcache >/dev/null 2>&1 || true
/usr/bin/sudo /usr/bin/killall -HUP mDNSResponder >/dev/null 2>&1 || true
printf 'OneDrive 25.056 hard freeze is active.\n'
