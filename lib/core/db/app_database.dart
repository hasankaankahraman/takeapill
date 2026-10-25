import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Medications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get form => text().withDefault(const Constant('pill'))();
  TextColumn get strength => text().withDefault(const Constant(''))();
  TextColumn get purpose => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get color => integer().withDefault(const Constant(0xFF3B82F6))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Kural JSON olarak saklanır (bkz. rule_codec.dart).
class Schedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicationId =>
      integer().references(Medications, #id, onDelete: KeyAction.cascade)();
  TextColumn get ruleJson => text()();
}

/// Her planlı doz için bir kayıt; yalnızca kullanıcı bir işlem yapınca oluşur.
class DoseEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicationId =>
      integer().references(Medications, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get scheduledAt => dateTime()();
  // taken | skipped
  TextColumn get status => text()();
  DateTimeColumn get actedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {medicationId, scheduledAt},
  ];
}

/// Basit anahtar-değer ayarlar (yemek saatleri, bildirim tercihleri).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Medications, Schedules, DoseEvents, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // --- İlaçlar ---
  Stream<List<Medication>> watchMedications() =>
      (select(medications)
            ..where((m) => m.archived.equals(false))
            ..orderBy([(m) => OrderingTerm.asc(m.name)]))
          .watch();

  Future<int> addMedication(MedicationsCompanion med, String ruleJson) =>
      transaction(() async {
        final id = await into(medications).insert(med);
        await into(schedules).insert(
          SchedulesCompanion.insert(medicationId: id, ruleJson: ruleJson),
        );
        return id;
      });

  Future<void> updateMedication(
    int id,
    MedicationsCompanion med,
    String ruleJson,
  ) => transaction(() async {
    await (update(medications)..where((m) => m.id.equals(id))).write(med);
    await (delete(schedules)..where((s) => s.medicationId.equals(id))).go();
    await into(
      schedules,
    ).insert(SchedulesCompanion.insert(medicationId: id, ruleJson: ruleJson));
  });

  Future<void> deleteMedication(int id) =>
      (delete(medications)..where((m) => m.id.equals(id))).go();

  /// Arşivlenmemiş tüm ilaçlar ve kuralları.
  Future<List<(Medication, String)>> activeSchedules() async {
    final q = select(medications).join([
      innerJoin(schedules, schedules.medicationId.equalsExp(medications.id)),
    ])..where(medications.archived.equals(false));
    final rows = await q.get();
    return [
      for (final r in rows)
        (r.readTable(medications), r.readTable(schedules).ruleJson),
    ];
  }

  Future<(Medication, String)?> medicationWithRule(int id) async {
    final med = await (select(
      medications,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    if (med == null) return null;
    final sch = await (select(
      schedules,
    )..where((s) => s.medicationId.equals(id))).getSingle();
    return (med, sch.ruleJson);
  }

  /// İlaç, kural, doz kaydı veya ayar değişince tetiklenir.
  Stream<void> watchAnyChange() => customSelect(
    'SELECT 1',
    readsFrom: {medications, schedules, doseEvents, settings},
  ).watch().map((_) {});

  // --- Doz kayıtları ---
  Future<void> recordDose(
    int medicationId,
    DateTime scheduledAt,
    String status,
  ) {
    final row = DoseEventsCompanion.insert(
      medicationId: medicationId,
      scheduledAt: scheduledAt,
      status: status,
    );
    // Çakışma birincil anahtarda değil (ilaç, zaman) benzersiz çiftinde olur.
    return into(doseEvents).insert(
      row,
      onConflict: DoUpdate(
        (_) => DoseEventsCompanion(
          status: Value(status),
          actedAt: Value(DateTime.now()),
        ),
        target: [doseEvents.medicationId, doseEvents.scheduledAt],
      ),
    );
  }

  Future<void> clearDose(int medicationId, DateTime scheduledAt) =>
      (delete(doseEvents)..where(
            (e) =>
                e.medicationId.equals(medicationId) &
                e.scheduledAt.equals(scheduledAt),
          ))
          .go();

  Stream<List<DoseEvent>> watchDoseEvents(DateTime from, DateTime to) =>
      (select(doseEvents)..where(
            (e) =>
                e.scheduledAt.isBiggerOrEqualValue(from) &
                e.scheduledAt.isSmallerThanValue(to),
          ))
          .watch();

  Future<List<DoseEvent>> doseEventsBetween(DateTime from, DateTime to) =>
      (select(doseEvents)..where(
            (e) =>
                e.scheduledAt.isBiggerOrEqualValue(from) &
                e.scheduledAt.isSmallerThanValue(to),
          ))
          .get();

  // --- Ayarlar ---
  Future<String?> getSetting(String key) async {
    final row = await (select(
      settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) => into(settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

LazyDatabase _open() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  return NativeDatabase.createInBackground(
    File(p.join(dir.path, 'takeapill.sqlite')),
  );
});
