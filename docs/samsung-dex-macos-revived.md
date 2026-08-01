# Samsung DeX for Mac Revived

## Install

Disconnect the Samsung phone during installation:

```bash
brew tap zwu7/tap
brew install --cask zwu7/tap/samsung-dex-macos-revived
open "/Applications/Samsung DeX Revived.app"
```

The cask downloads Samsung DeX for Mac 2.4.0.21 from an archived vendor installer. The archive URL is unversioned, so Homebrew requires `sha256 :no_check`. Before creating the revived app, the installer verifies the exact vendor version, executable SHA-256, Info.plist SHA-256, Samsung code signature, and Team ID `8S33FS7Q5Q`.

The tap does not redistribute Samsung's proprietary application, package, or DMG.

## Why the compatibility layer is needed

The phone-side `com.sec.android.app.dexonpc` version tested on 2026-08-01 explicitly stops a session when TerminalInfo declares `SinkType = MAC` on a device whose first API level is at least 31.

The compatibility shim changes only:

```text
SinkType: MAC -> Windows
```

It does not spoof `PcVer` or `SinkOSVersion`.

## Revision 6: validated top-level layout

Revision 6 is based on the final successful local validation rather than the failed nested-runtime design used in revisions 3-5.

It installs one visible application:

```text
/Applications/Samsung DeX Revived.app
```

The app is a complete top-level Samsung bundle:

```text
Samsung DeX Revived.app
├── Contents/Info.plist
├── Contents/MacOS/Samsung DeX
├── Contents/MacOS/Samsung DeX.real
├── Contents/Frameworks/libDexSinkTypeWindowsShim.dylib
└── Contents/Resources/DeXonPC.icns
```

The package-installed, code-signed vendor source is retained outside Applications for verification and repair:

```text
/Library/Application Support/Samsung DeX Revived/Vendor/Samsung DeX.app
```

It is not registered as a visible application.

The final validation on 2026-08-01 passed all four checks:

```text
MAIN_UI=y
FULL_DEX=y
INPUT_OK=y
SECOND_NORMAL_LAUNCH=y
```

The runtime log also confirmed `SinkType = Windows` and a successful `MCTerminalInfoResponseMessage`.

## Accessibility permission

macOS may require one-time approval:

```text
System Settings -> Privacy & Security -> Accessibility
```

Add or enable `/Applications/Samsung DeX Revived.app`, then open it again. The wrapper opens the correct settings pane when the old DeX runtime reports that Accessibility is denied.

## Maintenance

```bash
INSTALLER=/opt/homebrew/Library/Taps/zwu7/homebrew-tap/Scripts/samsung-dex-revived-installer.sh

# Verify the top-level app and hidden vendor source
"$INSTALLER" verify

# Restart the connectivity service and launch through normal LaunchServices
"$INSTALLER" launch

# Open the Accessibility pane and reveal the exact app
"$INSTALLER" permission-help

# Restart only the Samsung connectivity service
"$INSTALLER" repair-service
```

## Safety and scope

- Apple silicon only.
- Rosetta 2 is installed through Apple `softwareupdate` when missing.
- Only one DeX application is visible in Applications.
- SIP and Startup Security are not changed.
- The obsolete Samsung KEXT is not forced to load.
- Samsung phones must be disconnected during install, reinstall, and uninstall.
- The compatibility layer is unsupported by Samsung and may need another revision if the phone protocol changes.
