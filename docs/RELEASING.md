# Signing and releasing Markman

The release workflow follows Air Defense's Developer ID + hardened runtime +
Apple notarization process. It runs on GitHub's `macos-15` Apple Silicon runner.
CI on `main` and pull requests builds and tests without signing secrets.

## Configure GitHub Actions secrets

Add these under **Settings → Secrets and variables → Actions** in
[dchersey/markman](https://github.com/dchersey/markman/settings/secrets/actions).
Use the same Developer ID and Apple account used for Air Defense. GitHub does
not let you read an existing secret back, so set these from their original
values rather than attempting to retrieve them from the other repository.

| Secret | Value |
| --- | --- |
| `MACOS_CERT_P12` | Base64-encoded Developer ID Application certificate **and private key**, exported as `.p12`. |
| `MACOS_CERT_PASSWORD` | Password used for that `.p12` export. Omit only if the export has an empty password. |
| `MACOS_SIGN_IDENTITY` | Exact signing identity, beginning `Developer ID Application:`. |
| `APPLE_ID` | Apple Developer account email. |
| `APPLE_APP_PASSWORD` | Apple app-specific password for notarization. |
| `APPLE_TEAM_ID` | Apple Developer team ID associated with the certificate. |

The workflow creates a random temporary keychain password on each run; there is
no `KEYCHAIN_PASSWORD` secret to maintain. It removes the keychain and imported
certificate even if the build fails. Never commit certificates, private keys,
or passwords to this repository.

## Publish

After the main-branch CI passes and the secrets are configured:

```sh
git switch main
git pull --ff-only
git tag v0.1.0
git push origin v0.1.0
```

Choose a new, unused version for subsequent releases. Versions must be exactly
`vMAJOR.MINOR.PATCH`. The tag sets both app bundle version fields; local builds
default to `0.1.1` and can override that with `MARKMAN_VERSION=1.2.3`.
The stable app bundle identifier is `org.hersey.markman`.

The workflow:

1. Checks the tag and required secrets, builds the tagged version, and runs the
   native rendering and launcher tests.
2. Imports the Developer ID into a temporary keychain and signs with hardened
   runtime and a secure timestamp.
3. Tests rendering with that signature, submits the app to Apple, requires an
   `Accepted` result, and staples the notarization ticket.
4. Packages the stapled app, launcher, and licenses; creates corresponding
   source from the exact commit; and calculates SHA-256 checksums.
5. Validates the archive's signature, ticket, Gatekeeper acceptance, version,
   architecture, launcher, and source before creating the GitHub Release.
6. Downloads the published assets in a fresh job and repeats validation.

A missing secret or rejected notarization prevents publication. If a tag run
fails before publishing, correct the issue and rerun it in Actions. For a code
fix, use a new version tag rather than moving a published tag.

## Release assets

- `Markman-macos-arm64.zip`: `Markman.app`, `bin/markman`, and license notices.
- `markman-VERSION-source.tar.gz`: matching source, dependency sources, and
  build scripts, provided alongside the binary for GPLv3 compliance.
- `SHA256SUMS`: checksums for both archives.

The first workflow supports Apple Silicon. Source builds also support Intel;
there is no Intel prebuilt release job yet. The app uses WebKit's separate
rendering process, so no JIT or unsigned-executable-memory entitlement is added
to the app.

## Validate a published release

On macOS with GitHub CLI and Xcode/Command Line Tools installed:

```sh
./scripts/validate-release.sh v0.1.0
./scripts/validate-release.sh          # latest release
```

Validation extracts into a temporary folder, never installs or replaces an
application, and removes downloaded files afterward. CI also uses its
`--local ASSET_DIRECTORY TAG` form before publication.
