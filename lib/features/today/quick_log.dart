import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/db/database.dart';

/// Görevi [minutes] dakikalık çalışma olarak kapatır ve "Geri al" sunar.
///
/// Bugün listesindeki dakika rozetleri ile odak ekranının "Bitir" düğmesi
/// aynı yoldan geçiyor: kayıt sorusuz yazılıyor, yanlış rozete basmanın
/// bedeli ise tek dokunuşluk bir geri alma. Önce soru sormak, her doğru
/// kaydı yavaşlatıp nadir yanlışı korumak olurdu.
///
/// [messenger] çağıran tarafından, beklemeden önce alınmalı: odak ekranı
/// kayıttan sonra kapanıyor ve kendi bağlamı artık geçersiz oluyor.
Future<void> quickLog(
  ScaffoldMessengerState messenger,
  RitimDatabase db,
  int taskId,
  int minutes,
) async {
  final snapshot = await db.completeTaskAsStudied(taskId, minutes: minutes);
  if (snapshot == null) return;
  unawaited(HapticFeedback.mediumImpact());

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$minutes dk kaydedildi'),
        // Eylemli bildirimler varsayılan olarak kendiliğinden kapanmıyor;
        // geri alma fırsatı birkaç saniyelik, sonra yolundan çekilmeli.
        persist: false,
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () => db.undoQuickCompletion(snapshot),
        ),
      ),
    );
}
