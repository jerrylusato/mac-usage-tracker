Mac Usage tracks foreground application time locally, with daily and weekly reports, history, JSON export, and launch at login.

**Not notarized by Apple — manual approval required.** This universal download supports Apple Silicon and Intel on macOS 13+. It uses an ad-hoc signature, which does not identify the developer to Apple. Apple has not checked this release through its notarization service.

1. Download the DMG, open it, and drag **Mac Usage** into **Applications**.
2. Try opening the app. If macOS blocks it because the developer cannot be verified, open **System Settings → Privacy & Security → Open Anyway**, then confirm. Only proceed if you trust this project and its download. Managed Macs may prevent this exception.
3. Open the app's Settings to enable launch at login and allow report notifications.

Follow [Apple's installation guidance](https://support.apple.com/102445). Do not disable Gatekeeper globally. If macOS reports malware or that the app is damaged, stop and report the problem rather than bypassing that warning.

Quit any running copy before updating. Replacing the app preserves history stored outside the app bundle. Closing the dashboard keeps tracking in the menu bar.

`SHA256SUMS` and `release-manifest.json` accompany the DMG. GitHub build provenance verifies its source and build workflow; it does not replace Apple notarization. Verification commands are in [RELEASING.md](https://github.com/jerrylusato/mac-usage-tracker/blob/main/RELEASING.md).
