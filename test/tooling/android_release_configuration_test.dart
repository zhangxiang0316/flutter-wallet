import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release build never falls back to the debug signing config', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('isReleaseArtifactTask'));
    expect(gradle, contains('gradle.taskGraph.whenReady'));
    expect(gradle, contains('missingReleaseSigningProperties'));
    expect(gradle, contains('releaseStoreFile?.isFile'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
  });

  test('committed release certificate fingerprint is well formed', () {
    final properties = _readProperties(
      File('android/release-signing.properties'),
    );

    expect(properties['applicationId'], 'com.zx.wallet');
    expect(properties['certificateSha256'], matches(RegExp(r'^[0-9A-F]{64}$')));
  });

  test('APK and AAB scripts share mandatory release verification', () {
    final common = File('scripts/android_release_common.sh').readAsStringSync();
    final apk = File('scripts/build_android.sh').readAsStringSync();
    final aab = File('scripts/build_android_bundle.sh').readAsStringSync();

    for (final script in [apk, aab]) {
      expect(
        script,
        contains(r'source "$SCRIPT_DIR/android_release_common.sh"'),
      );
      expect(script, contains('require_android_release_signing'));
      expect(script, contains('write_release_checksum'));
    }
    expect(apk, contains('verify_android_apk'));
    expect(aab, contains('verify_android_aab'));
    expect(common, contains('apksigner'));
    expect(common, contains('jarsigner'));
    expect(common, contains('keytool'));
    expect(common, contains('verify_release_build_metadata'));
  });
}

Map<String, String> _readProperties(File file) {
  return {
    for (final line in file.readAsLinesSync())
      if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
        line.substring(0, line.indexOf('=')).trim(): line
            .substring(line.indexOf('=') + 1)
            .trim(),
  };
}
