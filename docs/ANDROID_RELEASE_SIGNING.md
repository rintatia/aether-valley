# Android Release Signing — Aether Valley

This repository builds a signed ARM64 APK for direct device testing and a signed AAB for store distribution.

## Security rules

- Never commit a keystore, signing password, private key, or populated export preset.
- Never send signing credentials through chat, issues, pull requests, or logs.
- Keep an offline backup of the keystore and its password in a secure password manager or encrypted backup.
- A lost keystore means future APKs signed with a replacement key cannot update the existing installation.
- The workflow reads signing material only from GitHub Actions Secrets and writes the decoded keystore to the ephemeral runner's temporary directory.

## One-time local keystore creation

Run this on a trusted local computer with JDK 17 installed. The command prompts for the keystore password; do not put the password in the command line. Use the same password for the keystore and key because Godot's Android release export currently exposes one release-password setting.

```powershell
keytool -genkeypair -v -keystore aether-valley-release.keystore -alias aether-valley -keyalg RSA -keysize 4096 -validity 10000
```

Back up `aether-valley-release.keystore` and its password securely. Do not place the keystore inside the repository.

## Add GitHub Actions Secrets

In the private repository, open **Settings → Secrets and variables → Actions → New repository secret** and create these three secrets:

1. `ANDROID_RELEASE_KEYSTORE_BASE64` — Base64 representation of the keystore file.
2. `ANDROID_RELEASE_KEY_ALIAS` — `aether-valley` (or the alias selected during key creation).
3. `ANDROID_RELEASE_KEYSTORE_PASSWORD` — the password entered during key creation.

To generate the Base64 value locally in PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes(".\aether-valley-release.keystore"))
```

Copy the output directly into the GitHub secret field. Do not paste it into ChatGPT, GitHub source files, or a terminal transcript that is shared. The alias and password must also be entered directly into GitHub's secret form, not into chat.

## Run a release build

After all three secrets exist, open **Actions → Aether Valley signed Android release → Run workflow**. The workflow validates the secrets, restores the keystore into the temporary runner directory, imports the project, installs the Godot Gradle Android template, runs the gameplay smoke test, exports APK and AAB with `--export-release`, verifies signatures, and uploads the artifacts with SHA-256 checksums.

Expected APK naming: `AetherValley-v1.0.0-rXX-release.apk`, where XX is the GitHub Actions run number. The AAB uses the same version and revision.

## Installation note

The current package ID is `com.rintatia.aethervalley`. A device with an earlier build signed by a different key must uninstall that earlier app before installing this release. Once installed with this persistent release key, later releases using the same key can update it in place.

A successful CI export is not proof of physical-device behavior. Touch controls, screen scaling, save persistence, and gameplay still require device testing.
