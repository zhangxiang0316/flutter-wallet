import 'dart:developer' as developer;

import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// 生物识别认证服务。
///
/// 提供指纹和面容 ID 等生物识别功能，用于快速解锁查看私钥和助记词。
class BiometricAuth {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// 检查设备是否支持生物识别。
  ///
  /// 返回 true 表示设备硬件支持生物识别（但不一定已注册）。
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      developer.log('canCheckBiometrics error: $e');
      return false;
    }
  }

  /// 检查设备是否已注册生物识别。
  ///
  /// 返回 true 表示设备支持且用户已注册至少一种生物识别方式。
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        developer.log('Device does not support biometrics');
        return false;
      }

      final availableBiometrics = await _auth.getAvailableBiometrics();
      developer.log('Available biometrics: $availableBiometrics');
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      developer.log('isAvailable error: $e');
      return false;
    }
  }

  /// 获取设备上已注册的生物识别类型列表。
  ///
  /// 可能包含：指纹、面容、虹膜等。
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      developer.log('getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// 执行生物识别认证。
  ///
  /// [localizedReason] 是向用户显示的原因文本，例如"验证身份以查看私钥"。
  ///
  /// 返回 true 表示认证成功，false 表示用户取消或认证失败。
  static Future<bool> authenticate({required String localizedReason}) async {
    try {
      developer.log('Starting biometric authentication...');
      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: true,
        ),
      );
      developer.log('Authentication result: $authenticated');
      return authenticated;
    } on Exception catch (e) {
      // 捕获具体的异常类型
      developer.log('Authentication exception: $e');

      // 检查是否是用户取消
      if (e.toString().contains('User canceled') ||
          e.toString().contains(auth_error.notAvailable) ||
          e.toString().contains(auth_error.notEnrolled)) {
        developer.log('User canceled or biometric not enrolled');
      }

      return false;
    } catch (e) {
      // 认证失败或用户取消，返回 false 不抛异常
      developer.log('Authentication error: $e');
      return false;
    }
  }
}
