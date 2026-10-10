# Releasing Mac Usage

Source is public under MIT. The shared download website is https://usage.jerrylusato.com.
Public downloads currently use an **ad-hoc signature and are not notarized by Apple**.
The owner explicitly selects `MAC_RELEASE_MODE=adhoc` as a GitHub repository variable.
`.github/workflows/release-adhoc.yml` publishes these downloads without Apple credentials.
There is no automatic fallback from a failed notarized release. Set the mode to `notarized`
only after configuring the Apple prerequisites below; `.github/workflows/release.yml`
then performs Developer ID signing and notarization. With neither mode set, publication is skipped.

## Installing the public download

Download the universal DMG from the website or GitHub release. Open it and drag Mac Usage
into Applications, then try opening it. For an unidentified-developer block, use
**System Settings → Privacy & Security → Open Anyway** and confirm only if you trust
this project and download. Managed Macs may disallow this exception. Never disable
Gatekeeper globally or bypass malware/damaged-app alerts. See
[Apple's guidance](https://support.apple.com/102445).
Quit a running copy before replacing it; history is stored outside the app bundle.
Closing the dashboard keeps tracking running in the menu bar. Enable launch at login
and notifications in the app's Settings.

## Checks and versioning

Pull requests and `main` run Swift formatting, the complete XCTest suite, and a universal
Apple Silicon/Intel release build on a macOS 15 GitHub runner. Actions are pinned to commit
revisions and updated by Dependabot. PR builds never use signing secrets. Verification also builds an ad-hoc DMG and mounts it
read-only to verify installer layout, version, signature, and both architectures.

`version.json` is the source of truth for the marketing version and integer build number.
The initial version is 1.0.0 (build 1). For each later release, update both values and the
changelog before merging verified changes. Then tag the exact commit:

```sh
python3 scripts/release.py --validate-only
git tag v1.0.0
git push origin v1.0.0
```

Release tags must match the configured version. Do not move published tags or overwrite
release assets. Rerun failed builds before publication on the same tag; a manually dispatched
run must select a tag. Branch dispatches skip the release job. Published releases cannot
be rerun to replace assets; fixes require a new version/build number.

## Apple signing prerequisites

Requires an Apple Developer Program membership, a Developer ID Application certificate
with its private key exported as password-protected PKCS#12, and an App Store Connect
team API key permitted to use the notarization service. Configure GitHub repository secrets:

- `MAC_CERTIFICATE_BASE64`, `MAC_CERTIFICATE_PASSWORD`: protected certificate export.
- `MAC_SIGNING_IDENTITY`: full `Developer ID Application: ...` identity.
- `APPLE_API_KEY_BASE64`: base64 of the `.p8` private key.
- `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`: corresponding team key identifiers.

Do not commit any certificate/private key. The workflow uses a temporary keychain and
restricted temporary files, then removes them in an always-run cleanup step. Review
release workflow changes carefully because that workflow can use signing credentials.
Missing credentials fail the notarized release; there is no automatic ad-hoc fallback.
You do not need full Xcode on your own Mac to trigger a GitHub-hosted release.

## Release outputs and verification

Both release modes rerun tests, build both architectures, and mount the packaged DMG
read-only to verify its layout, signature, version/build, and architectures. The ad-hoc
workflow verifies `Signature=adhoc` and publishes the warning in `RELEASE-NOTES.md`.
The notarized workflow signs with hardened runtime,
notarizes the app and staples its ticket, checks Gatekeeper acceptance and the bundle
version, packages a DMG, then signs/notarizes/staples the DMG. Notarization failures block
publication. The final DMG is mounted read-only and its packaged app is verified again. The downloaded DMG contains Mac Usage.app and an Applications shortcut; drag the app
into Applications. `scripts/package-dmg.sh` stages that layout before creating the DMG.
Quit the running copy before replacing it. Usage history is stored outside the app bundle.

Assets: `mac-usage-<version>-universal.dmg`, `SHA256SUMS`, `release-manifest.json`.
The manifest includes version/build, source commit, sizes, SHA-256 hashes, `signing`
(`ad-hoc` or `developer-id`), and a boolean `notarized` status. GitHub
creates a provenance attestation for the DMG. Verify a downloaded release with:

```sh
shasum -a 256 -c SHA256SUMS
gh attestation verify mac-usage-1.0.0-universal.dmg --repo jerrylusato/mac-usage-tracker
```

For a Developer ID release only, also run `xcrun stapler validate` on the DMG.
Checksums and provenance verify integrity and build origin, not malware safety or Apple approval.

The website discovers published releases and labels their notarization status; it offers
source builds while no valid release exists. Updates are manual downloads for now, without network access inside the tracker.
