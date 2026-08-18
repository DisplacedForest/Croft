# Releasing Croft

A release is a signed, notarized, stapled macOS app attached to a GitHub release. The `Release` workflow does all of it. It runs only on version tags and manual dispatch, never on pull requests, so signing material is never exposed to fork-triggered runs.

## Cutting a release

1. Make sure `main` is green and the changelog is curated.
2. Tag and push:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

3. The workflow builds Croft-macOS in Release, signs it with the Developer ID Application certificate, notarizes it through notarytool, staples the ticket, verifies the result with `codesign` and `spctl`, creates the GitHub release for the tag if one doesn't exist, and attaches `Croft-<version>-macOS.zip`.

To rehearse without tagging, run the workflow manually from the Actions tab (workflow_dispatch) on any branch. A rehearsal signs and notarizes for real but uploads the zip as a workflow artifact instead of creating a release.

## Required repository secrets

All of these live in GitHub under Settings, Secrets and variables, Actions. None of this material ever goes in the repo.

| Secret | What it is |
| --- | --- |
| `MACOS_SIGNING_CERT_P12_BASE64` | Developer ID Application certificate plus private key, exported as a `.p12`, base64 encoded |
| `MACOS_SIGNING_CERT_PASSWORD` | The passphrase set when exporting the `.p12` |
| `MACOS_PROVISIONING_PROFILE_BASE64` | Developer ID provisioning profile for `com.displacedforest.croft` with the WeatherKit capability, base64 encoded |
| `APPLE_API_KEY_P8_BASE64` | App Store Connect API key (`.p8`), base64 encoded, used by notarytool |
| `APPLE_API_KEY_ID` | Key ID of that API key |
| `APPLE_API_ISSUER_ID` | Issuer ID from the App Store Connect API keys page |
| `APPLE_TEAM_ID` | The 10-character Apple Developer team ID, shown under Membership details on developer.apple.com or in Xcode, Settings, Accounts |

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

## How the workflow handles the material

The certificate is imported into a throwaway keychain created with a random password inside the job. The provisioning profile's name and UUID are read from the profile itself, so there is no separate secret for them. A cleanup step that runs even on failure deletes the keychain, the installed profile, and every decoded file.

## Rotation

Rotation is a secrets-only operation. No repo changes, no PR.

1. Revoke the compromised or expiring item in the Apple Developer portal (certificate or profile) or App Store Connect (API key).
2. Create the replacement the same way as above.
3. Re-encode it and overwrite the matching repository secret. A new certificate usually means a new provisioning profile too, since the profile embeds the certificate.
4. Run a rehearsal via workflow_dispatch and confirm the run goes green through the Gatekeeper assessment step.

Previously shipped builds stay valid: notarization tickets are stapled to the artifacts and do not depend on the certificate remaining live, unless the certificate was revoked for compromise, in which case Apple invalidates its signatures and the affected releases need rebuilding.
