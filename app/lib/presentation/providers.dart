import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:local_auth/local_auth.dart';

import '../data/database/app_database.dart';
import '../data/repositories/cycle_repository.dart';
import '../data/repositories/daily_record_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/secure/secure_key_store.dart';
import '../services/lock_service.dart';
import '../services/notification_service.dart';
import 'state/app_state.dart';

final secureKeyStoreProvider = Provider<SecureKeyStore>((ref) {
  return SecureKeyStore();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final store = ref.watch(secureKeyStoreProvider);
  return AppDatabase(store.databasePassword());
});

final cycleRepositoryProvider = Provider<CycleRepository>((ref) {
  return CycleRepository(ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final dailyRecordRepositoryProvider = Provider<DailyRecordRepository>((ref) {
  return DailyRecordRepository(ref.watch(appDatabaseProvider));
});

final notificationPluginProvider = Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(notificationPluginProvider));
});

final lockServiceProvider = Provider<LockService>((ref) {
  return LockService(LocalAuthentication());
});

final appStateProvider = ChangeNotifierProvider<AppState>((ref) {
  return AppState(
    cycleRepo: ref.watch(cycleRepositoryProvider),
    settingsRepo: ref.watch(settingsRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
    dailyRepo: ref.watch(dailyRecordRepositoryProvider),
  );
});
