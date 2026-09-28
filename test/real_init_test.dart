import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_business/data/hive_service.dart';
import 'package:hisab_business/utils/app_paths.dart';

/// Exercises the REAL startup path (no bypass): AppPaths.documentsDir()
/// + HiveService.init(), exactly as main() calls it on a device.
void main() {
  test('real HiveService.init() completes', () async {
    final dir = await AppPaths.documentsDir();
    // ignore: avoid_print
    print('documentsDir resolved to: ${dir.path}');
    await HiveService.init();
    // ignore: avoid_print
    print('init OK, settings keys: ${HiveService.settings.keys.toList()}');
    // ignore: avoid_print
    print('firstRun=${HiveService.firstRun} language=${HiveService.language}');
  });
}
