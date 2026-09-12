# App distribution

## Current status

GitHub Releases provide **unnotarized arm64 DMG and ZIP downloads** under MIT, plus SHA-256 checksums. Source archives are separate. No Developer ID signed, Apple-notarized App has been produced yet.

## Unnotarized downloads (current workflow)

```sh
bash scripts/test.sh
python3 -m unittest discover -s tests_release -v
bash scripts/release-unnotarized.sh
```

This explicitly selects ad-hoc signing without reading or embedding a personal certificate. It builds into a private directory, verifies the signature and arm64 architecture, runs the packaged Metal self-check, produces a ZIP and a DMG with an Applications shortcut and installation instructions, verifies the disk image, and writes SHA256SUMS. Outputs are under `dist/releases-unnotarized/<version>/`; existing versions are never overwritten. It uses the same release/build locks as the notarized workflow and does not replace the authorized development App.

Ad-hoc signatures do not establish a stable developer identity across builds. Updates may require opening approval and a fresh screen recording grant; the README documents removing a stale permission entry and adding the new installed App. Keep the exact archive for each release rather than silently rebuilding it. A stable signing identity for future public updates remains a follow-up.

Before uploading, mount the DMG read-only, verify and self-check its App, check the Applications shortcut, extract and verify the ZIP, and compare the App payloads. Record the exact source commit, architecture and validation limits. Publish DMG, ZIP and SHA256SUMS as a GitHub prerelease while hardware coverage is limited. Never attach the locally certificate-signed development App or private signing material.

First launch follows Apple's **Privacy & Security → Open Anyway** process, separately from screen recording permission. Do not disable Gatekeeper globally. A valid ad-hoc signature and successful self-check are not notarization or a clean-machine installation test.

## Notarized downloads (future workflow)

The separate `scripts/release.sh` requires the Apple credentials below and fails if they are unavailable. Passing fixture tests is not a successful notarization.

## One-time prerequisites

1. Join the Apple Developer Program and create a **Developer ID Application** certificate for a team you are authorized to represent. Install it together with its private key in the local keychain.
2. Install full Xcode with `notarytool` and `stapler` available through `xcrun`.
3. Run the following command in your own terminal and complete its interactive prompts. Credentials are stored in Keychain, not in the repository or shell command history:

   ```sh
   xcrun notarytool store-credentials LidFold-notary
   ```

4. Set `LIDFOLD_SIGNING_IDENTITY` to the Developer ID certificate's SHA-1 if more than one distribution identity exists. Use `security find-identity -v -p codesigning` to find it.

Apple's [Developer ID documentation](https://developer.apple.com/developer-id/) explains membership and outside-the-store distribution. Never attach certificate/private-key files or credentials to an issue or pull request.

## Prepare an archive

Run local tests and real hardware acceptance first, quit LidFold, then:

```sh
LIDFOLD_NOTARY_PROFILE=LidFold-notary bash scripts/release.sh
```

The script builds an **arm64** App with hardened runtime and a secure timestamp, verifies its signature, submits it to Apple, requires an `Accepted` result, staples and validates the ticket, and checks Gatekeeper. It then creates a ZIP and SHA-256 manifest under `dist/releases/<version>/`. The App includes its MIT license.

The release script builds in its own temporary directory; the development App in `dist/LidFold.app` is not replaced. A manual `LIDFOLD_BUILD_MODE=distribution bash scripts/build-app.sh` build goes to `dist/distribution/LidFold.app`. Builds share a lock, and an in-progress notarization never reads from a destination another build could replace. The published ZIP is created only after all signing, notarization, and Gatekeeper checks succeed. Existing version archives are not overwritten.

## Publish a verified candidate

- Install the exact ZIP on a separate Mac or clean user account and follow the README's screen recording and login-item instructions. Those permissions remain necessary after notarization.
- Confirm version, architecture, checksum, tested devices, and current limitations in the release notes.
- Attach only the verified ZIP and checksum manifest to a GitHub Release for the exact source commit. Use a prerelease while hardware coverage is limited.
- Never upload certificates, private keys, local environment files, development bundles, notarization logs, or keychain profiles.

If a certificate/profile is missing or Apple rejects a submission, this notarized workflow must fail. It must never silently fall back to the explicitly separate unnotarized workflow or label an unnotarized download as notarized.
