# Samsung DeX for Mac Revived

## Install

```bash
brew tap zwu7/tap
brew install --cask zwu7/tap/samsung-dex-macos-revived
open "/Applications/Samsung DeX Revived.app"
```

The cask downloads Samsung DeX for Mac 2.4.0.21 from an archived installer. Because the archive URL is unversioned, Homebrew requires `sha256 :no_check`; before creating the revived runtime, the tap verifies the installed vendor app by exact version, executable SHA-256, Info.plist SHA-256, valid code signature, and Samsung Team ID `8S33FS7Q5Q`.

The tap does **not** redistribute Samsung's proprietary application binary or DMG.

## Compatibility mechanism

Current phone-side `com.sec.android.app.dexonpc` code explicitly stops a session when TerminalInfo declares `SinkType = MAC` on devices whose `ro.product.first_api_level` is at least 31.

The revived runtime:

1. keeps Samsung DeX for Mac `2.4.0.21`;
2. extracts its x86_64 executable;
3. runs it under Rosetta 2;
4. injects a small Objective-C runtime shim;
5. changes only `MCTerminalInfoRequestMessage.setSinkType:` from `MAC` to the phone-recognized value `Windows`.

No `PcVer` or `SinkOSVersion` spoofing is used.

## Revision 4 startup fix

The protocol shim was already correct in revision 2, but a normal `open` could still activate the original application because both bundles used `com.samsung.DeXonPC`. In addition, immediately after package installation the vendor connectivity daemon could remain in a stale running state.

Revision 4 fixes both startup conditions:

- `/Applications/Samsung DeX Revived.app` is now a small outer launcher with the unique bundle identifier `com.zwu7.SamsungDeXRevived`;
- the unmodified-identity Samsung runtime is embedded inside the launcher and executed directly, bypassing LaunchServices bundle selection;
- the cask restarts `system/com.devguru.ssconnservice2` after installation;
- the launcher repairs the service with an administrator prompt only when the service is missing.

The successful runtime probe on 2026-08-01 confirmed:

- `com.devguru.ssconnservice2` running after kickstart;
- direct execution of `Samsung DeX.real`;
- `libDexSinkTypeWindowsShim.dylib` loaded in the process;
- `HOOK_INSTALLED=yes`;
- successful phone recognition and a usable DeX session.

## Files installed

```text
/Applications/Samsung DeX.app
/Applications/Samsung DeX Revived.app
```

The first is Samsung's original application. The second is the tap-managed launcher and embedded revived runtime.

## Maintenance commands

```bash
INSTALLER=/opt/homebrew/Library/Taps/zwu7/homebrew-tap/Scripts/samsung-dex-revived-installer.sh

# Verify the launcher, embedded runtime, shim, and signatures
"$INSTALLER" verify

# Restart the vendor connectivity service and launch with hook verification
"$INSTALLER" launch

# Restart only the vendor connectivity service
"$INSTALLER" repair-service

# Rebuild the launcher from the installed original application
"$INSTALLER" install
```

## Scope and safety

- Apple silicon only.
- Rosetta 2 is installed through Apple `softwareupdate` when missing.
- The original Samsung application is not modified.
- SIP and Startup Security are not changed.
- The obsolete Samsung/Devguru KEXT is not forced to load.
- The compatibility layer is unsupported by Samsung and may need another revision if the phone-side protocol changes.


## Install and reinstall safety

Samsung's vendor installer refuses to run while a Samsung USB device is attached.
Revision 4 checks for the Samsung USB vendor ID before Homebrew begins an install
or uninstall phase. This prevents `brew reinstall` from removing a working copy
before the vendor installer rejects the connected phone. Disconnect the phone,
complete the Homebrew command, then reconnect it for DeX use.
