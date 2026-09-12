import 'package:sqflite_sqlcipher/sqflite.dart';

import '../database/app_database.dart';

// 保留导出：既有调用方仍可从本文件引用 ReminderSettings。
export '../../domain/entities/reminder_settings.dart';

/// 键值型设置仓储。
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<String?> raw(String key) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableSettings,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setRaw(String key, String? value) async {
    final db = await _db.database;
    await db.insert(
      AppDatabase.tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> getBool(String key, {bool fallback = false}) async {
    final v = await raw(key);
    if (v == null) return fallback;
    return v == '1' || v.toLowerCase() == 'true';
  }

  Future<void> setBool(String key, bool value) => setRaw(key, value ? '1' : '0');

  Future<int> getInt(String key, {required int fallback}) async {
    final v = await raw(key);
    if (v == null) return fallback;
    return int.tryParse(v) ?? fallback;
  }

  Future<void> setInt(String key, int value) => setRaw(key, value.toString());

  Future<double> getDouble(String key, {required double fallback}) async {
    final v = await raw(key);
    if (v == null) return fallback;
    return double.tryParse(v) ?? fallback;
  }

  Future<void> setDouble(String key, double value) => setRaw(key, value.toString());
}

/// 设置项键名集中管理，避免拼写错误。
class SettingKeys {
  static const onboardingDone = 'onboarding_done';
  static const defaultCycleLen = 'default_cycle_len';
  static const defaultPeriodLen = 'default_period_len';
  static const lastKnownStart = 'last_known_start';

  static const remindPrePeriod = 'remind_pre_period';
  static const remindPrePeriodDays = 'remind_pre_period_days';
  static const remindPeriodStart = 'remind_period_start';
  static const remindFertile = 'remind_fertile';
  static const remindOvulation = 'remind_ovulation';
  static const remindHour = 'remind_hour';
  static const remindMinute = 'remind_minute';
  static const dndEnabled = 'dnd_enabled';
  static const dndStartHour = 'dnd_start_hour';
  static const dndEndHour = 'dnd_end_hour';

  static const lockEnabled = 'lock_enabled';
  static const autoLockSeconds = 'auto_lock_seconds';
  static const fontScale = 'font_scale';
  static const darkMode = 'dark_mode';
}
