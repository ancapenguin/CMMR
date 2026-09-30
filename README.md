# CMMR

Codex Mobile Monorepo — a Flutter Android starter used to verify APK builds on GitHub Actions.

Every push or pull request to `main` runs the **Android APK** workflow. It builds a debug APK and uploads it as the `cmmr-debug-apk` artifact for seven days. A manual run is also available from the GitHub Actions tab.

The app source is in `lib/`. Flutter and Android SDK toolchains used for local inspection live outside this repository under `/workspace/.toolchains`.
