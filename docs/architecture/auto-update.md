# Automatic updates

AnhPT checks the latest GitHub Release on Android and Windows. Automatic updates are enabled by default and startup checks are throttled to once every 24 hours. A manual check is available under **Settings > Automatic updates**.

## Release assets

A releasable version must publish both platform assets using these names:

- Android: `anhpt-vX.Y.Z.apk`
- Windows: `anhpt-windows-vX.Y.Z.exe`

The GitHub release workflow builds both artifacts. Windows uses an Inno Setup installer under the current user's Local AppData directory so updates do not require administrator privileges.

## Android

The APK is downloaded to the app temporary directory and SHA-256 is verified when GitHub provides an asset digest. AnhPT then opens the Android package installer. Android security rules still require the user to allow installation from this source and confirm the installation; the app does not bypass those protections.

## Windows

The installer is downloaded and verified, then started in silent mode. AnhPT exits so the installer can replace the running application files. The installer relaunches AnhPT after installation. If download or verification fails, the existing installation is left untouched.

## Version comparison

Release tags use semantic versions (`vMAJOR.MINOR.PATCH`). Build metadata such as `+42` is ignored when deciding whether a release is newer.
