# LidFold

[简体中文](README.md) · [MIT License](LICENSE)

A macOS menu bar experiment that folds your desktop as you close your MacBook lid. Desktop and application images bend with the physical lid angle and return to normal when you open it.

Screen images stay in local memory. LidFold does not save or upload them, capture audio, or make network requests.

## Features

- Live lid angle tracking with folding, blur, and shadow.
- Adjustable activation angle and appearance, saved immediately.
- Five-second preview and **Command–Shift–Escape** emergency pause.
- Optional launch at login, enable on launch, and resume after wake.
- Native macOS settings and menu bar controls.

## Compatibility

The deployment target is macOS 14. Physical behavior has been verified on an **M4 MacBook Pro (Mac16,1), macOS 26.6.2**. Other models and OS versions remain unverified. A readable lid angle sensor is required; its report format is not a cross-model compatibility guarantee from Apple. Only the built-in display is affected.

## Installation and permission

Download the ready-to-run **Apple Silicon (arm64)** build; Xcode is not needed. Intel Macs are not supported by these downloads.

Open the [v0.2.4 DMG](https://github.com/leonthinking/LidFold/releases/download/v0.2.4/LidFold-0.2.4-arm64-unnotarized.dmg), drag **LidFold.app** into **Applications**, eject the image, then open the installed App. A [ZIP](https://github.com/leonthinking/LidFold/releases/download/v0.2.4/LidFold-0.2.4-arm64-unnotarized.zip) and SHA-256 checksums are also available on the [release page](https://github.com/leonthinking/LidFold/releases/tag/v0.2.4). GitHub's Source code archives are for developers.

**This build is not notarized by Apple.** If macOS cannot verify the developer or check for malicious software, confirm that you downloaded it from this repository, then use **System Settings → Privacy & Security → Open Anyway** and confirm. See [Apple's instructions](https://support.apple.com/en-us/102445). This is separate from granting screen recording permission.

Quit before upgrading. Downloads use an ad-hoc signature: upgrading or switching from a locally signed build may require opening approval and screen recording permission again. If an existing enabled grant no longer works, remove the old LidFold entry from screen recording settings, add the new App from Applications with the **+** button, authorize it, then reopen when prompted. Avoid moving the App after registering launch at login. Developers can follow the [build guide](docs/DEVELOPMENT.md).

### First-run permission

1. Open LidFold and enable the desktop effect in General.
2. Open **System Settings → Privacy & Security → Screen & System Audio Recording** (called **Screen Recording** on some versions).
3. Allow **LidFold**. The permission is used for the visual effect; no audio or screen recording is saved.
4. Quit and reopen the app if macOS requests it, then enable the effect again.
5. The default effect starts **below 105°**. Open the lid beyond that angle to restore the desktop, or use the five-second preview in Effects.

If permission is enabled but no image appears, quit and reopen the same authorized App. Permission management is available in Permissions & About. Changing the signing identity or bundle identifier when building may require a new authorization.

Launch at login and enable on launch are separate options, both off by default. If approval is needed, use **System Settings → General → Login Items & Extensions** (or **Login Items**). Automatic activation requires an existing screen recording grant. Resume after wake defaults to on and only restores an effect that was previously enabled; a manual pause remains paused.

LidFold's own settings window stays clear and does not fold, so its controls remain usable. Other application images fold with the desktop. Use the menu bar or **Command–Comma** to open settings, and **Command–Shift–Escape** to pause.

## Limitations

- This transforms the captured image, not actual window or pointer coordinates. Open the lid or pause before normal interaction.
- No Accessibility, camera, or microphone permission is required. Normal lid sleep behavior is unchanged.
- Protected content may be unavailable. HDR matching is not implemented.
- Sensor and capture work still consume power while enabled. Pausing stops both.
- Real login, sleep/wake, lock/unlock, and display changes need broader hardware testing.

## Development

[Build and test](docs/DEVELOPMENT.md) · [Distribution](docs/DISTRIBUTION.md) · [Contributing](CONTRIBUTING.md) · [Roadmap](docs/ROADMAP.md) · [Report an issue](https://github.com/leonthinking/LidFold/issues/new/choose)

## Special thanks

Thanks to **电丸科技 AK** for the inspiration shared in his videos.

[YouTube](https://www.youtube.com/user/ak47hs) · [Bilibili](https://space.bilibili.com/477782158)

## License

Licensed under the [MIT License](LICENSE), copyright leonthinking. Commercial use and redistribution are allowed with the copyright and license notices retained.
