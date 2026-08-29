
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_fab.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../reminders/reminder_prompt.dart';
import 'widgets/log_session_sheet.dart';
import 'widgets/note_list.dart';
import 'widgets/photo_strip.dart';
/// Bir konunun her şeyi: durumu, notu, çalışma geçmişi.
///
/// Ekranın omurgası "Çalıştım" düğmesi. Not ve geçmiş onun etrafında duruyor,
/// çünkü tekrar günü geldiğinde kullanıcıyı buraya getireceğiz ve o an
/// görmesi gereken şey kendi notu ile geçen sefer kaç yanlış yaptığı.
class TopicDetailScreen extends ConsumerStatefulWidget {
  const TopicDetailScreen({
    required this.subjectId,
    required this.topicId,
    super.key,
  });

  final int subjectId;
  final int topicId;

  @override
  ConsumerState<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends ConsumerState<TopicDetailScreen> {

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(topicsProvider(widget.subjectId));
    final totals = ref.watch(topicTotalsProvider(widget.topicId)).valueOrNull;
    final sessions =
        ref.watch(sessionsProvider(widget.topicId)).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;

    final topic = topics.valueOrNull
        ?.where((t) => t.id == widget.topicId)
        .firstOrNull;

    if (topic == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: Text(topic.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.listBottom),
        children: [
          _DoneToggle(
            done: topic.status == TopicStatus.done,
            onChanged: (value) => ref
                .read(databaseProvider)
                .setTopicDone(topic.id, done: value),
          ),
          if (totals != null && totals.minutes > 0) ...[
            const SizedBox(height: Gap.xl),
            _TotalsRow(totals: totals),
          ],
          const SizedBox(height: Gap.xxl),
          Text('Notların', style: text.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            'Tekrar günü geldiğinde bu notlar karşına çıkacak.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Gap.md),
          NoteList(topicId: widget.topicId),
          const SizedBox(height: Gap.xxl),
          Text('Fotoğraflar', style: text.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            'Kitaptan bir sayfa, çözdüğün bir soru. Tekrar günü bunlar da '
            'karşına çıkar.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Gap.md),
          PhotoStrip(topicId: widget.topicId),
          const SizedBox(height: Gap.section),
          Text('Çalışma geçmişi', style: text.titleMedium),
          const SizedBox(height: Gap.md),
          if (sessions.isEmpty)
            Text(
              'Henüz kayıt yok. Çalıştıktan sonra aşağıdaki düğmeye bas.',
              style: text.bodySmall,
            )
          else
            for (final session in sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SessionTile(session: session),
              ),
        ],
      ),
      floatingActionButton: AppFab(
        heroTag: 'calistim',
        icon: PhosphorIconsRegular.check,
        label: 'Çalıştım',
        // İzin tam burada isteniyor: kullanıcı ilk çalışma kaydını girdiği an
        // ilk tekrarı da planlanmış oluyor, yani hatırlatmanın ne işe
        // yaradığı en anlaşılır olduğu an burası.
        onPressed: () async {
          final logged = await LogSessionSheet.show(context, widget.topicId);
          if (logged == true && context.mounted) {
            await ReminderPrompt.askIfNeeded(context, ref);
          }
        },
      ),
    );
  }
}

/// "Bu konuyu bitirdim" anahtarı.
///
/// Önce üç durumlu bir seçici vardı (Başlamadım / Çalışıyorum / Bitirdim) ama
/// alttaki "Çalıştım" düğmesiyle aynı eksende okunuyordu: kullanıcı
/// "Çalışıyorum" ile "Çalıştım" arasındaki farkı çözemiyordu. İkisinden biri
/// gereksizdi ve gereksiz olan seçiciydi — üç değerinden ikisi zaten kullanıcı
/// kararı değil.
class _DoneToggle extends StatelessWidget {
  const _DoneToggle({required this.done, required this.onChanged});

  final bool done;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
      onTap: () => onChanged(!done),
      child: Row(
        children: [
          Icon(
            done
                ? PhosphorIconsFill.checkCircle
                : PhosphorIconsRegular.circleDashed,
            size: IconSize.md,
            color: done ? AppColors.progress : AppColors.textTertiary,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              done ? 'Bu konuyu bitirdin' : 'Bu konuyu bitirdim',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: done,
            activeThumbColor: AppColors.surface,
            activeTrackColor: AppColors.progress,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.totals});

  final TopicTotals totals;

  @override
  Widget build(BuildContext context) {
    final accuracy = totals.accuracy;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          _Stat(
            value: totals.minutes < 60
                ? '${totals.minutes} dk'
                : '${(totals.minutes / 60).toStringAsFixed(1)} sa',
            label: 'toplam süre',
          ),
          if (totals.hasQuestions) ...[
            _Stat(value: '${totals.solved}', label: 'soru'),
            _Stat(
              value: '%${((accuracy ?? 0) * 100).round()}',
              label: 'doğru',
              // Doğru oranı ilerleme yeşiliyle değil metin rengiyle yazılıyor:
              // yeşil yalnızca dolgu rengi, yazıda okunmuyor.
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final StudySession session;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final solved = session.questionsSolved;
    final wrong = session.questionsWrong ?? 0;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('d MMM', 'tr_TR').format(session.studiedAt),
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: Gap.md),
              Text(
                '${session.minutes} dk',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (solved != null)
                Text(
                  '$solved soru · $wrong yanlış',
                  style: text.bodySmall,
                ),
            ],
          ),
          if (session.note != null) ...[
            const SizedBox(height: Gap.sm),
            Text(session.note!, style: text.bodySmall?.copyWith(height: 1.4)),
          ],
        ],
      ),
    );
  }
}
