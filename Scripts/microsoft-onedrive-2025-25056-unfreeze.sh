#!/bin/bash
set -Eeuo pipefail
BEGIN_MARKER="# BEGIN MICROSOFT ONEDRIVE 25.056 HARD FREEZE"
END_MARKER="# END MICROSOFT ONEDRIVE 25.056 HARD FREEZE"
UID_VALUE="$(id -u)"
/usr/bin/osascript -e 'tell application id "com.microsoft.OneDrive" to quit' >/dev/null 2>&1 || true
TMP_HOSTS="$(mktemp "${TMPDIR:-/tmp}/hosts.onedrive.XXXXXX")"
/usr/bin/awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '$0 == begin { skipping=1; next } $0 == end { skipping=0; next } !skipping { print }' /etc/hosts > "$TMP_HOSTS"
/usr/bin/sudo /usr/bin/install -o root -g wheel -m 644 "$TMP_HOSTS" /etc/hosts
rm -f "$TMP_HOSTS"
LATEST_BACKUP="$(find "/Library/Application Support/OneDriveFreeze" -maxdepth 1 -type d -name '25.056_*' -print 2>/dev/null | sort | tail -n 1)"
if [ -n "$LATEST_BACKUP" ]; then
  if [ -f "$LATEST_BACKUP/com.microsoft.OneDriveStandaloneUpdater.plist" ]; then
    /usr/bin/sudo /bin/mv "$LATEST_BACKUP/com.microsoft.OneDriveStandaloneUpdater.plist" /Library/LaunchAgents/
  fi
  if [ -f "$LATEST_BACKUP/com.microsoft.OneDriveStandaloneUpdaterDaemon.plist" ]; then
    /usr/bin/sudo /bin/mv "$LATEST_BACKUP/com.microsoft.OneDriveStandaloneUpdaterDaemon.plist" /Library/LaunchDaemons/
  fi
  if [ -f "$LATEST_BACKUP/com.microsoft.OneDriveUpdaterDaemon.plist" ]; then
    /usr/bin/sudo /bin/mv "$LATEST_BACKUP/com.microsoft.OneDriveUpdaterDaemon.plist" /Library/LaunchDaemons/
  fi
fi
/bin/launchctl enable "gui/${UID_VALUE}/com.microsoft.OneDriveStandaloneUpdater" >/dev/null 2>&1 || true
/usr/bin/sudo /bin/launchctl enable "system/com.microsoft.OneDriveStandaloneUpdaterDaemon" >/dev/null 2>&1 || true
/usr/bin/sudo /bin/launchctl enable "system/com.microsoft.OneDriveUpdaterDaemon" >/dev/null 2>&1 || true
if [ -f /Library/LaunchAgents/com.microsoft.OneDriveStandaloneUpdater.plist ]; then
  /bin/launchctl bootstrap "gui/${UID_VALUE}" /Library/LaunchAgents/com.microsoft.OneDriveStandaloneUpdater.plist >/dev/null 2>&1 || true
fi
if [ -f /Library/LaunchDaemons/com.microsoft.OneDriveStandaloneUpdaterDaemon.plist ]; then
  /usr/bin/sudo /bin/launchctl bootstrap system /Library/LaunchDaemons/com.microsoft.OneDriveStandaloneUpdaterDaemon.plist >/dev/null 2>&1 || true
fi
if [ -f /Library/LaunchDaemons/com.microsoft.OneDriveUpdaterDaemon.plist ]; then
  /usr/bin/sudo /bin/launchctl bootstrap system /Library/LaunchDaemons/com.microsoft.OneDriveUpdaterDaemon.plist >/dev/null 2>&1 || true
fi
/usr/bin/sudo /usr/bin/dscacheutil -flushcache >/dev/null 2>&1 || true
/usr/bin/sudo /usr/bin/killall -HUP mDNSResponder >/dev/null 2>&1 || true
printf 'OneDrive update-host block was removed and updater launch services were restored when backups were available.\n'
