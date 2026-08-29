import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/domain/review_ladder.dart';
/// Tekrar merdiveninin kuralları. Motorun geri kalanı veritabanı işi;
/// karar mantığının tamamı burada ve saf.
void main() {
  test('hiç tekrar edilmemiş konunun ilk tekrarı ertesi gündür', () {
    final plan = ReviewLadder.planNext(lastStep: ReviewLadder.noReviewYet);

    expect(plan.step, 0);
    expect(plan.days, 1);
  });

  test('soru verisi yoksa merdiven sabit ilerler', () {
    expect(ReviewLadder.planNext(lastStep: 0).days, 3);
    expect(ReviewLadder.planNext(lastStep: 1).days, 7);
    expect(ReviewLadder.planNext(lastStep: 2).days, 21);
    expect(ReviewLadder.planNext(lastStep: 3).days, 30);
  });

  test('yüksek doğru oranı bir üst basamağa çıkarır', () {
    final plan = ReviewLadder.planNext(lastStep: 1, accuracy: 0.9);

    expect(plan.step, 2);
    expect(plan.days, 7);
  });

  test('orta doğru oranında basamak korunur, aralık uzamaz', () {
    final plan = ReviewLadder.planNext(lastStep: 2, accuracy: 0.7);

    expect(plan.step, 2);
    expect(plan.days, 7);
  });

  test('düşük doğru oranı bir basamak geriye düşürür', () {
    final plan = ReviewLadder.planNext(lastStep: 2, accuracy: 0.4);

    expect(plan.step, 1);
    expect(plan.days, 3);
  });

  test('ilk basamakta zorlanan öğrenci eksiye düşmez', () {
    final plan = ReviewLadder.planNext(lastStep: 0, accuracy: 0.2);

    expect(plan.step, 0);
    expect(plan.days, 1);
  });

  test('merdiven bittikten sonra aylık ritme oturur', () {
    expect(ReviewLadder.intervalForStep(4), 30);
    expect(ReviewLadder.intervalForStep(9), 30);
    expect(ReviewLadder.planNext(lastStep: 3, accuracy: 0.95).days, 30);
  });

  test('sınır değerler: %85 çıkarır, %60 korur', () {
    expect(ReviewLadder.planNext(lastStep: 1, accuracy: 0.85).step, 2);
    expect(ReviewLadder.planNext(lastStep: 1, accuracy: 0.6).step, 1);
    expect(ReviewLadder.planNext(lastStep: 1, accuracy: 0.599).step, 0);
  });
}
