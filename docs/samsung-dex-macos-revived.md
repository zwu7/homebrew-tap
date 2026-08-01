# Samsung DeX for Mac Revived

## Install

```bash
brew tap zwu7/tap
brew install --cask zwu7/tap/samsung-dex-macos-revived
open "/Applications/Samsung DeX Revived.app"
```

The cask downloads the archived Samsung DeX for Mac 2.4.0.21 installer using a fixed SHA-256. The tap does **not** redistribute Samsung's application binary or DMG.

After installing the vendor package, the tap-maintained installer creates a separate application:

```text
/Applications/Samsung DeX Revived.app
```

The original application remains at:

```text
/Applications/Samsung DeX.app
```

## Compatibility mechanism

Recent phone-side `com.sec.android.app.dexonpc` builds explicitly stop the session when TerminalInfo declares `SinkType = MAC` on devices with `ro.product.first_api_level >= 31`.

The revived copy:

1. keeps Samsung DeX for Mac version `2.4.0.21`;
2. extracts its x86_64 executable;
3. runs it under Rosetta 2;
4. injects a small Objective-C runtime shim;
5. changes only `MCTerminalInfoRequestMessage.setSinkType:` from `MAC` to the phone-recognized value `Windows`.

No `PcVer` or `SinkOSVersion` spoofing is used.

## Verified result

On 2026-08-01, the single-variable change produced:

- `MCTerminalInfoResponseMessage`;
- successful KMS and PSS state changes;
- screen sharing and streaming;
- an enabled DeX desktop;
- working Mac keyboard and mouse input.

## Scope and safety

- Apple silicon only.
- Rosetta 2 is required.
- The original Samsung app is not modified.
- SIP and Startup Security are not changed.
- The obsolete Samsung/Devguru KEXT is not forced to load.
- The compatibility layer is unsupported by Samsung and may require updates if the phone-side protocol changes again.

## Maintenance commands

```bash
# Verify the generated app
/opt/homebrew/Library/Taps/zwu7/homebrew-tap/Scripts/samsung-dex-revived-installer.sh verify

# Launch and verify that the hook loads
/opt/homebrew/Library/Taps/zwu7/homebrew-tap/Scripts/samsung-dex-revived-installer.sh launch

# Rebuild the revived copy from the installed original
/opt/homebrew/Library/Taps/zwu7/homebrew-tap/Scripts/samsung-dex-revived-installer.sh install
```
