import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// 本地加密数据库（SQLCipher / AES-256）。
/// 数据库口令本身由 Android Keystore 保护（见 SecureKeyStore），不落明文。
class AppDatabase {
  AppDatabase(this._passwordFuture);

  final Future<String> _passwordFuture;

  static const String dbFileName = 'yuejingben.db';
  static const int schemaVersion = 2;

  static const String tableCycle = 'cycle';
  static const String tableCycleDay = 'cycle_day';
  static const String tableSettings = 'settings';
  static const String tableIntimacy = 'intimacy';
  static const String tableSymptom = 'symptom';
  static const String tableMood = 'mood';
  static const String tableWeight = 'weight';
  static const String tableDischarge = 'discharge';
  static const String tableDiary = 'diary';

  /// v2 新增的六张记录表（爱爱/症状/心情/体重/白带/日记）。
  static const List<String> _extraTableSql = [
    '''
    CREATE TABLE IF NOT EXISTS $tableIntimacy (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      protected INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE IF NOT EXISTS $tableSymptom (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      symptom INTEGER NOT NULL,
      severity INTEGER NOT NULL DEFAULT 0,
      note TEXT,
      updated_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE IF NOT EXISTS $tableMood (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      score INTEGER NOT NULL,
      emotions TEXT,
      note TEXT,
      updated_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE IF NOT EXISTS $tableWeight (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL UNIQUE,
      kg REAL NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE IF NOT EXISTS $tableDischarge (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL UNIQUE,
      status INTEGER NOT NULL,
      amount INTEGER NOT NULL DEFAULT 1,
      smell INTEGER NOT NULL DEFAULT 0,
      itch INTEGER NOT NULL DEFAULT 0,
      note TEXT,
      updated_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE IF NOT EXISTS $tableDiary (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      content TEXT NOT NULL,
      images TEXT,
      updated_at TEXT NOT NULL
    )''',
  ];

  Database? _db;

  /// 正在进行的打开操作（单飞护栏）：并发调用复用同一个 future，
  /// 避免重复 openDatabase 引发竞态；失败后自动重置以便重试。
  Future<Database>? _opening;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    final pending = _opening;
    if (pending != null) return pending;
    final fut = _open();
    _opening = fut;
    try {
      final db = await fut;
      _db = db;
      return db;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, dbFileName);
    final password = await _passwordFuture;

    final db = await openDatabase(
      path,
      password: password,
      version: schemaVersion,
      // sqflite_sqlcipher 对 onConfigure 阶段执行 PRAGMA 有额外限制
      //（execute/rawQuery 均可能抛 "query or rawQuery methods only"），
      // 因此把 PRAGMA 全部移到 onOpen 阶段执行，并做容错：
      // 即使 PRAGMA 失败也只降级（如并发写无等待），不影响数据库打开。
      onConfigure: (_) async {},
      onOpen: (db) async {
        try {
          // 外键约束：cycle_day 的 ON DELETE CASCADE 依赖它，
          // 否则删除经期后会残留孤儿行。
          await db.rawQuery('PRAGMA foreign_keys = ON');
          // 写入等待：SQLCipher 在并发/残留写锁时默认立即报 locked，
          // 设超时让被锁住的写入等待释放，避免首次写入偶发失败。
          await db.rawQuery('PRAGMA busy_timeout = 10000');
        } catch (_) {
          // 容错：PRAGMA 失败不阻断数据库打开。
        }
      },
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute('''
          CREATE TABLE $tableCycle (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_date TEXT NOT NULL,
            end_date TEXT,
            overall_flow INTEGER NOT NULL DEFAULT 1,
            overall_cramp INTEGER NOT NULL DEFAULT 0,
            note TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        batch.execute('''
          CREATE TABLE $tableCycleDay (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cycle_id INTEGER NOT NULL,
            day_index INTEGER NOT NULL,
            date TEXT NOT NULL,
            flow_level INTEGER,
            cramp_level INTEGER,
            note TEXT,
            updated_at TEXT NOT NULL,
            UNIQUE(cycle_id, date),
            FOREIGN KEY (cycle_id) REFERENCES $tableCycle(id) ON DELETE CASCADE
          )
        ''');
        batch.execute('''
          CREATE TABLE $tableSettings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        batch.execute(
          'CREATE INDEX idx_cycle_start ON $tableCycle(start_date)',
        );
        for (final sql in _extraTableSql) {
          batch.execute(sql);
        }
        await batch.commit(noResult: true);
      },
      // v1 → v2：为老用户原地新增六张记录表（旧表不动，数据不丢）。
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final sql in _extraTableSql) {
            await db.execute(sql);
          }
        }
      },
    );
    _db = db;
    return db;
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) await db.close();
    _db = null;
  }
}
