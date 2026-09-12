# App distribution

## Current status

The repository is ready for source distribution under MIT. A public notarized App has **not** been produced yet: the maintainer's current machine has a development certificate, but no Developer ID Application identity. Source archives in GitHub Releases are not runnable App downloads.

The release tooling below is prepared for a maintainer with the necessary Apple credentials. It fails rather than publishing an App with an unsuitable signature. Passing fixture tests is not a successful notarization.

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

Release builds use `dist/distribution/LidFold.app`; the development App in `dist/LidFold.app` is not replaced. The published ZIP is created only after all signing, notarization, and Gatekeeper checks succeed. Existing version archives are not overwritten.

## Publish a verified candidate

- Install the exact ZIP on a separate Mac or clean user account and follow the README's screen recording and login-item instructions. Those permissions remain necessary after notarization.
- Confirm version, architecture, checksum, tested devices, and current limitations in the release notes.
- Attach only the verified ZIP and checksum manifest to a GitHub Release for the exact source commit. Use a prerelease while hardware coverage is limited.
- Never upload certificates, private keys, local environment files, development bundles, notarization logs, or keychain profiles.

If a certificate/profile is missing or Apple rejects a submission, resolve it before publishing a binary. Do not instruct users to disable Gatekeeper or remove quarantine as the installation method.
