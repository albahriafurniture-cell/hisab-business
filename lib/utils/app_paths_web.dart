/// Web variant: Hive uses IndexedDB automatically, so the filesystem helpers
/// below are never called on web. They exist only so `AppPaths` has the same
/// interface as the io variant for conditional compilation.
class AppPaths {
  static const String packageName = 'com.hisab.business';

  static Future<Never> documentsDir() =>
      throw UnsupportedError('documentsDir is not used on web');

  static Future<Never> externalFilesDir() =>
      throw UnsupportedError('externalFilesDir is not used on web');

  static Future<Never> externalOrDocuments(String subdir) =>
      throw UnsupportedError('externalOrDocuments is not used on web');
}
