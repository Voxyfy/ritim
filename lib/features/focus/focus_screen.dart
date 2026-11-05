import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../data/db/database.dart';
import '../../domain/focus_timer.dart';
import '../subjects/widgets/log_session_sheet.dart';
import '../today/quick_log.dart';

/// Bir göreve başlamadan önce odak sayacını kurar ve odak ekranını açar.
///
/// Sayaç önce ayara yazılıyor, sonra ekran açılıyor: ekran sayacı ayardan
/// okuyor, böylece Bugün'deki çubuktan yeniden açmak da aynı yoldan geçiyor.
Future<void> startFocus(
  BuildContext context,
  RitimDatabase db,
  int taskId,
) async {
  final router = GoRouter.of(context);
  await db.writeSetting(
    SettingKeys.focusTimer,
    FocusTimer(taskId: taskId, startedAt: DateTime.now()).encode(),
  );
  unawaited(router.push(Routes.focus));
}

/// Tam ekran odak sayacı: büyük süre, görevin adı, duraklat ve bitir.
///
/// Sayaç ekranın değil ayarların: geri hareketi ekranı kapatır ama sayacı
/// durdurmaz, Bugün'deki "Odak sürüyor" çubuğu ekrana geri getirir. Yalnızca
/// "Bitir" (kaydeder) ve "Vazgeç" (onayla siler) sayacı sonlandırır.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  FocusTimer? _timer;
  Task? _task;
  bool _loaded = false;
  bool _busy = false;
  late final Timer _ticker;

  RitimDatabase get _db => ref.read(databaseProvider);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final timer = FocusTimer.decode(
      await _db.readSetting(SettingKeys.focusTimer),
    );
    final task = timer == null ? null : await _db.taskById(timer.taskId);
    // Görev bu arada silindiyse sayacın bağlanacağı bir şey kalmadı.
    if (timer != null && task == null) {
      await _db.deleteSetting(SettingKeys.focusTimer);
    }
    if (!mounted) return;
    setState(() {
      _timer = task == null ? null : timer;
      _task = task;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _save(FocusTimer timer) async {
    setState(() => _timer = timer);
    await _db.writeSetting(SettingKeys.focusTimer, timer.encode());
  }

  Future<void> _finish() async {
    final timer = _timer;
    if (timer == null || _busy) return;
    _busy = true;
    final messenger = ScaffoldMessenger.of(context);
    final minutes = timer.minutes(DateTime.now());
    await _db.deleteSetting(SettingKeys.focusTimer);
    if (mounted) context.pop();
    await quickLog(messenger, _db, timer.taskId, minutes);
  }

  /// Süreyi ve soru sayılarını tam kayıt sayfasında düzeltmek için.
  Future<void> _details() async {
    final timer = _timer;
    final topicId = _task?.topicId;
    if (timer == null || topicId == null) return;
    final logged = await LogSessionSheet.show(
      context,
      topicId,
      taskId: timer.taskId,
      initialMinutes: timer.minutes(DateTime.now()),
    );
    if (logged != true) return;
    await _db.deleteSetting(SettingKeys.focusTimer);
    if (mounted) context.pop();
  }

  Future<void> _discard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bu odak silinsin mi?'),
        content: const Text('Geçen süre kaydedilmeyecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Devam et'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.overdue),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteSetting(SettingKeys.focusTimer);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final timer = _timer;
    final task = _task;

    if (!_loaded) return const Scaffold();
    if (timer == null || task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Süren bir odak yok.')),
      );
    }

    final paused = timer.isPaused;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.sm,
            Gap.page,
            Gap.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // Küçült: sayaç sürer, Bugün'deki çubuk geri getirir.
                  IconButton(
                    tooltip: 'Küçült',
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      PhosphorIconsRegular.caretDown,
                      size: IconSize.lg,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _discard,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Vazgeç'),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                task.title,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: Gap.lg),
              Text(
                formatElapsed(timer.elapsed(DateTime.now())),
                key: const ValueKey('odak-sure'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  // Rakamlar her saniye değişirken genişlik oynamasın.
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: paused
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: Gap.md),
              AnimatedOpacity(
                duration: Motion.base,
                opacity: paused ? 1 : 0,
                child: const Text(
                  'Duraklatıldı',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: () => _save(
                        paused
                            ? timer.resume(DateTime.now())
                            : timer.pause(DateTime.now()),
                      ),
                      icon: Icon(
                        paused
                            ? PhosphorIconsRegular.play
                            : PhosphorIconsRegular.pause,
                        size: IconSize.md,
                      ),
                      label: Text(paused ? 'Devam' : 'Duraklat'),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _finish,
                      child: const Text('Bitir'),
                    ),
                  ),
                ],
              ),
              if (task.topicId != null) ...[
                const SizedBox(height: Gap.sm),
                TextButton(
                  onPressed: _details,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Ayrıntıyla kaydet'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
