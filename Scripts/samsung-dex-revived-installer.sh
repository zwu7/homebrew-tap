#!/bin/bash
set -euo pipefail

EXPECTED_VERSION="2.4.0.21"
EXPECTED_ORIGINAL_BIN_SHA256="63bcf82496f2bce5e527160439d2d2fc4610102cfcb9404a5de59c4d45343d98"
EXPECTED_ORIGINAL_PLIST_SHA256="ded1a223b33714da3ad730175db1542ff9e11b666da5b2a1d821060a2f5a7fc7"
EXPECTED_TEAM_IDENTIFIER="8S33FS7Q5Q"
OUTER_BUNDLE_ID="com.zwu7.SamsungDeXRevived"
SERVICE_LABEL="system/com.devguru.ssconnservice2"
SERVICE_PLIST="/Library/LaunchDaemons/com.devguru.ssconnservice2.plist"
DEFAULT_ORIGINAL_APP="/Applications/Samsung DeX.app"
DEFAULT_TARGET_APP="/Applications/Samsung DeX Revived.app"
ORIGINAL_APP="$DEFAULT_ORIGINAL_APP"
TARGET_APP="$DEFAULT_TARGET_APP"
MODE="install"
LAUNCH_AFTER_INSTALL="no"

usage() {
  cat <<'USAGE'
Usage:
  samsung-dex-revived-installer.sh [install|verify|launch|repair-service|remove|assert-phone-disconnected] [options]

Options:
  --original-app PATH   Source Samsung DeX.app path
  --target-app PATH     Revived launcher application path
  --launch              Launch after install
  --no-launch           Do not launch after install (default)
  -h, --help            Show this help
USAGE
}

fail() {
  printf 'RESULT: FAIL\n%s\n' "$1" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    install|verify|launch|repair-service|remove|assert-phone-disconnected)
      MODE="$1"
      shift
      ;;
    --original-app)
      [[ $# -ge 2 ]] || fail "--original-app requires a path"
      ORIGINAL_APP="$2"
      shift 2
      ;;
    --target-app)
      [[ $# -ge 2 ]] || fail "--target-app requires a path"
      TARGET_APP="$2"
      shift 2
      ;;
    --launch)
      LAUNCH_AFTER_INSTALL="yes"
      shift
      ;;
    --no-launch)
      LAUNCH_AFTER_INSTALL="no"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

ORIGINAL_BIN="$ORIGINAL_APP/Contents/MacOS/Samsung DeX"
ORIGINAL_PLIST="$ORIGINAL_APP/Contents/Info.plist"
OUTER_BIN="$TARGET_APP/Contents/MacOS/Samsung DeX Revived"
RUNTIME_APP="$TARGET_APP/Contents/Resources/Samsung DeX Runtime.app"
RUNTIME_BIN="$RUNTIME_APP/Contents/MacOS/Samsung DeX"
REAL_BIN="$RUNTIME_APP/Contents/MacOS/Samsung DeX.real"
SHIM_DYLIB="$RUNTIME_APP/Contents/Frameworks/libDexSinkTypeWindowsShim.dylib"
LOG_DIR="$HOME/Library/Logs/Samsung DeX Revived"
MARKER="$LOG_DIR/shim_runtime_probe.txt"
APP_LOG="$LOG_DIR/app_stdout_stderr.log"
LAUNCHER_LOG="$LOG_DIR/launcher.log"

run_as_root() {
  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  else
    /usr/bin/sudo "$@"
  fi
}

samsung_usb_connected() {
  local usb_tree
  usb_tree="$(/usr/sbin/ioreg -p IOUSB -l -w 0 2>/dev/null || true)"

  # Samsung Electronics USB vendor ID: 0x04e8 (decimal 1256).
  if /usr/bin/grep -Eq '"idVendor"[[:space:]]*=[[:space:]]*(1256|0x0*4e8)' <<<"$usb_tree"; then
    return 0
  fi

  # Fallback for ioreg variants that expose the vendor as text only.
  if /usr/bin/grep -Eqi 'Samsung|0x04e8' <<<"$usb_tree"; then
    return 0
  fi

  return 1
}

assert_phone_disconnected() {
  if samsung_usb_connected; then
    cat >&2 <<'MSG'
RESULT: PHONE_CONNECTED
Disconnect the Samsung phone before installing, reinstalling, or uninstalling
Samsung DeX Revived. This check runs before Homebrew removes the existing cask,
so the current working installation is left unchanged. Reconnect the phone only
after Homebrew reports that installation has completed.
MSG
    exit 1
  fi

  printf 'RESULT: PHONE_DISCONNECTED
'
}

stop_dex_ui() {
  /usr/bin/osascript -e 'tell application id "com.samsung.DeXonPC" to quit' >/dev/null 2>&1 || true
  /usr/bin/osascript -e 'tell application id "com.zwu7.SamsungDeXRevived" to quit' >/dev/null 2>&1 || true
  /usr/bin/pkill -x "Samsung DeX" >/dev/null 2>&1 || true
  /usr/bin/pkill -f '/Applications/Samsung DeX.app/Contents/MacOS/Samsung DeX' >/dev/null 2>&1 || true
  /usr/bin/pkill -f '/Applications/Samsung DeX Revived.app/Contents/Resources/Samsung DeX Runtime.app/Contents/MacOS/Samsung DeX.real' >/dev/null 2>&1 || true
  sleep 1
}

check_rosetta() {
  if /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    return 0
  fi

  printf '%s\n' 'Rosetta 2 is not installed. Installing it through Apple softwareupdate...'
  run_as_root /usr/sbin/softwareupdate --install-rosetta --agree-to-license || \
    fail "Rosetta 2 installation failed."

  /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1 || \
    fail "Rosetta 2 is still unavailable after softwareupdate completed."
}

restart_connectivity_service() {
  [[ -f "$SERVICE_PLIST" ]] || fail "Samsung connectivity LaunchDaemon plist is missing: $SERVICE_PLIST"

  if ! run_as_root /bin/launchctl print "$SERVICE_LABEL" >/dev/null 2>&1; then
    run_as_root /bin/launchctl bootstrap system "$SERVICE_PLIST" >/dev/null 2>&1 || true
  fi

  run_as_root /bin/launchctl kickstart -k "$SERVICE_LABEL" || \
    fail "Unable to restart Samsung connectivity service."
  sleep 2

  run_as_root /bin/launchctl print "$SERVICE_LABEL" >/dev/null 2>&1 || \
    fail "Samsung connectivity service is not registered after restart."

  printf 'SERVICE: com.devguru.ssconnservice2 running\n'
}

verify_target() {
  [[ -d "$TARGET_APP" ]] || fail "Target app is not installed: $TARGET_APP"
  [[ -x "$OUTER_BIN" ]] || fail "Outer launcher is missing: $OUTER_BIN"
  [[ -d "$RUNTIME_APP" ]] || fail "Embedded DeX runtime is missing: $RUNTIME_APP"
  [[ -x "$RUNTIME_BIN" ]] || fail "Runtime launcher is missing: $RUNTIME_BIN"
  [[ -x "$REAL_BIN" ]] || fail "Real DeX binary is missing: $REAL_BIN"
  [[ -f "$SHIM_DYLIB" ]] || fail "SinkType shim is missing: $SHIM_DYLIB"

  local outer_id outer_version runtime_version
  outer_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$TARGET_APP/Contents/Info.plist")"
  outer_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$TARGET_APP/Contents/Info.plist")"
  runtime_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$RUNTIME_APP/Contents/Info.plist")"

  [[ "$outer_id" == "$OUTER_BUNDLE_ID" ]] || fail "Unexpected launcher bundle identifier: $outer_id"
  [[ "$outer_version" == "$EXPECTED_VERSION" ]] || fail "Unexpected launcher version: $outer_version"
  [[ "$runtime_version" == "$EXPECTED_VERSION" ]] || fail "Unexpected runtime version: $runtime_version"

  /usr/bin/file "$REAL_BIN" | /usr/bin/grep -q 'x86_64' || fail "Real DeX binary is not x86_64"
  /usr/bin/file "$SHIM_DYLIB" | /usr/bin/grep -q 'x86_64' || fail "SinkType shim is not x86_64"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$TARGET_APP"

  printf 'RESULT: VERIFY_OK\nAPP: %s\nBUNDLE_ID: %s\nVERSION: %s\n' \
    "$TARGET_APP" "$outer_id" "$outer_version"
}

launch_target() {
  verify_target >/dev/null
  check_rosetta
  stop_dex_ui
  restart_connectivity_service
  /bin/mkdir -p "$LOG_DIR"
  /bin/rm -f "$MARKER"

  # The outer app has a unique bundle identifier. Its launcher executes the
  # embedded Samsung runtime directly, avoiding LaunchServices selection of
  # the original com.samsung.DeXonPC application.
  /usr/bin/open -n "$TARGET_APP"

  for _ in $(/usr/bin/seq 1 200); do
    if [[ -f "$MARKER" ]] && /usr/bin/grep -Fqx 'HOOK_INSTALLED=yes' "$MARKER"; then
      printf 'RESULT: LAUNCH_OK\nAPP: %s\nHOOK: SinkType MAC -> Windows\nMARKER: %s\n' \
        "$TARGET_APP" "$MARKER"
      return 0
    fi
    sleep 0.1
  done

  printf 'RESULT: LAUNCHED_BUT_HOOK_NOT_VERIFIED\nAPP: %s\nMARKER: %s\nLOG: %s\nLAUNCHER_LOG: %s\n' \
    "$TARGET_APP" "$MARKER" "$APP_LOG" "$LAUNCHER_LOG"
  return 1
}

case "$MODE" in
  assert-phone-disconnected)
    assert_phone_disconnected
    exit 0
    ;;
  remove)
    stop_dex_ui
    /bin/rm -rf "$TARGET_APP"
    printf 'RESULT: REMOVED\nAPP: %s\n' "$TARGET_APP"
    exit 0
    ;;
  verify)
    verify_target
    exit 0
    ;;
  launch)
    launch_target
    exit 0
    ;;
  repair-service)
    restart_connectivity_service
    printf 'RESULT: SERVICE_REPAIRED\n'
    exit 0
    ;;
  install)
    ;;
  *)
    fail "Unsupported mode: $MODE"
    ;;
esac

[[ "$(/usr/bin/uname -m)" == "arm64" ]] || fail "This revival package supports Apple silicon Macs only."
[[ -x "$ORIGINAL_BIN" ]] || fail "Original Samsung DeX app not found at $ORIGINAL_APP"
[[ -f "$ORIGINAL_PLIST" ]] || fail "Original Samsung DeX Info.plist not found."

for cmd in clang lipo codesign ditto file shasum; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing required command: $cmd"
done
check_rosetta

ORIGINAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ORIGINAL_PLIST")"
[[ "$ORIGINAL_VERSION" == "$EXPECTED_VERSION" ]] || \
  fail "Expected Samsung DeX $EXPECTED_VERSION, found $ORIGINAL_VERSION"

ORIGINAL_BIN_SHA256="$(/usr/bin/shasum -a 256 "$ORIGINAL_BIN" | /usr/bin/awk '{print $1}')"
[[ "$ORIGINAL_BIN_SHA256" == "$EXPECTED_ORIGINAL_BIN_SHA256" ]] || \
  fail "Original Samsung DeX binary hash mismatch: $ORIGINAL_BIN_SHA256"

ORIGINAL_PLIST_SHA256="$(/usr/bin/shasum -a 256 "$ORIGINAL_PLIST" | /usr/bin/awk '{print $1}')"
[[ "$ORIGINAL_PLIST_SHA256" == "$EXPECTED_ORIGINAL_PLIST_SHA256" ]] || \
  fail "Original Samsung DeX Info.plist hash mismatch: $ORIGINAL_PLIST_SHA256"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$ORIGINAL_APP" || \
  fail "Original Samsung DeX code signature verification failed."

TEAM_IDENTIFIER="$(/usr/bin/codesign -dv --verbose=4 "$ORIGINAL_APP" 2>&1 | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}')"
[[ "$TEAM_IDENTIFIER" == "$EXPECTED_TEAM_IDENTIFIER" ]] || \
  fail "Unexpected Samsung DeX TeamIdentifier: ${TEAM_IDENTIFIER:-missing}"

/usr/bin/file "$ORIGINAL_BIN" | /usr/bin/grep -q 'x86_64' || \
  fail "Original DeX binary does not contain x86_64 code."

TARGET_PARENT="$(/usr/bin/dirname "$TARGET_APP")"
/bin/mkdir -p "$TARGET_PARENT" "$LOG_DIR"
[[ -w "$TARGET_PARENT" ]] || fail "Target directory is not writable: $TARGET_PARENT"

STAGE="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/samsung-dex-revived.XXXXXX")"
BACKUP="${TARGET_APP}.previous.$$"
INSTALLED_NEW_TARGET="no"

cleanup() {
  /bin/rm -rf "$STAGE"
  if [[ "$INSTALLED_NEW_TARGET" != "yes" && -d "$BACKUP" && ! -e "$TARGET_APP" ]]; then
    /bin/mv "$BACKUP" "$TARGET_APP" || true
  fi
}
trap cleanup EXIT INT TERM

stop_dex_ui
/bin/rm -rf "$BACKUP"

STAGE_APP="$STAGE/Samsung DeX Revived.app"
STAGE_CONTENTS="$STAGE_APP/Contents"
STAGE_OUTER_BIN="$STAGE_CONTENTS/MacOS/Samsung DeX Revived"
STAGE_RUNTIME_APP="$STAGE_CONTENTS/Resources/Samsung DeX Runtime.app"
STAGE_RUNTIME_BIN="$STAGE_RUNTIME_APP/Contents/MacOS/Samsung DeX"
STAGE_REAL="$STAGE_RUNTIME_APP/Contents/MacOS/Samsung DeX.real"
STAGE_SHIM="$STAGE_RUNTIME_APP/Contents/Frameworks/libDexSinkTypeWindowsShim.dylib"
SHIM_SRC="$STAGE_RUNTIME_APP/Contents/Resources/dex_sinktype_windows_shim.m"
REVIVAL_INFO="$STAGE_CONTENTS/Resources/REVIVAL_INFO.txt"

/bin/mkdir -p "$STAGE_CONTENTS/MacOS" "$STAGE_CONTENTS/Resources"
/usr/bin/ditto "$ORIGINAL_APP" "$STAGE_RUNTIME_APP"

/usr/bin/lipo "$STAGE_RUNTIME_BIN" -thin x86_64 -output "$STAGE_REAL"
/bin/chmod 755 "$STAGE_REAL"
/bin/rm -f "$STAGE_RUNTIME_BIN"

cat > "$SHIM_SRC" <<'SHIM'
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void (*dex_original_set_sink_type)(id, SEL, id) = NULL;
static pthread_mutex_t dex_hook_lock = PTHREAD_MUTEX_INITIALIZER;
static int dex_hook_installed = 0;
static const char *dex_marker_path = NULL;

static const char *dex_utf8(id value) {
  if (value == nil) return "(nil)";
  if ([value respondsToSelector:@selector(UTF8String)]) {
    const char *text = [value UTF8String];
    return text != NULL ? text : "";
  }
  return [[value description] UTF8String];
}

static void dex_marker_append(const char *format, ...) {
  if (dex_marker_path == NULL || dex_marker_path[0] == '\0') return;
  FILE *file = fopen(dex_marker_path, "a");
  if (file == NULL) return;
  va_list args;
  va_start(args, format);
  vfprintf(file, format, args);
  va_end(args);
  fclose(file);
}

static void dex_forced_set_sink_type(id self, SEL cmd, id originalValue) {
  NSString *forcedValue = @"Windows";
  const char *originalText = dex_utf8(originalValue);

  if (dex_original_set_sink_type != NULL) {
    dex_original_set_sink_type(self, cmd, forcedValue);
  }

  id observedValue = nil;
  SEL getter = sel_registerName("sinkType");
  if ([self respondsToSelector:getter]) {
    observedValue = ((id (*)(id, SEL))objc_msgSend)(self, getter);
  }

  dex_marker_append("HOOK_INVOKED=yes\n");
  dex_marker_append("ORIGINAL_ARGUMENT=%s\n", originalText);
  dex_marker_append("FORCED_ARGUMENT=Windows\n");
  dex_marker_append("OBSERVED_AFTER=%s\n", dex_utf8(observedValue));
}

static int dex_try_install_hook(void) {
  pthread_mutex_lock(&dex_hook_lock);
  if (dex_hook_installed) {
    pthread_mutex_unlock(&dex_hook_lock);
    return 1;
  }

  Class messageClass = objc_getClass("MCTerminalInfoRequestMessage");
  if (messageClass == Nil) {
    pthread_mutex_unlock(&dex_hook_lock);
    return 0;
  }

  SEL setter = sel_registerName("setSinkType:");
  Method setterMethod = class_getInstanceMethod(messageClass, setter);
  if (setterMethod == NULL) {
    dex_marker_append("CLASS_FOUND=yes\nSETTER_FOUND=no\n");
    pthread_mutex_unlock(&dex_hook_lock);
    return 0;
  }

  IMP previous = method_setImplementation(setterMethod, (IMP)dex_forced_set_sink_type);
  dex_original_set_sink_type = (void (*)(id, SEL, id))previous;
  dex_hook_installed = 1;

  Method getterMethod = class_getInstanceMethod(messageClass, sel_registerName("sinkType"));
  dex_marker_append("CLASS_FOUND=yes\n");
  dex_marker_append("CLASS_NAME=%s\n", class_getName(messageClass));
  dex_marker_append("SETTER_FOUND=yes\n");
  dex_marker_append("SETTER_ENCODING=%s\n", method_getTypeEncoding(setterMethod));
  dex_marker_append("GETTER_FOUND=%s\n", getterMethod != NULL ? "yes" : "no");
  dex_marker_append("HOOK_INSTALLED=yes\nFORCED_VALUE=Windows\n");

  pthread_mutex_unlock(&dex_hook_lock);
  return 1;
}

static void *dex_hook_worker(void *unused) {
  (void)unused;
  for (int attempt = 0; attempt < 300; attempt++) {
    if (dex_try_install_hook()) return NULL;
    usleep(100000);
  }
  dex_marker_append("HOOK_INSTALLED=no\nHOOK_TIMEOUT=yes\n");
  return NULL;
}

__attribute__((constructor))
static void dex_sink_type_shim_start(void) {
  dex_marker_path = getenv("DEX_SINKTYPE_SHIM_MARKER");
  dex_marker_append("SHIM_LOADED=yes\n");
  dex_marker_append("TARGET_CLASS=MCTerminalInfoRequestMessage\n");
  dex_marker_append("TARGET_SELECTOR=setSinkType:\n");

  if (dex_try_install_hook()) return;

  pthread_t thread;
  if (pthread_create(&thread, NULL, dex_hook_worker, NULL) == 0) {
    pthread_detach(thread);
  } else {
    dex_marker_append("HOOK_THREAD_CREATE_FAILED=yes\n");
  }
}
SHIM

/usr/bin/clang \
  -arch x86_64 \
  -dynamiclib \
  -framework Foundation \
  -mmacosx-version-min=10.13 \
  -Wl,-install_name,@rpath/libDexSinkTypeWindowsShim.dylib \
  -o "$STAGE_SHIM" \
  "$SHIM_SRC"
/bin/chmod 755 "$STAGE_SHIM"

cat > "$STAGE_RUNTIME_BIN" <<'RUNTIME_LAUNCHER'
#!/bin/bash
set -euo pipefail
MACOS_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTENTS_DIR="$(cd "$MACOS_DIR/.." && pwd)"
REAL_BIN="$MACOS_DIR/Samsung DeX.real"
SHIM="$CONTENTS_DIR/Frameworks/libDexSinkTypeWindowsShim.dylib"
LOG_DIR="$HOME/Library/Logs/Samsung DeX Revived"
MARKER="$LOG_DIR/shim_runtime_probe.txt"
APP_LOG="$LOG_DIR/app_stdout_stderr.log"

/bin/mkdir -p "$LOG_DIR"
: > "$MARKER"
: > "$APP_LOG"

export DEX_SINKTYPE_SHIM_MARKER="$MARKER"
export DYLD_INSERT_LIBRARIES="$SHIM"
exec "$REAL_BIN" "$@" >>"$APP_LOG" 2>&1
RUNTIME_LAUNCHER
/bin/chmod 755 "$STAGE_RUNTIME_BIN"

cat > "$STAGE_OUTER_BIN" <<'OUTER_LAUNCHER'
#!/bin/bash
set -u
APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME_LAUNCHER="$APP_DIR/Contents/Resources/Samsung DeX Runtime.app/Contents/MacOS/Samsung DeX"
SERVICE_LABEL="system/com.devguru.ssconnservice2"
SERVICE_PLIST="/Library/LaunchDaemons/com.devguru.ssconnservice2.plist"
LOG_DIR="$HOME/Library/Logs/Samsung DeX Revived"
LAUNCHER_LOG="$LOG_DIR/launcher.log"

/bin/mkdir -p "$LOG_DIR"
{
  echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S %z')] launcher start"

  /usr/bin/osascript -e 'tell application id "com.samsung.DeXonPC" to quit' >/dev/null 2>&1 || true
  /usr/bin/pkill -x "Samsung DeX" >/dev/null 2>&1 || true
  /usr/bin/pkill -f '/Applications/Samsung DeX.app/Contents/MacOS/Samsung DeX' >/dev/null 2>&1 || true
  /usr/bin/pkill -f '/Applications/Samsung DeX Revived.app/Contents/Resources/Samsung DeX Runtime.app/Contents/MacOS/Samsung DeX.real' >/dev/null 2>&1 || true
  /bin/sleep 1

  if ! /bin/launchctl print "$SERVICE_LABEL" >/dev/null 2>&1; then
    echo "connectivity service is not registered; requesting administrator repair"
    /usr/bin/osascript <<APPLESCRIPT
try
  do shell script "/bin/launchctl bootstrap system '$SERVICE_PLIST' >/dev/null 2>&1 || true; /bin/launchctl kickstart -k '$SERVICE_LABEL'" with administrator privileges
on error errorMessage number errorNumber
  error "Samsung connectivity service could not be started: " & errorMessage number errorNumber
end try
APPLESCRIPT
    /bin/sleep 2
  fi

  if [[ ! -x "$RUNTIME_LAUNCHER" ]]; then
    echo "missing runtime launcher: $RUNTIME_LAUNCHER"
    /usr/bin/osascript -e 'display alert "Samsung DeX Revived is incomplete" message "Reinstall the Homebrew cask." as critical'
    exit 1
  fi

  echo "directly launching embedded runtime"
  /usr/bin/nohup "$RUNTIME_LAUNCHER" >/dev/null 2>&1 &
  echo "runtime pid=$!"
} >>"$LAUNCHER_LOG" 2>&1

exit 0
OUTER_LAUNCHER
/bin/chmod 755 "$STAGE_OUTER_BIN"

cat > "$STAGE_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Samsung DeX Revived</string>
  <key>CFBundleExecutable</key>
  <string>Samsung DeX Revived</string>
  <key>CFBundleIdentifier</key>
  <string>$OUTER_BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Samsung DeX Revived</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$ORIGINAL_VERSION</string>
  <key>CFBundleVersion</key>
  <string>3</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

# Reuse the vendor icon when present.
if [[ -f "$STAGE_RUNTIME_APP/Contents/Resources/AppIcon.icns" ]]; then
  /bin/cp "$STAGE_RUNTIME_APP/Contents/Resources/AppIcon.icns" "$STAGE_CONTENTS/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$STAGE_CONTENTS/Info.plist"
fi

cat > "$REVIVAL_INFO" <<INFO
Samsung DeX for Mac revival launcher
Created: $(/bin/date '+%Y-%m-%d %H:%M:%S %z')
Tap compatibility revision: 3
Vendor version: $ORIGINAL_VERSION
Outer bundle identifier: $OUTER_BUNDLE_ID
Compatibility change: TerminalInfo SinkType MAC -> Windows
Architecture: x86_64 under Rosetta 2
Original application: $ORIGINAL_APP
Original application changed: no
Original binary SHA-256: $ORIGINAL_BIN_SHA256
Original Info.plist SHA-256: $ORIGINAL_PLIST_SHA256
Original TeamIdentifier: $TEAM_IDENTIFIER
Runtime startup: unique outer launcher -> direct embedded runtime execution
Connectivity startup: vendor service restarted at installation; repaired on launch if missing
Validation basis: full DeX desktop and keyboard/mouse input verified on 2026-08-01
INFO

/usr/bin/xattr -dr com.apple.quarantine "$STAGE_APP" 2>/dev/null || true
/usr/bin/codesign --force --sign - --timestamp=none "$STAGE_SHIM"
/usr/bin/codesign --force --deep --sign - --timestamp=none "$STAGE_RUNTIME_APP"
/usr/bin/codesign --force --deep --sign - --timestamp=none "$STAGE_APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$STAGE_APP"
/usr/bin/file "$STAGE_REAL" | /usr/bin/grep -q 'x86_64' || fail "Staged real binary is not x86_64."
/usr/bin/file "$STAGE_SHIM" | /usr/bin/grep -q 'x86_64' || fail "Staged shim is not x86_64."

if [[ -d "$TARGET_APP" ]]; then
  /bin/mv "$TARGET_APP" "$BACKUP"
fi
/bin/mv "$STAGE_APP" "$TARGET_APP"
INSTALLED_NEW_TARGET="yes"
/bin/rm -rf "$BACKUP"
trap - EXIT INT TERM
/bin/rm -rf "$STAGE"

verify_target >/dev/null
restart_connectivity_service
printf 'RESULT: INSTALL_OK\nAPP: %s\nBUNDLE_ID: %s\nORIGINAL_APP_UNCHANGED: yes\nHOOK: SinkType MAC -> Windows\nSERVICE_RESTARTED: yes\n' \
  "$TARGET_APP" "$OUTER_BUNDLE_ID"

if [[ "$LAUNCH_AFTER_INSTALL" == "yes" ]]; then
  launch_target
fi
