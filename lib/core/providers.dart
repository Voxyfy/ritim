import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/photo_store.dart';
import '../data/templates/study_template.dart';
import '../domain/exam_scoring.dart';
import 'day_tracker.dart';
import 'notifications.dart';
/// Veritabanı uygulama başına bir kez oluşturulur, kapanışta da kapatılır.
/// Kalıcılığa dokunan her şeyi test etmenin yolu, bunu bellek içi bir
/// yürütücüyle geçersiz kılmaktır.
final databaseProvider = Provider<RitimDatabase>((ref) {
  final db = RitimDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Bildirim servisi. `main()` içinde uyandırılır; testlerde hazır olmadığı
/// için tüm çağrıları sessizce yutar.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// Hatırlatma tercihleri.
final reminderSettingsProvider = StreamProvider<ReminderSettings>(
  (ref) => ref.watch(databaseProvider).watchReminderSettings(),
);

/// Bekleyen tekrarlar; bildirimleri besler.
final upcomingReviewsProvider = StreamProvider<List<TaskItem>>(
  (ref) => ref.watch(databaseProvider).watchUpcomingReviews(),
);

/// Konu fotoğraflarının dosya deposu.
final photoStoreProvider = Provider<PhotoStore>((ref) => PhotoStore());

/// Bir konunun fotoğrafları, en yeniden eskiye.
final photosProvider = StreamProvider.family<List<TopicPhoto>, int>(
  (ref, topicId) => ref.watch(databaseProvider).watchPhotos(topicId),
);

final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => TemplateRepository(),
);

final templatesProvider = FutureProvider<List<StudyTemplate>>(
  (ref) => ref.watch(templateRepositoryProvider).load(),
);

final subjectsProvider = StreamProvider<List<Subject>>(
  (ref) => ref.watch(databaseProvider).watchSubjects(),
);

/// Ders kimliğine göre konu sayısı. İlk satır gelene kadar boştur; asenkron
/// duruma göre dallanmak yerine `?? 0` ile okuyun.
final topicCountsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(databaseProvider).watchTopicCounts(),
);

final topicsProvider = StreamProvider.family<List<Topic>, int>(
  (ref, subjectId) => ref.watch(databaseProvider).watchTopics(subjectId),
);

/// Ders kimliğine göre tamamlanmış konu sayısı; ilerleme halkalarını besler.
final completedTopicCountsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(databaseProvider).watchCompletedTopicCounts(),
);

/// Tek bir konunun çalışma toplamları.
final topicTotalsProvider = StreamProvider.family<TopicTotals, int>(
  (ref, topicId) => ref.watch(databaseProvider).watchTopicTotals(topicId),
);

/// Denemeler, en yeniden eskiye.
final mockExamsProvider = StreamProvider<List<MockExam>>(
  (ref) => ref.watch(databaseProvider).watchMockExams(),
);

/// Bir denemenin ders sonuçları.
final examScoresProvider = StreamProvider.family<List<SubjectScore>, int>(
  (ref, examId) => ref.watch(databaseProvider).watchExamScores(examId),
);

/// Bir konunun notları, en yeniden eskiye.
final topicNotesProvider = StreamProvider.family<List<TopicNote>, int>(
  (ref, topicId) => ref.watch(databaseProvider).watchTopicNotes(topicId),
);

/// Bir dersteki konuların not sayıları.
final noteCountsProvider = StreamProvider.family<Map<int, int>, int>(
  (ref, subjectId) => ref.watch(databaseProvider).watchNoteCounts(subjectId),
);

/// Bir konunun çalışma kayıtları, en yeniden eskiye.
final sessionsProvider = StreamProvider.family<List<StudySession>, int>(
  (ref, topicId) => ref.watch(databaseProvider).watchSessions(topicId),
);

/// Kesintisiz çalışma serisi (gün).
final streakProvider = StreamProvider<int>((ref) {
  ref.watch(currentDayProvider);
  return ref.watch(databaseProvider).watchStreak();
});

/// Son yedi günün günlük çalışma dakikaları.
final dailyMinutesProvider = StreamProvider<List<DailyMinutes>>((ref) {
  ref.watch(currentDayProvider);
  return ref.watch(databaseProvider).watchDailyMinutes();
});

/// Haftalık özet sayıları.
final weeklySummaryProvider = StreamProvider<WeeklySummary>((ref) {
  ref.watch(currentDayProvider);
  return ref.watch(databaseProvider).watchWeeklySummary();
});

/// Önümüzdeki iki haftanın planı, güne göre gruplanmış.
final upcomingDaysProvider = StreamProvider<List<PlannedDay>>((ref) {
  // Gün değişince plan da kaymalı: dünün "Bugün" başlığı bugüne geçmeli.
  ref.watch(currentDayProvider);
  return ref.watch(databaseProvider).watchUpcomingDays();
});

/// Son yedi günün ders bazlı çalışma dağılımı.
final subjectMinutesProvider = StreamProvider<List<SubjectMinutes>>((ref) {
  ref.watch(currentDayProvider);
  return ref.watch(databaseProvider).watchSubjectMinutes();
});

/// Konuların genel ilerlemesi.
final topicProgressProvider = StreamProvider<TopicProgress>(
  (ref) => ref.watch(databaseProvider).watchTopicProgress(),
);

/// Uygulamanın "bugün" dediği gün. Gece yarısında ve uygulama öne geldiğinde
/// tazeleniyor; zamana bağlı bütün sağlayıcılar bunu izliyor.
final currentDayProvider = StateNotifierProvider<DayTracker, DateTime>(
  (ref) => DayTracker(),
);

/// Bugünün listesi: bugüne planlanmış işler ve gecikmiş olanlar.
final todayTasksProvider = StreamProvider<List<TaskItem>>(
  (ref) => ref.watch(databaseProvider).watchTasksUpTo(
        ref.watch(currentDayProvider),
      ),
);
