import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 数据库口令的保险箱。
///
/// 口令本身随机生成并交由 Android Keystore（encryptedSharedPreferences）保护，
/// 绝不以明文形式写入磁盘或日志。
class SecureKeyStore {
  SecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _passwordKey = 'yuejingben_db_password';

  final FlutterSecureStorage _storage;

  Future<String> databasePassword() async {
    final existing = await _storage.read(key: _passwordKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _generatePassword();
    await _storage.write(key: _passwordKey, value: generated);
    return generated;
  }

  /// 32 字节随机数 → 64 位十六进制。
  String _generatePassword() {
    final rnd = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(rnd.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
