# Packaging

`build.sh` builds the universal `calc` binary and produces `dist/CalculateAnything.alfredworkflow`.

## Build

```sh
Packaging/build.sh
```

It runs `swift build -c release --arch arm64 --arch x86_64`, checks `lipo -info`, stages `calc`, `info.plist`, `icon.png` and the assets the plist references, ad-hoc signs the binary, zips it and prints the sha256. The root `info.plist` is the workflow definition; it runs `./calc` and has no API-key settings.

## Developer ID signing and notarization

1. Install a "Developer ID Application" certificate, then build with `SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" Packaging/build.sh`. This signs with the hardened runtime and a timestamp.
2. Store credentials once: `xcrun notarytool store-credentials calc-notary --apple-id you@example.com --team-id TEAMID`.
3. Submit the zip: `xcrun notarytool submit Packaging/dist/CalculateAnything.alfredworkflow --keychain-profile calc-notary --wait`. The service accepts a zip containing a signed binary.
4. Stapling does not apply: `stapler` cannot attach a ticket to a bare binary or a zip. Do nothing further; Gatekeeper fetches the ticket online on first run. Offline first runs of a quarantined copy will fail the check, so ship the notarized zip unchanged and never re-zip it after notarizing.

## Quarantine

A workflow downloaded in a browser carries `com.apple.quarantine`, and the extracted `calc` inherits it. With an ad-hoc signature macOS blocks the first run ("cannot be opened") and Alfred shows no results. Fix it once:

```sh
xattr -dr com.apple.quarantine ~/Library/Application\ Support/Alfred/Alfred.alfredpreferences/workflows/user.workflow.*/calc
```

(or right-click the workflow folder in Alfred, "Open in Terminal", and run `xattr -dr com.apple.quarantine .`). A Developer ID signed and notarized build does not need this.
