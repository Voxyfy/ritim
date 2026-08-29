import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/domain/weekly_planner.dart';
/// Planlayıcının saf karar mantığı.
void main() {
  /// Belirli bir hafta gününe denk gelen sabit bir başlangıç: testin haftanın
  /// hangi gününde koşturulduğuna bağlı olmaması için.
  final pazartesi = DateTime(2026, 8, 31);

  List<PlannableTopic> topics(Map<int, int> countBySubject) {
    final list = <PlannableTopic>[];
    var id = 1;
    countBySubject.forEach((subjectId, count) {
      for (var i = 0; i < count; i++) {
        list.add(
          PlannableTopic(id: id++, subjectId: subjectId, position: i),
        );
      }
    });
    return list;
  }

  test('konular seçilen günlere, günde belirtilen sayıda dağılır', () {
    final plan = WeeklyPlanner.build(
      topics: topics({1: 6}),
      weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
      perDay: 2,
      from: pazartesi,
    );

    expect(plan, hasLength(6));
    expect(plan[0].dueOn, DateTime(2026, 8, 31));
    expect(plan[1].dueOn, DateTime(2026, 8, 31));
    expect(plan[2].dueOn, DateTime(2026, 9, 2));
    expect(plan[4].dueOn, DateTime(2026, 9, 4));
  });

  test('aynı güne aynı dersten üst üste konu düşmez', () {
    final plan = WeeklyPlanner.build(
      topics: topics({1: 3, 2: 3}),
      weekdays: {DateTime.monday},
      perDay: 2,
      from: pazartesi,
      weeks: 1,
    );

    // İlk gün: 1. dersten bir, 2. dersten bir.
    expect(plan[0].topicId, 1);
    expect(plan[1].topicId, 4);
  });

  test('konu sayısı slot sayısını aşarsa fazlası plana girmez', () {
    final plan = WeeklyPlanner.build(
      topics: topics({1: 20}),
      weekdays: {DateTime.monday},
      perDay: 2,
      from: pazartesi,
    );

    expect(plan, hasLength(2));
  });

  test('ders içinde müfredat sırası korunur', () {
    final plan = WeeklyPlanner.build(
      topics: topics({1: 4}),
      weekdays: {DateTime.monday, DateTime.tuesday},
      perDay: 2,
      from: pazartesi,
    );

    expect(plan.map((p) => p.topicId), [1, 2, 3, 4]);
  });

  test('bugün seçili günlerdense plan bugünden başlar', () {
    final plan = WeeklyPlanner.build(
      topics: topics({1: 1}),
      weekdays: {DateTime.monday},
      perDay: 1,
      from: pazartesi,
    );

    expect(plan.single.dueOn, DateTime(2026, 8, 31));
  });

  test('boş girdiler boş plan üretir', () {
    expect(
      WeeklyPlanner.build(
        topics: const [],
        weekdays: {DateTime.monday},
        perDay: 2,
        from: pazartesi,
      ),
      isEmpty,
    );
    expect(
      WeeklyPlanner.build(
        topics: topics({1: 3}),
        weekdays: const {},
        perDay: 2,
        from: pazartesi,
      ),
      isEmpty,
    );
    expect(
      WeeklyPlanner.build(
        topics: topics({1: 3}),
        weekdays: {DateTime.monday},
        perDay: 0,
        from: pazartesi,
      ),
      isEmpty,
    );
  });

  test('aynı girdi her zaman aynı planı verir', () {
    List<PlannedItem> run() => WeeklyPlanner.build(
          topics: topics({1: 4, 2: 4}),
          weekdays: {DateTime.monday, DateTime.thursday},
          perDay: 2,
          from: pazartesi,
        );

    expect(
      run().map((p) => '${p.topicId}@${p.dueOn}'),
      run().map((p) => '${p.topicId}@${p.dueOn}'),
    );
  });

  test('günde en fazla dört konu; üstü kırpılır', () {
    final plan = WeeklyPlanner.build(
      topics: topics({1: 10}),
      weekdays: {DateTime.monday},
      perDay: 9,
      from: pazartesi,
    );

    expect(plan, hasLength(WeeklyPlanner.maxPerDay));
  });
}
