import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Storage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'keeps legacy getStorage behavior for missing and JSON values',
      () async {
        final storage = Storage();

        expect(await storage.getStorage('missing'), '');

        await storage.setStorage('map', {'name': 'wallet', 'index': 1});
        await storage.setStorage('list', ['bsc', 'solana']);

        expect(await storage.getStorage('map'), {'name': 'wallet', 'index': 1});
        expect(await storage.getStorage('list'), ['bsc', 'solana']);
      },
    );

    test('typed string methods do not JSON-decode plain values', () async {
      final storage = Storage();

      await storage.setString('raw_json_text', '{"enabled":true}');

      expect(await storage.getString('raw_json_text'), '{"enabled":true}');
      expect(await storage.getStorage('raw_json_text'), {'enabled': true});
    });

    test(
      'typed JSON methods return null for missing or mismatched values',
      () async {
        final storage = Storage();

        expect(await storage.getJsonList('missing'), isNull);
        expect(await storage.getJsonMap('missing'), isNull);

        await storage.setString('plain', 'hello');

        expect(await storage.getJsonList('plain'), isNull);
        expect(await storage.getJsonMap('plain'), isNull);
      },
    );

    test('typed JSON list and map methods round-trip values', () async {
      final storage = Storage();

      await storage.setJsonList('chains', [
        {'id': 'bsc'},
        {'id': 'solana'},
      ]);
      await storage.setJsonMap('settings', {'language': 'zh'});

      expect(await storage.getJsonList('chains'), [
        {'id': 'bsc'},
        {'id': 'solana'},
      ]);
      expect(await storage.getJsonMap('settings'), {'language': 'zh'});
    });
  });
}
