# Releasing Mac Usage

Source is public under MIT. The shared download website is https://usage.jerrylusato.com.
Public Mac binaries require Developer ID signing and successful Apple notarization.
Local ad-hoc builds and verification artifacts are not public distribution releases.

## Checks and versioning

Pull requests and `main` run Swift formatting, the complete XCTest suite, and a universal
Apple Silicon/Intel release build on a macOS 15 GitHub runner. Actions are pinned to commit
revisions and updated by Dependabot. PR builds never use signing secrets.

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
Missing credentials fail the release; there is no unsigned public-release fallback.
You do not need full Xcode on your own Mac to trigger a GitHub-hosted release.

## Release outputs and verification

The workflow reruns tests, builds both architectures, signs with hardened runtime,
notarizes the app and staples its ticket, checks Gatekeeper acceptance and the bundle
version, packages a DMG, then signs/notarizes/staples the DMG. Notarization failures block
publication. The downloaded DMG contains Mac Usage.app; drag it into Applications.
Quit the running copy before replacing it. Usage history is stored outside the app bundle.

Assets: `mac-usage-<version>-universal.dmg`, `SHA256SUMS`, `release-manifest.json`.
The manifest includes version/build, source commit, sizes and SHA-256 hashes. GitHub
creates a provenance attestation for the DMG. Verify a downloaded release with:

```sh
shasum -a 256 -c SHA256SUMS
gh attestation verify mac-usage-1.0.0-universal.dmg --repo jerrylusato/mac-usage-tracker
xcrun stapler validate mac-usage-1.0.0-universal.dmg
```

The website discovers published releases; it offers source builds while no signed release
exists. Updates are manual downloads for now, without network access inside the tracker.
