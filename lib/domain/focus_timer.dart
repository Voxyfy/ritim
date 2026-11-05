import 'dart:convert';
import 'dart:math' as math;

/// Süren bir odak oturumu: hangi görev, ne zaman başladı, ne kadar duraklandı.
///
/// Geçen süre bir sayaçta biriktirilmiyor, her okumada duvar saatinden
/// hesaplanıyor. Uygulama arka plana atıldığında ya da sistem süreci
/// öldürdüğünde çalışan bir sayaç durur; başlangıç anı ve duraklama toplamı
/// ise ayarlar tablosunda kalır ve açılışta süre doğru çıkar.
class FocusTimer {
  const FocusTimer({
    required this.taskId,
    required this.startedAt,
    this.pausedMs = 0,
    this.pausedAt,
  });

  final int taskId;
  final DateTime startedAt;

  /// Kapanmış duraklamaların toplamı (milisaniye).
  final int pausedMs;

  /// Şu an duraklatılmışsa duraklamanın başladığı an.
  final DateTime? pausedAt;

  bool get isPaused => pausedAt != null;

  /// [now] anına kadar çalışılan süre; duraklamalar düşülmüş, eksiye inmez
  /// (saat geri alınırsa sıfırda kalır).
  Duration elapsed(DateTime now) {
    final end = pausedAt ?? now;
    final ms = end.difference(startedAt).inMilliseconds - pausedMs;
    return Duration(milliseconds: math.max(0, ms));
  }

  /// Kayda geçecek dakika: yuvarlanmış, en az 1. Bir dakikadan kısa odak da
  /// bir çalışmadır; sıfır dakikalık kayıt ise istatistikte görünmez kalırdı.
  int minutes(DateTime now) =>
      math.max(1, (elapsed(now).inSeconds / 60).round());

  FocusTimer pause(DateTime now) => isPaused
      ? this
      : FocusTimer(
          taskId: taskId,
          startedAt: startedAt,
          pausedMs: pausedMs,
          pausedAt: now,
        );

  FocusTimer resume(DateTime now) => !isPaused
      ? this
      : FocusTimer(
          taskId: taskId,
          startedAt: startedAt,
          pausedMs:
              pausedMs + math.max(0, now.difference(pausedAt!).inMilliseconds),
        );

  String encode() => jsonEncode({
    'taskId': taskId,
    'startedAt': startedAt.toIso8601String(),
    'pausedMs': pausedMs,
    if (pausedAt != null) 'pausedAt': pausedAt!.toIso8601String(),
  });

  /// Bozuk ya da eski biçimli kayıt `null` döner: okunamayan bir sayaç için
  /// uygulamayı düşürmektense sayacı yok saymak daha az zararlı.
  static FocusTimer? decode(String? raw) {
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final pausedAt = map['pausedAt'] as String?;
      return FocusTimer(
        taskId: map['taskId'] as int,
        startedAt: DateTime.parse(map['startedAt'] as String),
        pausedMs: map['pausedMs'] as int? ?? 0,
        pausedAt: pausedAt == null ? null : DateTime.parse(pausedAt),
      );
    } on Object {
      return null;
    }
  }
}

/// "mm:ss"; bir saati aşınca "s:mm:ss".
String formatElapsed(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
