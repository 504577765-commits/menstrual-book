import 'package:flutter/foundation.dart';

import '../../domain/entities/cycle.dart';
import '../../domain/entities/cycle_day.dart';
import '../database/app_database.dart';

/// 经期记录仓储。所有写操作均使用参数绑定，防止 SQL 注入。
class CycleRepository {
  CycleRepository(this._db);

  final AppDatabase _db;

  Future<List<Cycle>> allCycles() async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableCycle,
      orderBy: 'start_date ASC',
    );
    final result = <Cycle>[];
    for (final row in rows) {
      try {
        result.add(_cycleFromMap(row));
      } catch (error) {
        // 单行损坏不应导致整个应用不可用：本应用无备份，
        // 用户仍需要看到其余数据，因此跳过坏行并记录日志。
        debugPrint('跳过损坏的经期记录 id=${row['id']}：$error');
      }
    }
    return result;
  }

  Future<Cycle?> cycleById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableCycle,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _cycleFromMap(rows.first);
  }

  /// 插入一条经期记录，返回自增 id。
  Future<int> insertCycle(Cycle cycle) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    return db.insert(AppDatabase.tableCycle, {
      'start_date': _dateKey(cycle.startDate),
      'end_date': cycle.endDate == null ? null : _dateKey(cycle.endDate!),
      'overall_flow': cycle.overallFlow,
      'overall_cramp': cycle.overallCramp,
      'note': cycle.note,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> updateCycle(Cycle cycle) async {
    if (cycle.id == null) return 0;
    final db = await _db.database;
    return db.update(
      AppDatabase.tableCycle,
      {
        'start_date': _dateKey(cycle.startDate),
        'end_date': cycle.endDate == null ? null : _dateKey(cycle.endDate!),
        'overall_flow': cycle.overallFlow,
        'overall_cramp': cycle.overallCramp,
        'note': cycle.note,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [cycle.id],
    );
  }

  Future<int> deleteCycle(int id) async {
    final db = await _db.database;
    return db.delete(
      AppDatabase.tableCycle,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 该周期下的每日详情。
  Future<List<CycleDay>> daysOfCycle(int cycleId) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableCycleDay,
      where: 'cycle_id = ?',
      whereArgs: [cycleId],
      orderBy: 'day_index ASC',
    );
    final result = <CycleDay>[];
    for (final row in rows) {
      try {
        result.add(_dayFromMap(row));
      } catch (error) {
        debugPrint('跳过损坏的每日详情 id=${row['id']}：$error');
      }
    }
    return result;
  }

  /// 写入或更新某天的详情（flow/cramp 为 null 表示清空）。
  ///
  /// 不用 ConflictAlgorithm.replace：replace 会先删后插，导致行 id 变化，
  /// 且与显式传入的 id 混合时行为难以预期。这里显式做 update-or-insert。
  Future<void> upsertDay(CycleDay day) async {
    final db = await _db.database;
    final dateKey = _dateKey(day.date);
    final values = <String, Object?>{
      'cycle_id': day.cycleId,
      'day_index': day.dayIndex,
      'date': dateKey,
      'flow_level': day.flowLevel,
      'cramp_level': day.crampLevel,
      'note': day.note,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final existing = await db.query(
      AppDatabase.tableCycleDay,
      columns: ['id'],
      where: 'cycle_id = ? AND date = ?',
      whereArgs: [day.cycleId, dateKey],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update(
        AppDatabase.tableCycleDay,
        values,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert(AppDatabase.tableCycleDay, values);
    }
  }

  /// 清空某天的详情。
  Future<int> deleteDay(int id) async {
    final db = await _db.database;
    return db.delete(
      AppDatabase.tableCycleDay,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Cycle _cycleFromMap(Map<String, Object?> m) => Cycle(
        id: m['id'] as int?,
        startDate: DateTime.parse(m['start_date'] as String),
        endDate: m['end_date'] == null ? null : DateTime.parse(m['end_date'] as String),
        overallFlow: (m['overall_flow'] as int?) ?? 1,
        overallCramp: (m['overall_cramp'] as int?) ?? 0,
        note: m['note'] as String?,
      );

  static CycleDay _dayFromMap(Map<String, Object?> m) => CycleDay(
        id: m['id'] as int?,
        cycleId: m['cycle_id'] as int,
        date: DateTime.parse(m['date'] as String),
        dayIndex: (m['day_index'] as int?) ?? 1,
        flowLevel: m['flow_level'] as int?,
        crampLevel: m['cramp_level'] as int?,
        note: m['note'] as String?,
      );
}
