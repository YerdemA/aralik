/// Update notice (pure). The manifest names the newest build on Google
/// Play (`"app_build"`, set with `tools/publish_content.py --app-build`)
/// and on the App Store (`"ios_build"`, `--ios-build`); an older app
/// offers the update on launch.
library;

/// This app's build number: the "+N" of `version` in pubspec.yaml. A test
/// keeps the two equal, so bump both together.
const int appBuild = 11;

/// Whether [latest] (from the manifest, null when unknown) is newer than
/// [current].
bool updateAvailable(int? latest, {int current = appBuild}) =>
    latest != null && latest > current;
