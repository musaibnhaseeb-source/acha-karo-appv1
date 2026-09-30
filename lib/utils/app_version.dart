// User-facing label for THIS build — must match pubspec.yaml's version (1.3.1 -> 'v1.3.1') and the
// version_label used on the matching app_updates row. checkForUpdate() compares against this so
// someone already running this build is never prompted to "update" to it.
const String kAppVersionLabel = 'v1.3.1';
