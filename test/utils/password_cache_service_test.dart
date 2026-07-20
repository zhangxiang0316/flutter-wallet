import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/password_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'password_cache_enabled': true,
      'password_cache_expiry_minutes': 5,
    });
    PasswordCacheService.clearCache();
  });

  tearDown(PasswordCacheService.clearCache);

  test('isolates cached passwords by wallet ID', () async {
    await PasswordCacheService.cachePassword(
      walletId: 'wallet-a',
      password: 'password-a',
    );
    await PasswordCacheService.cachePassword(
      walletId: 'wallet-b',
      password: 'password-b',
    );

    expect(
      await PasswordCacheService.getCachedPassword('wallet-a'),
      'password-a',
    );
    expect(
      await PasswordCacheService.getCachedPassword('wallet-b'),
      'password-b',
    );
    expect(await PasswordCacheService.getCachedPassword('wallet-c'), isNull);
  });

  test('can clear one wallet without clearing another wallet', () async {
    await PasswordCacheService.cachePassword(
      walletId: 'wallet-a',
      password: 'password-a',
    );
    await PasswordCacheService.cachePassword(
      walletId: 'wallet-b',
      password: 'password-b',
    );

    PasswordCacheService.clearCache(walletId: 'wallet-a');

    expect(await PasswordCacheService.getCachedPassword('wallet-a'), isNull);
    expect(
      await PasswordCacheService.getCachedPassword('wallet-b'),
      'password-b',
    );
  });

  test('clears all wallet passwords when caching is disabled', () async {
    await PasswordCacheService.cachePassword(
      walletId: 'wallet-a',
      password: 'password-a',
    );

    await PasswordCacheService.setEnabled(false);

    expect(await PasswordCacheService.getCachedPassword('wallet-a'), isNull);
  });

  test('does not treat an empty wallet ID as a global clear', () async {
    await PasswordCacheService.cachePassword(
      walletId: 'wallet-a',
      password: 'password-a',
    );

    PasswordCacheService.clearCache(walletId: '  ');

    expect(
      await PasswordCacheService.getCachedPassword('wallet-a'),
      'password-a',
    );
  });

  test('ignores empty wallet IDs and passwords', () async {
    await PasswordCacheService.cachePassword(
      walletId: '',
      password: 'password-a',
    );
    await PasswordCacheService.cachePassword(
      walletId: 'wallet-a',
      password: '',
    );

    expect(await PasswordCacheService.getCachedPassword('wallet-a'), isNull);
  });
}
