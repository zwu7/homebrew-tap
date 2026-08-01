#!/bin/bash
set -euo pipefail

EXPECTED_VERSION="2.4.0.21"
EXPECTED_BUNDLE_ID="com.samsung.DeXonPC"
EXPECTED_ORIGINAL_BIN_SHA256="63bcf82496f2bce5e527160439d2d2fc4610102cfcb9404a5de59c4d45343d98"
EXPECTED_ORIGINAL_PLIST_SHA256="ded1a223b33714da3ad730175db1542ff9e11b666da5b2a1d821060a2f5a7fc7"
EXPECTED_REAL_BIN_SHA256="c715d9d2ce0c036cb4e4196b059536891197de0165f7a2eb8ec7f17f55333bb3"
EXPECTED_ICON_SHA256="959f7309985a022f7f8e24198e203387e60394d0ddaa095fe1b3a74d999c68d3"
EXPECTED_TEAM_IDENTIFIER="8S33FS7Q5Q"

ORIGINAL_APP="/Applications/Samsung DeX.app"
TARGET_APP="/Applications/Samsung DeX Revived.app"
STORE_ROOT="/Library/Application Support/Samsung DeX Revived"
VENDOR_STORE_APP="$STORE_ROOT/Vendor/Samsung DeX.app"
SERVICE_LABEL="system/com.devguru.ssconnservice2"
SERVICE_PLIST="/Library/LaunchDaemons/com.devguru.ssconnservice2.plist"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
LOG_DIR="$HOME/Library/Logs/Samsung DeX Revived"
MARKER="$LOG_DIR/shim_runtime_probe.txt"
APP_LOG="$LOG_DIR/app_stdout_stderr.log"

MODE="install"
LAUNCH_AFTER_INSTALL="no"

usage() {
  cat <<'USAGE'
Usage:
  samsung-dex-revived-installer.sh MODE [options]

Modes:
  install                       Build and install the validated top-level app
  verify                        Verify the installed top-level app
  launch                        Restart the service and launch normally
  repair-service                Restart the Samsung connectivity service
  permission-help               Open Accessibility settings and reveal the app
  assert-phone-disconnected     Fail only for a live Samsung Android USB device
  remove                        Remove tap-managed visible and hidden app copies

Options:
  --launch                      Launch normally after install
  --no-launch                   Do not launch after install (default)
  -h, --help                    Show this help
USAGE
}

fail() {
  printf 'RESULT: FAIL\n%s\n' "$1" >&2
  exit 1
}

run_as_root() {
  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  else
    /usr/bin/sudo "$@"
  fi
}

plist_value() {
  local app="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$app/Contents/Info.plist" 2>/dev/null || true
}

while (($#)); do
  case "$1" in
    install|verify|launch|repair-service|permission-help|assert-phone-disconnected|remove)
      MODE="$1"
      shift
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

samsung_usb_connected() {
  local usb_tree usb_profile
  usb_tree="$(/usr/sbin/ioreg -p IOUSB -l -w 0 2>/dev/null || true)"

  if /usr/bin/grep -Fq 'SAMSUNG_Android' <<<"$usb_tree" && \
     /usr/bin/grep -Eq '"idVendor"[[:space:]]*=[[:space:]]*(1256|0x0*4[eE]8|<e8040000>)' <<<"$usb_tree"; then
    return 0
  fi

  usb_profile="$(/usr/sbin/system_profiler SPUSBDataType 2>/dev/null || true)"
  if /usr/bin/grep -Eq '^[[:space:]]*SAMSUNG_Android:' <<<"$usb_profile" && \
     /usr/bin/grep -Eqi 'Vendor ID:[[:space:]]*0x0*4e8' <<<"$usb_profile"; then
    return 0
  fi

  return 1
}

assert_phone_disconnected() {
  if samsung_usb_connected; then
    cat >&2 <<'MSG'
RESULT: PHONE_CONNECTED
Disconnect the Samsung phone before installing, reinstalling, or uninstalling
Samsung DeX Revived. Reconnect it only after Homebrew reports completion.
MSG
    exit 1
  fi
  printf 'RESULT: PHONE_DISCONNECTED\n'
}

stop_dex() {
  /usr/bin/osascript -e 'tell application id "com.samsung.DeXonPC" to quit' >/dev/null 2>&1 || true
  /usr/bin/pkill -x "Samsung DeX" >/dev/null 2>&1 || true
  /usr/bin/pkill -f '/Applications/Samsung DeX Revived.app/Contents/MacOS/Samsung DeX.real' >/dev/null 2>&1 || true
  /usr/bin/pkill -f '/Applications/Samsung DeX.app/Contents/MacOS/Samsung DeX' >/dev/null 2>&1 || true
  /bin/sleep 2
}

check_rosetta() {
  if /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    return 0
  fi

  printf '%s\n' 'Rosetta 2 is missing. Installing it through Apple softwareupdate...'
  run_as_root /usr/sbin/softwareupdate --install-rosetta --agree-to-license || \
    fail "Rosetta 2 installation failed."
  /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1 || \
    fail "Rosetta 2 remains unavailable."
}

restart_service() {
  [[ -f "$SERVICE_PLIST" ]] || fail "Connectivity service plist is missing: $SERVICE_PLIST"
  if ! run_as_root /bin/launchctl print "$SERVICE_LABEL" >/dev/null 2>&1; then
    run_as_root /bin/launchctl bootstrap system "$SERVICE_PLIST" >/dev/null 2>&1 || true
  fi
  run_as_root /bin/launchctl kickstart -k "$SERVICE_LABEL" || \
    fail "Unable to restart Samsung connectivity service."
  /bin/sleep 2
  run_as_root /bin/launchctl print "$SERVICE_LABEL" >/dev/null 2>&1 || \
    fail "Samsung connectivity service is not registered after restart."
  printf 'SERVICE_RESTARTED: yes\n'
}

verify_vendor_app() {
  local app="$1"
  local bin="$app/Contents/MacOS/Samsung DeX"
  local plist="$app/Contents/Info.plist"
  local version bundle_id bin_hash plist_hash team_id

  [[ -d "$app" ]] || fail "Vendor Samsung DeX app is missing: $app"
  [[ -x "$bin" ]] || fail "Vendor executable is missing: $bin"
  [[ -f "$plist" ]] || fail "Vendor Info.plist is missing: $plist"

  version="$(plist_value "$app" CFBundleShortVersionString)"
  bundle_id="$(plist_value "$app" CFBundleIdentifier)"
  bin_hash="$(/usr/bin/shasum -a 256 "$bin" | /usr/bin/awk '{print $1}')"
  plist_hash="$(/usr/bin/shasum -a 256 "$plist" | /usr/bin/awk '{print $1}')"

  [[ "$version" == "$EXPECTED_VERSION" ]] || fail "Expected vendor version $EXPECTED_VERSION, found $version"
  [[ "$bundle_id" == "$EXPECTED_BUNDLE_ID" ]] || fail "Unexpected vendor bundle ID: $bundle_id"
  [[ "$bin_hash" == "$EXPECTED_ORIGINAL_BIN_SHA256" ]] || fail "Vendor executable hash mismatch: $bin_hash"
  [[ "$plist_hash" == "$EXPECTED_ORIGINAL_PLIST_SHA256" ]] || fail "Vendor Info.plist hash mismatch: $plist_hash"

  /usr/bin/codesign --verify --deep --strict --verbose=2 "$app" >/dev/null 2>&1 || \
    fail "Vendor Samsung DeX signature verification failed."
  team_id="$(/usr/bin/codesign -dv --verbose=4 "$app" 2>&1 | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}')"
  [[ "$team_id" == "$EXPECTED_TEAM_IDENTIFIER" ]] || \
    fail "Unexpected Samsung TeamIdentifier: ${team_id:-missing}"
}

write_shim_source() {
  local path="$1"
  cat > "$path" <<'SHIM'
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
}

write_wrapper() {
  local path="$1"
  cat > "$path" <<'WRAPPER'
#!/bin/bash
set -u
MACOS_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTENTS_DIR="$(cd "$MACOS_DIR/.." && pwd)"
APP_DIR="$(cd "$CONTENTS_DIR/.." && pwd)"
REAL_BIN="$MACOS_DIR/Samsung DeX.real"
SHIM="$CONTENTS_DIR/Frameworks/libDexSinkTypeWindowsShim.dylib"
LOG_DIR="$HOME/Library/Logs/Samsung DeX Revived"
MARKER="$LOG_DIR/shim_runtime_probe.txt"
APP_LOG="$LOG_DIR/app_stdout_stderr.log"

mkdir -p "$LOG_DIR"
: > "$MARKER"
: > "$APP_LOG"

export DEX_SINKTYPE_SHIM_MARKER="$MARKER"
export DYLD_INSERT_LIBRARIES="$SHIM"
"$REAL_BIN" "$@" >> "$APP_LOG" 2>&1
rc=$?

if grep -Fq '[Accessibility] is not allowed' "$APP_LOG" 2>/dev/null; then
  /usr/bin/open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility' >/dev/null 2>&1 || true
  /usr/bin/open -R "$APP_DIR" >/dev/null 2>&1 || true
  /usr/bin/osascript <<OSA >/dev/null 2>&1 || true
try
  display dialog "Samsung DeX Revived needs one-time Accessibility permission. In System Settings, add or enable Samsung DeX Revived, then open it again." buttons {"OK"} default button "OK" with title "Samsung DeX Revived"
end try
OSA
fi

exit "$rc"
WRAPPER
  /bin/chmod 755 "$path"
}

verify_target() {
  local app="${1:-$TARGET_APP}"
  local wrapper="$app/Contents/MacOS/Samsung DeX"
  local real_bin="$app/Contents/MacOS/Samsung DeX.real"
  local shim="$app/Contents/Frameworks/libDexSinkTypeWindowsShim.dylib"
  local icon="$app/Contents/Resources/DeXonPC.icns"
  local bundle_id version executable icon_name real_hash icon_hash

  [[ -d "$app" ]] || fail "Target app is missing: $app"
  [[ ! -d "$app/Contents/Resources/Samsung DeX Runtime.app" ]] || fail "Nested runtime app must not exist."
  [[ -x "$wrapper" ]] || fail "Top-level wrapper is missing: $wrapper"
  [[ -x "$real_bin" ]] || fail "Top-level real binary is missing: $real_bin"
  [[ -f "$shim" ]] || fail "Top-level protocol shim is missing: $shim"
  [[ -f "$icon" ]] || fail "Samsung DeX icon is missing: $icon"

  bundle_id="$(plist_value "$app" CFBundleIdentifier)"
  version="$(plist_value "$app" CFBundleShortVersionString)"
  executable="$(plist_value "$app" CFBundleExecutable)"
  icon_name="$(plist_value "$app" CFBundleIconFile)"
  real_hash="$(/usr/bin/shasum -a 256 "$real_bin" | /usr/bin/awk '{print $1}')"
  icon_hash="$(/usr/bin/shasum -a 256 "$icon" | /usr/bin/awk '{print $1}')"

  [[ "$bundle_id" == "$EXPECTED_BUNDLE_ID" ]] || fail "Unexpected target bundle ID: $bundle_id"
  [[ "$version" == "$EXPECTED_VERSION" ]] || fail "Unexpected target version: $version"
  [[ "$executable" == "Samsung DeX" ]] || fail "Unexpected target executable: $executable"
  [[ "$icon_name" == "DeXonPC" || "$icon_name" == "DeXonPC.icns" ]] || fail "Unexpected icon declaration: $icon_name"
  [[ "$real_hash" == "$EXPECTED_REAL_BIN_SHA256" ]] || fail "Unexpected x86_64 binary hash: $real_hash"
  [[ "$icon_hash" == "$EXPECTED_ICON_SHA256" ]] || fail "Unexpected icon hash: $icon_hash"

  /usr/bin/file "$real_bin" | /usr/bin/grep -q 'x86_64' || fail "Real binary is not x86_64."
  /usr/bin/file "$shim" | /usr/bin/grep -q 'x86_64' || fail "Shim is not x86_64."
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$app" >/dev/null 2>&1 || \
    fail "Target ad-hoc signature verification failed."

  printf 'RESULT: VERIFY_OK\nAPP: %s\nBUNDLE_ID: %s\nVERSION: %s\nICON: DeXonPC.icns\nLAYOUT: top-level\n' \
    "$app" "$bundle_id" "$version"
}

build_stage() {
  local source_app="$1"
  local stage_app="$2"
  local stage_bin="$stage_app/Contents/MacOS/Samsung DeX"
  local stage_real="$stage_app/Contents/MacOS/Samsung DeX.real"
  local stage_shim="$stage_app/Contents/Frameworks/libDexSinkTypeWindowsShim.dylib"
  local shim_src="$stage_app/Contents/Resources/dex_sinktype_windows_shim.m"
  local revival_info="$stage_app/Contents/Resources/REVIVAL_INFO.txt"

  /usr/bin/ditto "$source_app" "$stage_app"
  /usr/bin/lipo "$stage_bin" -thin x86_64 -output "$stage_real"
  /bin/chmod 755 "$stage_real"
  /bin/rm -f "$stage_bin"

  write_shim_source "$shim_src"
  /usr/bin/clang \
    -arch x86_64 \
    -dynamiclib \
    -framework Foundation \
    -mmacosx-version-min=10.13 \
    -Wl,-install_name,@rpath/libDexSinkTypeWindowsShim.dylib \
    -o "$stage_shim" \
    "$shim_src"
  /bin/chmod 755 "$stage_shim"
  write_wrapper "$stage_bin"

  cat > "$revival_info" <<INFO
Samsung DeX for Mac Revived - Homebrew tap revision 6
Vendor version: $EXPECTED_VERSION
Architecture: complete top-level bundle with x86_64 runtime under Rosetta 2
Protocol compatibility change: TerminalInfo SinkType MAC -> Windows
Validated: main UI, full DeX desktop, Mac input, and second normal open
Source executable SHA-256: $EXPECTED_ORIGINAL_BIN_SHA256
Source Info.plist SHA-256: $EXPECTED_ORIGINAL_PLIST_SHA256
INFO

  /usr/bin/xattr -dr com.apple.quarantine "$stage_app" 2>/dev/null || true
  /usr/bin/codesign --force --sign - --timestamp=none "$stage_shim" >/dev/null
  /usr/bin/codesign --force --deep --sign - --timestamp=none "$stage_app" >/dev/null
  verify_target "$stage_app" >/dev/null
}

install_target() {
  local source_app stage_dir stage_app backup_dir old_target old_store source_was_original
  source_was_original="no"

  if [[ -d "$ORIGINAL_APP" ]]; then
    source_app="$ORIGINAL_APP"
    source_was_original="yes"
  elif [[ -d "$VENDOR_STORE_APP" ]]; then
    source_app="$VENDOR_STORE_APP"
  else
    fail "Neither the package-installed vendor app nor the hidden verified source exists."
  fi

  verify_vendor_app "$source_app"
  check_rosetta

  stage_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/samsung-dex-revived-v6.XXXXXX")"
  stage_app="$stage_dir/Samsung DeX Revived.app"
  backup_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/samsung-dex-revived-v6-backup.XXXXXX")"
  old_target="$backup_dir/Previous Samsung DeX Revived.app"
  old_store="$backup_dir/Previous Vendor Store.app"

  cleanup_install() {
    local rc=$?
    set +e
    /bin/rm -rf "$stage_dir"
    if [[ "$rc" -ne 0 ]]; then
      if [[ -d "$TARGET_APP" ]]; then
        run_as_root /bin/rm -rf "$TARGET_APP"
      fi
      if [[ -d "$old_target" ]]; then
        run_as_root /bin/mv "$old_target" "$TARGET_APP"
      fi
      if [[ "$source_was_original" == "yes" && ! -d "$ORIGINAL_APP" && -d "$VENDOR_STORE_APP" ]]; then
        run_as_root /bin/mv "$VENDOR_STORE_APP" "$ORIGINAL_APP"
      fi
      if [[ -d "$old_store" && ! -d "$VENDOR_STORE_APP" ]]; then
        run_as_root /bin/mkdir -p "$(/usr/bin/dirname "$VENDOR_STORE_APP")"
        run_as_root /bin/mv "$old_store" "$VENDOR_STORE_APP"
      fi
    fi
    /bin/rm -rf "$backup_dir"
    exit "$rc"
  }
  trap cleanup_install EXIT INT TERM

  build_stage "$source_app" "$stage_app"
  stop_dex

  if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -u "$ORIGINAL_APP" >/dev/null 2>&1 || true
    "$LSREGISTER" -u "$TARGET_APP" >/dev/null 2>&1 || true
  fi

  if [[ -d "$TARGET_APP" ]]; then
    run_as_root /bin/mv "$TARGET_APP" "$old_target"
  fi

  if [[ -d "$VENDOR_STORE_APP" && "$source_app" != "$VENDOR_STORE_APP" ]]; then
    run_as_root /bin/mv "$VENDOR_STORE_APP" "$old_store"
  fi

  run_as_root /bin/mkdir -p "$(/usr/bin/dirname "$VENDOR_STORE_APP")"
  if [[ "$source_was_original" == "yes" ]]; then
    run_as_root /bin/mv "$ORIGINAL_APP" "$VENDOR_STORE_APP"
  fi

  run_as_root /bin/mv "$stage_app" "$TARGET_APP"
  run_as_root /usr/sbin/chown -R root:wheel "$TARGET_APP" "$STORE_ROOT"
  verify_target "$TARGET_APP" >/dev/null
  verify_vendor_app "$VENDOR_STORE_APP"

  if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -f "$TARGET_APP" >/dev/null 2>&1 || true
  fi

  restart_service
  /bin/rm -rf "$old_target" "$old_store"
  trap - EXIT INT TERM
  /bin/rm -rf "$stage_dir" "$backup_dir"

  printf 'RESULT: INSTALL_OK\nAPP: %s\nVISIBLE_APPS: 1\nBUNDLE_ID: %s\nHOOK: SinkType MAC -> Windows\nLAYOUT: top-level\nSERVICE_RESTARTED: yes\n' \
    "$TARGET_APP" "$EXPECTED_BUNDLE_ID"
}

launch_target() {
  verify_target "$TARGET_APP" >/dev/null
  check_rosetta
  stop_dex
  restart_service
  /bin/mkdir -p "$LOG_DIR"
  /bin/rm -f "$MARKER" "$APP_LOG"
  /usr/bin/open -n "$TARGET_APP"

  local i
  for i in $(/usr/bin/seq 1 200); do
    if [[ -f "$MARKER" ]] && /usr/bin/grep -Fqx 'HOOK_INSTALLED=yes' "$MARKER"; then
      if /usr/bin/grep -Fq '[Accessibility] is not allowed' "$APP_LOG" 2>/dev/null; then
        printf 'RESULT: ACCESSIBILITY_APPROVAL_REQUIRED\nAPP: %s\n' "$TARGET_APP"
        exit 2
      fi
      printf 'RESULT: LAUNCH_OK\nAPP: %s\nHOOK: SinkType MAC -> Windows\n' "$TARGET_APP"
      return 0
    fi
    /bin/sleep 0.1
  done

  fail "The app launched without confirming the protocol hook. See $APP_LOG"
}

permission_help() {
  [[ -d "$TARGET_APP" ]] || fail "Target app is missing: $TARGET_APP"
  /usr/bin/open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility' >/dev/null 2>&1 || true
  /usr/bin/open -R "$TARGET_APP" >/dev/null 2>&1 || true
  printf 'RESULT: ACCESSIBILITY_SETTINGS_OPENED\nAPP: %s\n' "$TARGET_APP"
}

remove_managed_apps() {
  stop_dex
  run_as_root /bin/rm -rf "$TARGET_APP" "$ORIGINAL_APP" "$STORE_ROOT"
  printf 'RESULT: REMOVED\n'
}

case "$MODE" in
  assert-phone-disconnected)
    assert_phone_disconnected
    ;;
  install)
    [[ "$(/usr/bin/uname -m)" == "arm64" ]] || fail "Apple silicon is required."
    assert_phone_disconnected
    install_target
    if [[ "$LAUNCH_AFTER_INSTALL" == "yes" ]]; then
      launch_target
    fi
    ;;
  verify)
    verify_target "$TARGET_APP"
    verify_vendor_app "$VENDOR_STORE_APP"
    ;;
  launch)
    launch_target
    ;;
  repair-service)
    restart_service
    printf 'RESULT: SERVICE_REPAIRED\n'
    ;;
  permission-help)
    permission_help
    ;;
  remove)
    remove_managed_apps
    ;;
  *)
    fail "Unsupported mode: $MODE"
    ;;
esac
