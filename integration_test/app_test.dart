import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:takeapill/bootstrap.dart';
import 'package:takeapill/core/db/app_database.dart';
import 'package:takeapill/core/notifications/notification_planner.dart';
import 'package:takeapill/core/notifications/notification_service.dart';
import 'package:takeapill/core/settings_store.dart';
import 'package:takeapill/features/schedule/domain/rule_codec.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  /// Dışarıdan sürekli kare alan bir süreç çalışırken ekranın oturmasını bekler.
  Future<void> shot(WidgetTester t, String name) async {
    await settle(t, 2);
    // ignore: avoid_print
    print('SHOT $name ${DateTime.now().millisecondsSinceEpoch ~/ 1000}');
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> scrollTo(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(t, 2);
  }

  testWidgets('uçtan uca: ilaç ekle, bildirimler, işaretle, tema', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    await t.pumpWidget(await bootstrap(db: db));
    await settle(t);

    // --- Karşılama + izin ---
    expect(find.text('Take a Pill'), findsOneWidget);
    await shot(t, '10_welcome');
    for (var i = 0; i < 3; i++) {
      await t.tap(find.text('Devam'));
      await settle(t, 3);
    }
    await shot(t, '10b_welcome_last');
    await t.tap(find.text('Başla ve bildirimlere izin ver'));
    await settle(t, 10);
    expect(find.textContaining('planlı ilaç yok'), findsOneWidget);
    await shot(t, '11_today_empty');

    // --- Form ile ilaç ekle ---
    await t.tap(find.text('İlaçlar'));
    await settle(t);
    await t.tap(find.text('İlaç ekle'));
    await settle(t);

    // Boş kaydetmeyi doğrula
    await t.tap(find.text('Kaydet').last);
    await settle(t);
    expect(find.text('İlaç adı gerekli'), findsOneWidget);

    await t.enterText(
      find.widgetWithText(TextFormField, 'İlaç adı'),
      'Metformin',
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Doz / güç'),
      '500 mg',
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Ne için kullanılıyor?'),
      'Şeker',
    );
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);

    await scrollTo(t, find.text('Doz saati ekle'));
    await t.tap(find.text('Doz saati ekle'));
    await settle(t);
    await scrollTo(t, find.text('Hangi günler?'));

    // İlk dozun yemek ilişkisini "Tok karnına" yap
    await t.ensureVisible(find.text('Fark etmez').first);
    await settle(t, 2);
    await t.tap(find.text('Fark etmez').first);
    await settle(t);
    await t.tap(find.text('Tok karnına').last);
    await settle(t);
    await shot(t, '12_form');

    await t.tap(find.text('Kaydet').first);
    await settle(t, 10);
    expect(find.text('Metformin 500 mg'), findsOneWidget);
    await shot(t, '13_meds_list');

    // DB'ye doğru yazıldı mı
    final saved = await db.activeSchedules();
    expect(saved.length, 1);
    final rule = decodeRule(saved.single.$2) as DailyRule;
    expect(rule.slots.length, 2);
    expect(rule.slots.first.food, FoodRelation.fullStomach);

    // --- Bildirim planı: iOS 64 sınırı ---
    var pending = await NotificationService.pending();
    expect(
      pending.length,
      60,
      reason: '14 gün × 2 doz × 3 bildirim > 60, sınırlanmalı',
    );
    final ids = pending.map((e) => e.id).toSet();
    expect(ids.length, pending.length, reason: 'kimlikler benzersiz olmalı');

    // --- Gerçek zamanlı test ilacı: 2 dk sonra ---
    await db.saveNotificationPrefs(
      const NotificationPrefs(leadMinutes: 1, nagMinutes: 1, snoozeMinutes: 5),
    );
    final now = DateTime.now();
    final target = now.hour * 60 + now.minute + 2;
    expect(
      target < 24 * 60 - 5,
      isTrue,
      reason: 'gece yarısına yakın çalıştırma',
    );
    final medId = await db.addMedication(
      MedicationsCompanion.insert(
        name: 'TestPill',
        purpose: const Value('Bildirim testi'),
      ),
      encodeRule(
        DailyRule(
          startDate: DateTime(now.year, now.month, now.day),
          slots: [DoseSlot.fixed(target, food: FoodRelation.before)],
        ),
      ),
    );
    await syncNotifications(db);
    pending = await NotificationService.pending();
    final testPending = pending.where(
      (p) => p.title?.contains('TestPill') ?? false,
    );
    expect(
      testPending.length,
      greaterThanOrEqualTo(3),
      reason: 'önce + zamanında + tekrar bildirimi planlı olmalı',
    );
    expect(testPending.any((p) => p.title!.startsWith('Birazdan')), isTrue);
    expect(testPending.any((p) => p.title!.startsWith('İlaç zamanı')), isTrue);
    expect(testPending.any((p) => p.title!.startsWith('Aldın mı')), isTrue);
    // Android teslim edilmiş bildirimin payload'ını vermez; kimlikten bulunur.
    final payloadById = {for (final p in testPending) p.id: p.payload};

    // Bugün ekranında üç ilaç satırı
    await t.tap(find.text('Bugün'));
    await settle(t, 8);
    expect(find.text('TestPill'), findsOneWidget);
    expect(find.text('Metformin'), findsNWidgets(2));
    await shot(t, '14_today');

    // --- Bildirimin gerçekten teslim edilmesini bekle ---
    final deadline = DateTime.now().add(const Duration(seconds: 200));
    var delivered = <ActiveNotification>[];
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 5));
      await t.pump(const Duration(milliseconds: 100));
      delivered = await NotificationService.active();
      if (delivered.any((n) => n.title?.startsWith('İlaç zamanı') ?? false)) {
        break;
      }
    }
    final titles = delivered.map((n) => n.title).toList();
    // ignore: avoid_print
    print('TESLİM EDİLEN: $titles');
    expect(
      titles.any((x) => x?.startsWith('Birazdan: TestPill') ?? false),
      isTrue,
      reason: 'önceden haber bildirimi gelmedi: $titles',
    );
    expect(
      titles.any((x) => x?.startsWith('İlaç zamanı: TestPill') ?? false),
      isTrue,
      reason: 'zamanında bildirim gelmedi: $titles',
    );
    await shot(t, '15_after_delivery');

    // --- Bildirim butonu mantığı: Aldım ---
    final due = delivered.firstWhere(
      // Android başlıksız sistem bildirimleri de döndürebilir.
      (n) => n.title?.startsWith('İlaç zamanı') ?? false,
    );
    final payload = due.payload ?? payloadById[due.id];
    expect(payload, isNotNull);
    await handleNotificationAction(db, actionTaken, payload);
    await t.pump(const Duration(seconds: 1));
    final events = await db.doseEventsBetween(
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day + 1),
    );
    expect(events.length, 1);
    expect(events.single.medicationId, medId);
    expect(events.single.status, 'taken');
    pending = await NotificationService.pending();
    expect(
      pending.where(
        (p) => p.title!.contains('TestPill') && p.payload == payload,
      ),
      isEmpty,
      reason: 'alınan doz için bekleyen bildirim kalmamalı',
    );

    // Ertele mantığı: tek bir yeni bildirim planlar
    await handleNotificationAction(db, actionSnooze, payload);
    // Atla, alınmışı atlanmışa çevirir (çift kayıt yok)
    await handleNotificationAction(db, actionSkip, payload);
    final events2 = await db.doseEventsBetween(
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day + 1),
    );
    expect(events2.length, 1);
    expect(events2.single.status, 'skipped');

    await settle(t, 5);
    await shot(t, '16_today_after_actions');

    // --- Uygulama içi işaretleme: Aldım / Geri al ---
    await t.tap(find.byTooltip('Aldım').first);
    await settle(t, 6);
    expect(find.byTooltip('Geri al'), findsWidgets);
    await t.tap(find.byTooltip('Geri al').first);
    await settle(t, 6);

    // --- Geçmiş ---
    await t.tap(find.text('Geçmiş'));
    await settle(t, 8);
    expect(find.text('Uyum oranı'), findsOneWidget);
    await shot(t, '17_history');

    // --- Ayarlar + tema ---
    await t.tap(find.text('Ayarlar'));
    await settle(t, 6);
    await shot(t, '18_settings_system');
    Brightness current() =>
        Theme.of(t.element(find.byType(Scaffold).first)).brightness;

    await t.tap(find.text('Koyu'));
    await settle(t, 6);
    expect(current(), Brightness.dark);
    await shot(t, '19_dark');
    await t.tap(find.text('Açık'));
    await settle(t, 6);
    expect(current(), Brightness.light);
    await shot(t, '20_light');
    expect(await db.getSetting(SettingKeys.themeMode), 'light');

    // Önceden haber vermeyi kapat -> "Birazdan" bildirimi kalmaz
    await t.tap(find.text('1 dk').first); // ilk eşleşme: "Önceden haber ver"
    await settle(t, 3);
    await t.tap(find.text('Kapalı').last);
    await settle(t, 8);
    pending = await NotificationService.pending();
    expect(
      pending.any((p) => p.title!.startsWith('Birazdan')),
      isFalse,
      reason: 'önceden haber kapatılınca bu bildirimler silinmeli',
    );
    expect(pending, isNotEmpty);
    await shot(t, '21_settings_lead_off');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
