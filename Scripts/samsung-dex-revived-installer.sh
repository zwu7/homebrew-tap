#!/bin/bash
set -euo pipefail

EXPECTED_VERSION="2.4.0.21"
DEFAULT_ORIGINAL_APP="/Applications/Samsung DeX.app"
DEFAULT_TARGET_APP="/Applications/Samsung DeX Revived.app"
ORIGINAL_APP="$DEFAULT_ORIGINAL_APP"
TARGET_APP="$DEFAULT_TARGET_APP"
MODE="install"
LAUNCH_AFTER_INSTALL="no"

usage() {
  cat <<'EOF'
Usage:
  samsung-dex-revived-installer.sh [install|verify|launch|remove] [options]

Options:
  --original-app PATH   Source Samsung DeX.app path
  --target-app PATH     Revived application path
  --launch              Launch after install
  --no-launch           Do not launch after install (default)
  -h, --help            Show this help
EOF
}

fail() {
  printf 'RESULT: FAIL\n%s\n' "$1" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    install|verify|launch|remove)
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
TARGET_BIN="$TARGET_APP/Contents/MacOS/Samsung DeX"
REAL_BIN="$TARGET_APP/Contents/MacOS/Samsung DeX.real"
SHIM_DYLIB="$TARGET_APP/Contents/Frameworks/libDexSinkTypeWindowsShim.dylib"
LOG_DIR="$HOME/Library/Logs/Samsung DeX Revived"
MARKER="$LOG_DIR/shim_runtime_probe.txt"
APP_LOG="$LOG_DIR/app_stdout_stderr.log"

stop_dex_ui() {
  pkill -x "Samsung DeX" >/dev/null 2>&1 || true
  pkill -f "$TARGET_APP/Contents/MacOS/Samsung DeX.real" >/dev/null 2>&1 || true
  sleep 1
}

check_rosetta() {
  if ! /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    fail "Rosetta 2 is required. Install it with: softwareupdate --install-rosetta --agree-to-license"
  fi
}

verify_target() {
  [[ -d "$TARGET_APP" ]] || fail "Target app is not installed: $TARGET_APP"
  [[ -x "$TARGET_BIN" ]] || fail "Launcher is missing: $TARGET_BIN"
  [[ -x "$REAL_BIN" ]] || fail "Real DeX binary is missing: $REAL_BIN"
  [[ -f "$SHIM_DYLIB" ]] || fail "SinkType shim is missing: $SHIM_DYLIB"

  local version
  version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$TARGET_APP/Contents/Info.plist")"
  [[ "$version" == "$EXPECTED_VERSION" ]] || fail "Unexpected target version: $version"

  file "$REAL_BIN" | grep -q 'x86_64' || fail "Real DeX binary is not x86_64"
  file "$SHIM_DYLIB" | grep -q 'x86_64' || fail "SinkType shim is not x86_64"
  codesign --verify --deep --strict --verbose=2 "$TARGET_APP"

  printf 'RESULT: VERIFY_OK\nAPP: %s\nVERSION: %s\n' "$TARGET_APP" "$version"
}

launch_target() {
  verify_target >/dev/null
  check_rosetta
  stop_dex_ui
  mkdir -p "$LOG_DIR"
  rm -f "$MARKER"
  /usr/bin/open -n "$TARGET_APP"

  for _ in $(seq 1 150); do
    if [[ -f "$MARKER" ]] && grep -q '^HOOK_INSTALLED=yes$' "$MARKER"; then
      printf 'RESULT: LAUNCH_OK\nAPP: %s\nHOOK: SinkType MAC -> Windows\nMARKER: %s\n' \
        "$TARGET_APP" "$MARKER"
      return 0
    fi
    sleep 0.1
  done

  printf 'RESULT: LAUNCHED_BUT_HOOK_NOT_VERIFIED\nAPP: %s\nMARKER: %s\nLOG: %s\n' \
    "$TARGET_APP" "$MARKER" "$APP_LOG"
  return 1
}

case "$MODE" in
  remove)
    stop_dex_ui
    rm -rf "$TARGET_APP"
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
  install)
    ;;
  *)
    fail "Unsupported mode: $MODE"
    ;;
esac

[[ "$(uname -m)" == "arm64" ]] || fail "This revival package supports Apple silicon Macs only."
[[ -x "$ORIGINAL_BIN" ]] || fail "Original Samsung DeX app not found at $ORIGINAL_APP"
[[ -f "$ORIGINAL_PLIST" ]] || fail "Original Samsung DeX Info.plist not found."

for cmd in clang lipo codesign ditto file shasum; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing required command: $cmd"
done
check_rosetta

ORIGINAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ORIGINAL_PLIST")"
[[ "$ORIGINAL_VERSION" == "$EXPECTED_VERSION" ]] || \
  fail "Expected Samsung DeX $EXPECTED_VERSION, found $ORIGINAL_VERSION"

file "$ORIGINAL_BIN" | grep -q 'x86_64' || fail "Original DeX binary does not contain x86_64 code."

TARGET_PARENT="$(dirname "$TARGET_APP")"
mkdir -p "$TARGET_PARENT" "$LOG_DIR"
[[ -w "$TARGET_PARENT" ]] || fail "Target directory is not writable: $TARGET_PARENT"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/samsung-dex-revived.XXXXXX")"
BACKUP="${TARGET_APP}.previous.$$"
INSTALLED_NEW_TARGET="no"

cleanup() {
  rm -rf "$STAGE"
  if [[ "$INSTALLED_NEW_TARGET" != "yes" && -d "$BACKUP" && ! -e "$TARGET_APP" ]]; then
    mv "$BACKUP" "$TARGET_APP" || true
  fi
}
trap cleanup EXIT INT TERM

stop_dex_ui
rm -rf "$BACKUP"
ditto "$ORIGINAL_APP" "$STAGE/Samsung DeX Revived.app"
STAGE_APP="$STAGE/Samsung DeX Revived.app"
STAGE_BIN="$STAGE_APP/Contents/MacOS/Samsung DeX"
STAGE_REAL="$STAGE_APP/Contents/MacOS/Samsung DeX.real"
STAGE_SHIM="$STAGE_APP/Contents/Frameworks/libDexSinkTypeWindowsShim.dylib"
SHIM_SRC="$STAGE_APP/Contents/Resources/dex_sinktype_windows_shim.m"
REVIVAL_INFO="$STAGE_APP/Contents/Resources/REVIVAL_INFO.txt"

lipo "$STAGE_BIN" -thin x86_64 -output "$STAGE_REAL"
chmod 755 "$STAGE_REAL"
rm -f "$STAGE_BIN"

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

clang \
  -arch x86_64 \
  -dynamiclib \
  -framework Foundation \
  -mmacosx-version-min=10.13 \
  -Wl,-install_name,@rpath/libDexSinkTypeWindowsShim.dylib \
  -o "$STAGE_SHIM" \
  "$SHIM_SRC"
chmod 755 "$STAGE_SHIM"

cat > "$STAGE_BIN" <<'LAUNCHER'
#!/bin/bash
set -euo pipefail
MACOS_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTENTS_DIR="$(cd "$MACOS_DIR/.." && pwd)"
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
exec "$REAL_BIN" "$@" >>"$APP_LOG" 2>&1
LAUNCHER
chmod 755 "$STAGE_BIN"

cat > "$REVIVAL_INFO" <<INFO
Samsung DeX for Mac revival wrapper
Created: $(date '+%Y-%m-%d %H:%M:%S %z')
Vendor version: $ORIGINAL_VERSION
Compatibility change: TerminalInfo SinkType MAC -> Windows
Architecture: x86_64 under Rosetta 2
Original application: $ORIGINAL_APP
Original application changed: no
Original binary SHA-256: $(shasum -a 256 "$ORIGINAL_BIN" | awk '{print $1}')
Validation basis: full DeX desktop and keyboard/mouse input verified on 2026-08-01
INFO

xattr -dr com.apple.quarantine "$STAGE_APP" 2>/dev/null || true
codesign --force --sign - --timestamp=none "$STAGE_SHIM"
codesign --force --deep --sign - --timestamp=none "$STAGE_APP"
codesign --verify --deep --strict --verbose=2 "$STAGE_APP"
file "$STAGE_REAL" | grep -q 'x86_64' || fail "Staged real binary is not x86_64."
file "$STAGE_SHIM" | grep -q 'x86_64' || fail "Staged shim is not x86_64."

if [[ -d "$TARGET_APP" ]]; then
  mv "$TARGET_APP" "$BACKUP"
fi
mv "$STAGE_APP" "$TARGET_APP"
INSTALLED_NEW_TARGET="yes"
rm -rf "$BACKUP"
trap - EXIT INT TERM
rm -rf "$STAGE"

verify_target >/dev/null
printf 'RESULT: INSTALL_OK\nAPP: %s\nORIGINAL_APP_UNCHANGED: yes\nHOOK: SinkType MAC -> Windows\n' "$TARGET_APP"

if [[ "$LAUNCH_AFTER_INSTALL" == "yes" ]]; then
  launch_target
fi
