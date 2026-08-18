# Releasing Croft

A release is a notarized drag-to-install disk image: a signed, notarized, stapled `Croft.app` inside a signed, notarized, stapled `Croft-<version>.dmg` attached to the GitHub release. The `Release` workflow does all of it. It runs only on version tags and manual dispatch, never on pull requests, so signing material is never exposed to fork-triggered runs.

## Cutting a release

1. Make sure `main` is green and the changelog is curated.
2. Tag and push:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

3. The workflow builds Croft-macOS in Release, signs it with the Developer ID Application certificate, notarizes it through notarytool, staples the ticket, and verifies the result with `codesign` and `spctl`. It then packages the stapled app into `Croft-<version>.dmg` (a volume named `Croft <version>` holding the app and an Applications symlink, built with hdiutil), signs the dmg with the same identity, notarizes and staples it too, and assesses it with `spctl --type open`. The dmg then gets its second signature: the job fetches the Sparkle distribution at a version pinned by sha256, signs the dmg with `sign_update` using the EdDSA private key from the `SPARKLE_ED_PRIVATE_KEY` secret, and writes `appcast.xml` with an enclosure pointing at the release's dmg download URL, the marketing version as `sparkle:shortVersionString`, and the run number as `sparkle:version` (matching the archived `CURRENT_PROJECT_VERSION`). Finally it creates the GitHub release for the tag if one doesn't exist and attaches both the dmg and `appcast.xml`. The app polls `https://github.com/DisplacedForest/Croft/releases/latest/download/appcast.xml`, which always resolves to the newest release's appcast; that URL is permanent and must never change.

To rehearse without tagging, run the workflow manually from the Actions tab (workflow_dispatch) on any branch. A rehearsal signs and notarizes for real but uploads the dmg as a workflow artifact instead of creating a release.

## Required repository secrets

All of these live in GitHub under Settings, Secrets and variables, Actions. None of this material ever goes in the repo.

| Secret | What it is |
| --- | --- |
| `MACOS_SIGNING_CERT_P12_BASE64` | Developer ID Application certificate plus private key, exported as a `.p12`, base64 encoded |
| `MACOS_SIGNING_CERT_PASSWORD` | The passphrase set when exporting the `.p12` |
| `MACOS_PROVISIONING_PROFILE_BASE64` | Developer ID provisioning profile for `com.displacedforest.croft` with the WeatherKit capability, base64 encoded. Must be named `Croft Developer ID`, since `project.yml` pins that name to the app target's Release configuration (xcodebuild command-line overrides hit SwiftPM package targets, which reject profiles, so the setting lives in the project instead) |
| `APPLE_API_KEY_P8_BASE64` | App Store Connect API key (`.p8`), base64 encoded, used by notarytool |
| `APPLE_API_KEY_ID` | Key ID of that API key |
| `APPLE_API_ISSUER_ID` | Issuer ID from the App Store Connect API keys page |
| `APPLE_TEAM_ID` | The 10-character Apple Developer team ID, shown under Membership details on developer.apple.com or in Xcode, Settings, Accounts |
| `SPARKLE_ED_PRIVATE_KEY` | The Sparkle EdDSA private key that signs every update for the appcast, base64 as printed by Sparkle's `generate_keys -x`. Lives only here and in the password manager |

### Creating the material

1. Certificate: in the Apple Developer portal (Certificates), create a Developer ID Application certificate, or open Xcode, Settings, Accounts, Manage Certificates and create it there. Export it from Keychain Access as a `.p12` with a passphrase.
2. Provisioning profile: in the portal (Profiles), create a Developer ID profile for the `com.displacedforest.croft` App ID. The App ID must have the WeatherKit capability enabled, since the app's entitlements include WeatherKit and a profile without it fails at archive time.
3. API key: in App Store Connect, Users and Access, Integrations, create a team key with the Developer role. Download the `.p8` once and note the Key ID and Issuer ID.
4. Encode the files:

   ```sh
   base64 -i DeveloperID.p12 | pbcopy
   base64 -i Croft_DeveloperID.provisionprofile | pbcopy
   base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
   ```

5. Paste each into its secret.

### Sparkle update key

Generate once with Sparkle's key tool (download the release matching the version pinned in the workflow):

```sh
curl -sSfLO https://github.com/sparkle-project/Sparkle/releases/download/2.9.6/Sparkle-2.9.6.tar.xz
tar -xJf Sparkle-2.9.6.tar.xz
./bin/generate_keys
./bin/generate_keys -x sparkle-private-key
```

`generate_keys` stores the keypair in the login Keychain and prints the public key. The public key goes in `project.yml`'s Info.plist as `SUPublicEDKey`. The `-x` export writes the private key to a file: paste its contents into the `SPARKLE_ED_PRIVATE_KEY` secret and the password manager, then delete the file. The private key never enters the repo in any form.

Rotating the Sparkle key is not like rotating Apple material: shipped apps pin the old public key and reject updates signed with a new one. A rotation therefore needs a bridge release, signed with the old key but carrying the new public key in its Info.plist, before releases signed only with the new key work. Treat the key as compromised-only rotation, keep the keypair backed up, and if it is ever lost, users on old versions must manually download once, exactly like the pre-Sparkle floor.

## How the workflow handles the material

The certificate is imported into a throwaway keychain created with a random password inside the job. The provisioning profile's name and UUID are read from the profile itself, so there is no separate secret for them. A cleanup step that runs even on failure deletes the keychain, the installed profile, and every decoded file.

## Rotation

Rotation is a secrets-only operation. No repo changes, no PR.

1. Revoke the compromised or expiring item in the Apple Developer portal (certificate or profile) or App Store Connect (API key).
2. Create the replacement the same way as above.
3. Re-encode it and overwrite the matching repository secret. A new certificate usually means a new provisioning profile too, since the profile embeds the certificate. Keep the profile named `Croft Developer ID`; the workflow checks the installed profile against the name pinned in `project.yml` and fails with instructions if they diverge.
4. Run a rehearsal via workflow_dispatch and confirm the run goes green through the Gatekeeper assessment step.

Previously shipped builds stay valid: notarization tickets are stapled to the artifacts and do not depend on the certificate remaining live, unless the certificate was revoked for compromise, in which case Apple invalidates its signatures and the affected releases need rebuilding.
