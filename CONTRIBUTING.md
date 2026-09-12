# Contributing to LidFold

Bug reports, compatibility reports, documentation improvements, and focused pull requests are welcome. Use the issue templates and include your Mac model, macOS version, App version, permission state, and reproduction steps. Screenshots should omit personal desktop content.

## Before a pull request

1. Read [the build guide](docs/DEVELOPMENT.md).
2. Run `bash scripts/test.sh` and `python3 -m unittest discover -s tests_release -v`.
3. Explain the user-visible change, tests run, and any real hardware checks you could not perform.
4. Keep fixes focused and preserve existing preferences and permissions where possible.

Do not commit signing certificates, private keys, Apple credentials, local configuration, or App bundles. Use your own certificate for local development. Enable GitHub email privacy and use your GitHub-provided `users.noreply.github.com` address for commits if you do not want your email published.

Contributions are accepted under the repository's MIT License. Preserve required notices when adding code from another source and identify its origin and license in the pull request.

For reports involving a security vulnerability or a possible exposure of screen content, use GitHub's private vulnerability reporting when available rather than attaching sensitive information to a public issue.
