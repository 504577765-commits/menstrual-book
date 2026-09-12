import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// 应用锁服务。
///
/// 方案（v1.1 决策）：仅生物识别（指纹/面容），不可用时回退到手机系统锁屏凭据。
/// 不设独立的 App 密码，从根上消除「忘记密码导致数据永久锁死」的风险。
class LockService {
  LockService(this._auth);

  final LocalAuthentication _auth;

  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (error) {
      debugPrint('生物识别能力检测失败：$error');
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (error) {
      debugPrint('生物识别能力检测失败：$error');
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (error) {
      debugPrint('读取可用生物识别类型失败：$error');
      return const [];
    }
  }

  /// 生物识别优先；不可用时由系统弹窗回退到 PIN/图案/密码。
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (error) {
      debugPrint('生物识别验证失败：$error');
      return false;
    }
  }
}
