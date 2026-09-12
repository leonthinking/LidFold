# Build and test

## Requirements

- macOS 14 or newer, Xcode command line tools, and Python 3 for release tooling tests.
- Package manifest: Swift tools 5.9. The local verified toolchain is Swift 6.3.3; CI tests its configured Xcode toolchain separately.
- A MacBook with a readable lid angle sensor for live testing. Hosted CI is not a replacement for physical lid testing.
- A valid Apple Development or Developer ID Application certificate with its private key in your keychain to package a local App. Tests and `swift build` do not require a certificate.

```sh
git clone https://github.com/leonthinking/LidFold.git
cd LidFold
bash scripts/test.sh
python3 -m unittest discover -s tests_release -v
swift build -c release --disable-sandbox
```

## Prepare your own development signing identity

In Xcode, open **Settings → Accounts**, add your Apple account if needed, select your team, and open **Manage Certificates**. Create an **Apple Development** certificate if your team supports it. Do not use or request the maintainer's private key. Developer ID distribution requires Apple Developer Program membership and a different certificate.

List valid signing identities:

```sh
security find-identity -v -p codesigning
```

If exactly one supported identity is available, the build script selects it. If several are available, set `LIDFOLD_SIGNING_IDENTITY` to the desired certificate's SHA-1 from that command, then build. Keep using the same identity for successive local builds; changing identity can invalidate an existing screen recording grant.

Quit LidFold before replacing the development App:

```sh
bash scripts/build-app.sh
bash scripts/verify-signing.sh
dist/LidFold.app/Contents/MacOS/LidFold --self-check
open dist/LidFold.app
```

The script stages and validates the App before replacing `dist/LidFold.app`. It deliberately refuses ad-hoc signing. For permission setup, follow [the README](../README.md#首次授权与启用).

## Testing boundaries

Swift tests cover sensor report parsing, fold math, permission decisions, session lifetimes, preferences, login item state, preview deadlines, and offscreen Metal rendering. Metal tests explicitly skip when a device is unavailable. GitHub-hosted VMs also run a shader-free clear/readback probe: an exposed device that cannot return even that clear image is reported as unavailable. This hosted-only exemption never skips a LidFold shader pixel mismatch and does not apply to a physical/self-hosted runner. A CI pass with GPU skips does not establish graphics correctness.

Release tooling tests use fixtures and temporary files to verify certificate selection and publication metadata. They do not contact Apple's notarization service or require credentials. Public CI has read-only repository permissions and does not sign, notarize, or upload an App.

For a release candidate, also test real opening/closing, the emergency pause shortcut, settings interaction, permission after restart, login, sleep/wake, and display changes. Record the exact machine and OS and distinguish actual checks from untested behavior.

## Implementation notes

The app uses IOHIDManager to read the orientation sensor report, ScreenCaptureKit to capture the built-in display while excluding its own windows, and Metal to render the effect. Capture is capped at 1920 px width and 30 fps; the visual transition runs at 60 Hz while needed. Sensor and capture work continue while enabled, even when the effect is hidden.

The current bundle identifier is intentionally stable to preserve local permissions and preferences. A fork can choose its own identifier but should document that it becomes a separate macOS application identity.
