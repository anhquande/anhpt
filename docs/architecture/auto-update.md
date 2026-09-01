# Automatic updates

AnhPT checks the latest GitHub Release on Android and Windows. Automatic updates are **off by default**. A manual check is always available under **Settings > Automatic updates**.

When automatic updates are enabled, the update flow runs immediately during application startup, before the main Flutter UI starts. Startup continues only when no newer release exists or when the update check fails safely. If a newer release is found, AnhPT downloads and verifies the installer, launches the platform installer, and terminates the current process so the old version cannot continue running during installation.

Startup checks are performed on every launch while automatic updates are enabled. The GitHub request has a timeout so a network problem does not block startup indefinitely.

## Release assets

A releasable version must publish both platform assets using these names:

- Android: `anhpt-vX.Y.Z.apk`
- Windows: `anhpt-windows-vX.Y.Z.exe`

The GitHub release workflow builds both artifacts. Windows uses an Inno Setup installer under the current user's Local AppData directory so updates do not require administrator privileges.

## Android

The APK is downloaded to the app temporary directory and SHA-256 is verified when GitHub provides an asset digest. AnhPT then opens the Android package installer and terminates the running app process. Android security rules still require the user to allow installation from this source and confirm the installation; the app does not bypass those protections.

## Windows

The installer is downloaded and verified, then started in silent mode. AnhPT exits so the installer can replace the running application files. The installer relaunches AnhPT after installation. If download or verification fails, the existing installation is left untouched and startup can continue.

## Version comparison

Release tags use semantic versions (`vMAJOR.MINOR.PATCH`). Build metadata such as `+42` is ignored when deciding whether a release is newer.
