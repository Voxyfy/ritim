import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:ritim/core/providers.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';
import 'package:ritim/data/templates/study_template.dart';
import 'package:ritim/domain/focus_timer.dart';
import 'package:ritim/main.dart';

/// Bugün ekranının hız akışları: tek dokunuşla kayıt, geri alma, "Sıradaki"
/// kartından odak sayacı ve süreç ölümünden sonra sürmesi.
void main() {
  late RitimDatabase db;
  late int taskId;

  const lgs = StudyTemplate(
    id: 'lgs8',
    name: 'LGS · 8. Sınıf',
    group: 'Ortaokul',
    description: '',
    subjects: [
      TemplateSubject(
        name: 'Matematik',
        colorIndex: 1,
        topics: ['Çarpanlar ve Katlar'],
      ),
    ],
  );

  setUpAll(() async {
    Intl.defaultLocale = appLocale.toString();
    await initializeDateFormatting(appLocale.toString());
  });

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    await db.applyTemplate(lgs);
    await db.writeSetting(SettingKeys.tourSeen, 'true');
    // Şablon kendi planını da kurabiliyor; elle eklenen tek iş üzerinden
    // ilerlemek için önce bugünün listesini boşaltıyoruz.
    await db.delete(db.tasks).go();
    final topic = (await db.select(db.topics).get()).single;
    taskId = await db.addTask(
      title: topic.name,
      dueOn: DateTime.now(),
      topicId: topic.id,
      source: TaskSource.plan,
    );
  });
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const RitimApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Gövdenin sonunda çağrılmalı: bekleyen zamanlayıcı denetimi tearDown'dan
  // önce koşuyor ve sökülmemiş drift akışları ona takılıyor.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('daire → rozet tek dokunuşla kaydeder, "Geri al" iz bırakmaz', (
    tester,
  ) async {
    await pumpApp(tester);

    await tapVisible(tester, find.byKey(ValueKey('gorev-onay-$taskId')));
    // Daireye yeniden dokunmak kaydetmeden kapatır.
    await tapVisible(tester, find.byKey(ValueKey('gorev-onay-$taskId')));
    expect(find.byKey(ValueKey('hizli-kayit-$taskId-45')), findsNothing);
    expect(await db.select(db.studySessions).get(), isEmpty);

    await tapVisible(tester, find.byKey(ValueKey('gorev-onay-$taskId')));
    await tapVisible(tester, find.byKey(ValueKey('hizli-kayit-$taskId-45')));

    final sessions = await db.select(db.studySessions).get();
    expect(sessions.single.minutes, 45);
    expect((await db.taskById(taskId))!.done, isTrue);
    expect(find.text('45 dk kaydedildi'), findsOneWidget);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(await db.select(db.studySessions).get(), isEmpty);
    expect((await db.taskById(taskId))!.done, isFalse);
    expect(
      (await db.select(db.tasks).get()).where(
        (t) => t.source == TaskSource.review,
      ),
      isEmpty,
    );
    await disposeApp(tester);
  });

  testWidgets('Sıradaki → Başla → Bitir görevi çalışma olarak kapatır', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Sıradaki'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('siradaki-basla')));
    expect(find.text('Bitir'), findsOneWidget);
    expect(
      FocusTimer.decode(await db.readSetting(SettingKeys.focusTimer))?.taskId,
      taskId,
    );

    await tester.tap(find.text('Duraklat'));
    await tester.pumpAndSettle();
    expect(find.text('Devam'), findsOneWidget);
    expect(
      FocusTimer.decode(await db.readSetting(SettingKeys.focusTimer))!.isPaused,
      isTrue,
    );

    await tester.tap(find.text('Bitir'));
    await tester.pumpAndSettle();

    expect(await db.readSetting(SettingKeys.focusTimer), isNull);
    expect((await db.select(db.studySessions).get()).single.minutes, 1);
    expect((await db.taskById(taskId))!.done, isTrue);
    expect(find.text('1 dk kaydedildi'), findsOneWidget);
    // Bekleyen iş kalmadı: kart da gizlendi.
    expect(find.text('Sıradaki'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('kayıtlı sayaç açılışta çubuk olarak döner, Vazgeç siler', (
    tester,
  ) async {
    await db.writeSetting(
      SettingKeys.focusTimer,
      FocusTimer(
        taskId: taskId,
        startedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      ).encode(),
    );
    await pumpApp(tester);

    expect(find.textContaining('Odak sürüyor · 12:'), findsOneWidget);
    expect(find.text('Sıradaki'), findsNothing);

    await tapVisible(tester, find.byKey(const ValueKey('odak-cubugu')));
    expect(find.text('Bitir'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(await db.readSetting(SettingKeys.focusTimer), isNull);
    expect(await db.select(db.studySessions).get(), isEmpty);
    expect(find.text('Sıradaki'), findsOneWidget);
    await disposeApp(tester);
  });
}
