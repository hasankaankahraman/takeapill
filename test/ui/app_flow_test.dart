import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeapill/bootstrap.dart';
import 'package:takeapill/core/db/app_database.dart';
import 'package:takeapill/core/notifications/notification_planner.dart';
import 'package:takeapill/core/notifications/notification_service.dart';
import 'package:takeapill/core/settings_store.dart';
import 'package:takeapill/features/schedule/domain/rule_codec.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';
import 'package:takeapill/ui/widgets.dart';

import '../helpers/fake_notifications.dart';

/// Gerçek fontlar: Ahem test fontuyla taşmalar gerçeği yansıtmaz.
Future<void> _loadFonts() async {
  Future<void> font(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  await font('PlusJakartaSans', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
      'assets/fonts/PlusJakartaSans-$w.ttf',
  ]);
}

void main() {
  late FakeNotifications fake;

  setUpAll(() async {
    // Her test kendi bellek içi DB'sini açar.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await _loadFonts();
  });
  setUp(() => fake = FakeNotifications()..install());
  tearDown(() => fake.uninstall());

  /// Karşılama ekranındaki görsel sürekli döndüğü için pumpAndSettle bitmez.
  Future<void> settle(WidgetTester t, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<AppDatabase> start(WidgetTester t, {AppDatabase? db}) async {
    t.view.physicalSize = const Size(1170, 2532); // iPhone, 390 × 844
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final database = db ?? AppDatabase(NativeDatabase.memory());
    // Drift sorguları gerçek zamanlayıcı ister; sahte zamanda beklemez.
    await t.pumpWidget((await t.runAsync(() => bootstrap(db: database)))!);
    await settle(t);
    return database;
  }

  /// Drift akışlarının kapanması zamanlayıcı bırakır; ağacı söküp bekle.
  Future<void> finish(WidgetTester t, AppDatabase db) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    await t.runAsync(db.close);
  }

  Future<AppDatabase> seeded(List<int> slotMinutes) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.setSetting(SettingKeys.onboarded, '1');
    await db.addMedication(
      MedicationsCompanion.insert(name: 'Metformin'),
      encodeRule(
        DailyRule(
          startDate: DateTime(2026, 11, 1),
          slots: [for (final m in slotMinutes) DoseSlot.fixed(m)],
        ),
      ),
    );
    return db;
  }

  testWidgets('karşılama → ilaç ekle → işaretle → sil', (t) async {
    await withClock(Clock.fixed(DateTime(2026, 11, 2, 7, 30)), () async {
      final db = await start(t);

      // Karşılama ve izin; ad boş, hatırlatma şekli varsayılanda (bildirim).
      for (var i = 0; i < 5; i++) {
        await t.tap(find.text('Devam'));
        await settle(t);
      }
      await t.tap(find.text('Başla ve bildirimlere izin ver'));
      await settle(t);
      expect(
        fake.calls.map((c) => c.method),
        contains('requestNotificationsPermission'),
      );
      expect((await t.runAsync(db.loadNotificationPrefs))!.callMode, isFalse);
      expect(find.text('Bugün için planlı ilaç yok.'), findsOneWidget);

      // Form, adım adım: boş adla ilerlenmez
      await t.tap(find.text('İlk ilacını ekle'));
      await settle(t);
      expect(find.text('Hangi ilaç?'), findsOneWidget);
      await t.tap(find.text('Devam'));
      await settle(t);
      expect(find.text('İlaç adı gerekli'), findsOneWidget);
      expect(find.text('Hangi ilaç?'), findsOneWidget);

      await t.enterText(find.byKey(const ValueKey('name')), 'Metformin');
      await settle(t);
      expect(find.text('İlaç adı gerekli'), findsNothing);
      await t.tap(find.text('Kapsül'));
      await t.tap(find.text('Devam'));
      await settle(t);

      // Doz: önizleme seçilen formu ve dozu gösterir
      await t.enterText(find.byKey(const ValueKey('amount')), '500');
      await settle(t);
      expect(find.text('Kapsül · 500 mg'), findsOneWidget);
      await t.tap(find.text('Devam'));
      await settle(t);

      // Zamanlama: saat seçici iki platformda aynı panel
      expect(find.text('Ne zaman?'), findsOneWidget);
      await t.tap(find.text('08:00'));
      await settle(t);
      expect(find.text('Tamam'), findsOneWidget);
      await t.tap(find.text('Akşam'));
      await settle(t);
      expect(find.text('19:00'), findsWidgets);
      await t.tap(find.text('Sabah'));
      await settle(t);
      await t.tap(find.text('Tamam'));
      await settle(t);
      expect(find.text('08:00'), findsOneWidget);

      // Geri tuşu önceki adıma döner, değerler korunur
      await t.tap(find.byTooltip('Geri'));
      await settle(t);
      expect(find.text('Kapsül · 500 mg'), findsOneWidget);
      await t.tap(find.text('Devam'));
      await settle(t);
      await t.tap(find.text('Devam'));
      await settle(t);

      // Tarih seçici Türkçe
      await t.tap(find.text('Başlangıç'));
      await settle(t);
      expect(find.text('İptal'), findsOneWidget);
      await t.tap(find.text('İptal'));
      await settle(t);

      await t.tap(find.text('Kaydet'));
      await settle(t);
      final saved = await t.runAsync(db.activeSchedules);
      expect(saved!.single.$1.form, 'capsule');
      expect(saved.single.$1.strength, '500 mg');

      // Bugün: 08:00 dozu sıradaki, 30 dk kaldı; bildirimleri kuruldu
      expect(find.text('Metformin'), findsOneWidget);
      expect(find.text('30 dk'), findsOneWidget);
      expect(fake.titles, contains('İlaç zamanı: Metformin'));

      await t.tap(find.text('Aldım'));
      await settle(t);
      expect(find.text('Bugünlük tamam'), findsOneWidget);
      expect(find.text('Alındı'), findsOneWidget);

      // Geri al
      await t.tap(find.text('Alındı'));
      await settle(t);
      expect(find.text('Güne başlayalım'), findsOneWidget);

      // İlaçlar listesi ve kaydırarak silme
      await t.tap(find.text('İlaçlar'));
      await settle(t);
      expect(find.text('Günde 1 kez'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      await t.drag(find.text('Metformin 500 mg'), const Offset(-500, 0));
      await settle(t);
      await t.tap(find.text('Sil'));
      await settle(t);
      expect(find.text('Henüz ilaç eklenmedi.'), findsOneWidget);
      expect(await t.runAsync(db.activeSchedules), isEmpty);
      expect(fake.scheduled, isEmpty);

      await finish(t, db);
    });
  });

  testWidgets(
    'karşılamada girilen ad selamlamada ve bildirimlerde kullanılır',
    (t) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 2, 7, 30)), () async {
        final db = await start(t);
        for (var i = 0; i < 3; i++) {
          await t.tap(find.text('Devam'));
          await settle(t);
        }
        expect(find.text('Sana nasıl seslenelim?'), findsOneWidget);
        await t.enterText(find.byKey(const ValueKey('userName')), '  Zeynep ');
        await settle(t);
        // Görseldeki bildirim önizlemesi yazıldıkça güncellenir.
        expect(find.text('Zeynep, ilaç vaktin geldi'), findsOneWidget);
        for (var i = 0; i < 2; i++) {
          await t.tap(find.text('Devam'));
          await settle(t);
        }
        expect(find.text('Hazırsan başlayalım, Zeynep.'), findsOneWidget);
        await t.tap(find.text('Başla ve bildirimlere izin ver'));
        await settle(t);
        expect(await t.runAsync(db.loadUserName), 'Zeynep');
        expect(find.text('Günaydın, Zeynep'), findsOneWidget);
        await finish(t, db);
      });
    },
  );

  testWidgets('Ayarlar\'dan silinen adla genel başlık ve bildirimler', (
    t,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 11, 2, 7, 30)), () async {
      final db = await t.runAsync(() async {
        final db = await seeded([8 * 60]);
        await db.saveUserName('Zeynep');
        await syncNotifications(db);
        return db;
      }) as AppDatabase;
      await start(t, db: db);
      expect(find.text('Günaydın, Zeynep'), findsOneWidget);
      expect(fake.titles, contains('Zeynep, ilaç vaktin geldi'));

      await t.tap(find.text('Ayarlar'));
      await settle(t);
      await t.enterText(find.byKey(const ValueKey('userName')), '');
      await settle(t, 12);
      expect(await t.runAsync(db.loadUserName), isNull);
      expect(fake.titles, contains('İlaç zamanı: Metformin'));

      await t.tap(find.text('Bugün').last);
      await settle(t);
      expect(
        find.descendant(
          of: find.byType(PageHeader),
          matching: find.text('Bugün'),
        ),
        findsOneWidget,
      );
      await finish(t, db);
    });
  });

  testWidgets('karşılamada alarm seçilir, Ayarlar\'dan kapatılır', (t) async {
    final db = await start(t);
    for (var i = 0; i < 4; i++) {
      await t.tap(find.text('Devam'));
      await settle(t);
    }
    expect(find.text('Nasıl hatırlatalım?'), findsOneWidget);
    await t.tap(find.text('Alarm'));
    await settle(t);
    await t.tap(find.text('Devam'));
    await settle(t);
    await t.tap(find.text('Başla ve bildirimlere izin ver'));
    await settle(t);
    expect((await t.runAsync(db.loadNotificationPrefs))!.callMode, isTrue);

    await t.tap(find.text('Ayarlar'));
    await settle(t);
    expect(find.textContaining('İlaç saatinde alarm çalar'), findsOneWidget);
    await t.tap(find.text('Hatırlatma şekli'));
    await settle(t);
    await t.tap(find.text('Bildirim').last);
    await settle(t);
    expect((await t.runAsync(db.loadNotificationPrefs))!.callMode, isFalse);
    expect(find.textContaining('İlaç saatinde alarm çalar'), findsNothing);
    await finish(t, db);
  });

  testWidgets(
    'alarm modunda tam ekran izni, ayarlara göndermeden önce anlatılır',
    (t) async {
      fake.fullScreenState = 'miui';
      final db = await start(t);
      for (var i = 0; i < 4; i++) {
        await t.tap(find.text('Devam'));
        await settle(t);
      }
      await t.tap(find.text('Alarm'));
      await settle(t);
      await t.tap(find.text('Devam'));
      await settle(t);
      await t.tap(find.text('Başla ve bildirimlere izin ver'));
      await settle(t);
      expect(find.text('Tam ekran alarm'), findsOneWidget);
      expect(
        fake.calls.map((c) => c.method),
        isNot(contains('openFullScreenSettings')),
      );
      await t.tap(find.text('Ayarları aç'));
      await settle(t);
      expect(
        fake.calls.map((c) => c.method),
        contains('openFullScreenSettings'),
      );
      await finish(t, db);
    },
  );

  testWidgets('alarmda "Aç" uygulamayı Bugün\'de açar', (t) async {
    await withClock(Clock.fixed(DateTime(2026, 11, 2, 8)), () async {
      final db = await t.runAsync(() async {
        final db = await seeded([8 * 60]);
        await db.saveNotificationPrefs(const NotificationPrefs(callMode: true));
        return db;
      }) as AppDatabase;
      await start(t, db: db);
      await t.tap(find.text('Ayarlar'));
      await settle(t);

      final payload = encodePayload(1, DateTime(2026, 11, 2, 8), call: true);
      await fake.respond(actionId: actionAnswer, payload: payload);
      await settle(t);
      expect(find.text('Metformin'), findsOneWidget);
      expect(find.text('Aldım'), findsOneWidget);
      await finish(t, db);
    });
  });

  testWidgets('tema tercihi kaydedilir ve açılışta uygulanır', (t) async {
    final db = await t.runAsync(() => seeded([8 * 60])) as AppDatabase;
    await start(t, db: db);
    await t.tap(find.text('Ayarlar'));
    await settle(t);
    await t.tap(find.text('Koyu'));
    await settle(t);
    Brightness brightness() =>
        Theme.of(t.element(find.byType(Scaffold).first)).brightness;
    expect(brightness(), Brightness.dark);
    expect(
      await t.runAsync(() => db.getSetting(SettingKeys.themeMode)),
      'dark',
    );

    // Yeniden açılış: ilk karede koyu tema. Önce eski akışlar kapansın.
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    await t.pumpWidget((await t.runAsync(() => bootstrap(db: db)))!);
    await t.pump();
    expect(brightness(), Brightness.dark);
    await finish(t, db);
  });

  testWidgets('bildirim izni kapalıysa Bugün\'de ve Ayarlar\'da uyarı', (
    t,
  ) async {
    fake.notificationsEnabled = false;
    final db = await t.runAsync(() => seeded([8 * 60])) as AppDatabase;
    await start(t, db: db);
    expect(find.textContaining('Bildirimler kapalı'), findsOneWidget);
    await t.tap(find.textContaining('Bildirimler kapalı'));
    await settle(t);
    expect(
      fake.calls.map((c) => c.method),
      contains('openAppNotificationSettings'),
    );
    await t.tap(find.text('Ayarlar'));
    await settle(t);
    expect(find.textContaining('Bildirimler kapalı'), findsOneWidget);
    await finish(t, db);
  });

  testWidgets('Android alarm izni, ayarlara göndermeden önce anlatılır', (
    t,
  ) async {
    fake.exactAlarmsAllowed = false;
    final db = await start(t);
    for (var i = 0; i < 5; i++) {
      await t.tap(find.text('Devam'));
      await settle(t);
    }
    await t.tap(find.text('Başla ve bildirimlere izin ver'));
    await settle(t);
    expect(find.text('Tam saatinde hatırlatma'), findsOneWidget);
    expect(
      fake.calls.map((c) => c.method),
      isNot(contains('requestExactAlarmsPermission')),
    );
    await t.tap(find.text('Ayarları aç'));
    await settle(t);
    expect(
      fake.calls.map((c) => c.method),
      contains('requestExactAlarmsPermission'),
    );
    expect(find.text('Bugün için planlı ilaç yok.'), findsOneWidget);
    await finish(t, db);
  });

  testWidgets('alarm izni kapalıysa ayarlarda uyarı görünür', (t) async {
    fake.exactAlarmsAllowed = false;
    final db = await t.runAsync(() => seeded([8 * 60])) as AppDatabase;
    await start(t, db: db);
    await t.tap(find.text('Ayarlar'));
    await settle(t);
    expect(find.textContaining('birkaç dakika gecikebilir'), findsOneWidget);
    await finish(t, db);
  });

  testWidgets('düzenlerken adım çubuğuyla atlanır, her adımdan kaydedilir', (
    t,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 11, 2, 7, 30)), () async {
      final db = await t.runAsync(() => seeded([8 * 60])) as AppDatabase;
      await start(t, db: db);
      await t.tap(find.text('İlaçlar'));
      await settle(t);
      await t.tap(find.text('Metformin'));
      await settle(t);
      expect(find.text('İlacı düzenle'), findsOneWidget);
      expect(find.text('Hangi ilaç?'), findsOneWidget);

      // İleri adıma doğrudan geçilir; saat değiştirilip üstten kaydedilir.
      await t.tap(find.text('Zamanlama'));
      await settle(t);
      expect(find.text('Ne zaman?'), findsOneWidget);
      await t.tap(find.text('08:00'));
      await settle(t);
      await t.tap(find.text('Gece'));
      await settle(t);
      await t.tap(find.text('Tamam'));
      await settle(t);
      await t.tap(find.text('Kaydet').first);
      await settle(t);

      expect(find.text('22:00'), findsOneWidget);
      final rule = decodeRule(
        (await t.runAsync(db.activeSchedules))!.single.$2,
      );
      expect((rule as DailyRule).slots.single.fixedMinutes, 22 * 60);
      await finish(t, db);
    });
  });

  testWidgets('saat ilerledikçe doz "Gecikti"ye döner', (t) async {
    var now = DateTime(2026, 11, 2, 7, 59, 30);
    await withClock(Clock(() => now), () async {
      final db = await t.runAsync(() => seeded([8 * 60])) as AppDatabase;
      await start(t, db: db);
      expect(find.text('Şimdi'), findsOneWidget);
      expect(find.text('Gecikti'), findsNothing);

      now = DateTime(2026, 11, 2, 8, 1);
      await t.pump(const Duration(seconds: 31));
      await settle(t);
      expect(find.text('Gecikti'), findsOneWidget);
      expect(find.text('1 doz gecikti'), findsOneWidget);
      await finish(t, db);
    });
  });

  testWidgets('büyük yazı boyutunda sekmeler taşmaz', (t) async {
    await withClock(Clock.fixed(DateTime(2026, 11, 2, 7, 30)), () async {
      final db = await t.runAsync(
        () => seeded([8 * 60, 13 * 60, 20 * 60]),
      ) as AppDatabase;
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await start(t, db: db);
      for (final tab in ['İlaçlar', 'Geçmiş', 'Ayarlar', 'Bugün']) {
        await t.tap(find.text(tab).last);
        await settle(t);
      }
      await t.tap(find.byTooltip('İlaç ekle'));
      await settle(t);
      expect(find.text('Yeni ilaç'), findsOneWidget);
      await finish(t, db);
    });
  });
  testWidgets('başlık ve buton her sekmede aynı pikselde durur', (t) async {
    await withClock(Clock.fixed(DateTime(2026, 11, 2, 7, 30)), () async {
      // Boş liste: İlaçlar'da bilgi satırı yok; yine de başlık kaymamalı.
      for (final slots in [
        <int>[],
        [8 * 60],
      ]) {
        final db = await t.runAsync(() async {
          final db = await seeded(slots);
          if (slots.isEmpty) await db.deleteMedication(1);
          return db;
        }) as AppDatabase;
        await start(t, db: db);
        final titles = <Rect>[];
        final buttons = <Rect>[];
        for (final (tab, title) in [
          ('Bugün', 'Bugün'),
          ('İlaçlar', 'İlaçlarım'),
          ('Geçmiş', 'Geçmiş'),
          ('Ayarlar', 'Ayarlar'),
        ]) {
          await t.tap(find.text(tab).last);
          await settle(t);
          titles.add(
            t.getRect(
              find.descendant(
                of: find.byType(PageHeader),
                matching: find.text(title),
              ),
            ),
          );
          final add = find.byType(AddButton);
          if (add.evaluate().isNotEmpty) buttons.add(t.getRect(add));
        }
        for (final r in titles.skip(1)) {
          expect(r.topLeft, titles.first.topLeft);
        }
        expect(buttons, hasLength(2));
        expect(buttons.last, buttons.first);
        await finish(t, db);
      }
    });
  });
}
