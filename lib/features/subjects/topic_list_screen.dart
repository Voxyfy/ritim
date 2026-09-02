import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_fab.dart';
import '../../core/widgets/illustration.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
/// Bir dersin konuları.
///
/// Ders adı rota parametresi olarak değil `extra` ile geliyor: başlığı
/// çizebilmek için tek satırlık bir veritabanı sorgusu açmaya değmez ve
/// kullanıcı buraya zaten ders listesinden giriyor.
class TopicListScreen extends ConsumerWidget {
  const TopicListScreen({
    required this.subjectId,
    required this.subjectName,
    super.key,
  });

  final int subjectId;
  final String subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider(subjectId));
    final noteCounts =
        ref.watch(noteCountsProvider(subjectId)).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(subjectName)),
      floatingActionButton: AppFab(
        heroTag: 'konu-ekle',
        onPressed: () => _addTopic(context, ref, subjectId),
      ),
      body: topics.when(
        loading: () => const SizedBox.shrink(),
        error: (error, stack) => Center(child: Text('Konular okunamadı: $error')),
        data: (list) => list.isEmpty
            ? _EmptyTopics(onAdd: () => _addTopic(context, ref, subjectId))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.listBottom),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final topic = list[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      onTap: () => context.go(
                        '${Routes.subjects}/$subjectId/${topic.id}',
                        extra: subjectName,
                      ),
                      onLongPress: () => _showTopicActions(context, ref, topic),
                      child: Row(
                        children: [
                          _StatusDot(status: topic.status),
                          const SizedBox(width: Gap.lg),
                          Expanded(
                            child: Text(
                              topic.name,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if ((noteCounts[topic.id] ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: Gap.sm),
                              child: Row(
                                children: [
                                  const Icon(
                                    PhosphorIconsRegular.note,
                                    size: IconSize.sm,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: Gap.xs),
                                  Text(
                                    '${noteCounts[topic.id]}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Konu ekleme diyaloğu.
///
/// Tek alan olduğu için ayrı bir ekran değil: konu eklemek çoğunlukla arka
/// arkaya yapılan bir iş ve her seferinde tam ekran açmak yorucu olurdu.
///
/// Ders kimliği parametreyle geçiyor. Önce ağaçta [TopicListScreen] aranıyordu
/// ama `findAncestorWidgetOfExactType` çağıran widget'ın kendisini bulmuyor;
/// fonksiyon sessizce hiçbir şey yapmadan dönüyordu.
Future<void> _addTopic(
  BuildContext context,
  WidgetRef ref,
  int subjectId,
) async {
  final name = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (context) => const _TopicNameDialog(),
  );

  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return;

  final db = ref.read(databaseProvider);
  await db.addTopic(
    subjectId: subjectId,
    name: trimmed,
    position: await db.nextTopicPosition(subjectId),
  );
}

/// Konu adı soran diyalog.
///
/// Denetleyiciyi diyalog widget'ı sahipleniyor. Önce çağıran taraf
/// oluşturup `showDialog` döner dönmez siliyordu; diyaloğun kapanma
/// animasyonu hâlâ sürdüğü için [TextField] bir kez daha çiziliyor ve
/// "A TextEditingController was used after being disposed" hatası
/// veriyordu. Sahiplik, yaşam döngüsünü bilen tarafta olmalı.
class _TopicNameDialog extends StatefulWidget {
  const _TopicNameDialog();

  @override
  State<_TopicNameDialog> createState() => _TopicNameDialogState();
}

class _TopicNameDialogState extends State<_TopicNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      title: const Text('Yeni konu'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(hintText: 'Konu adı'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Vazgeç',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: _submit,
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}

/// Uzun basıldığında konu düzenleme ve silme.
void _showTopicActions(BuildContext context, WidgetRef ref, Topic topic) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              PhosphorIconsRegular.trash,
              color: AppColors.overdue,
            ),
            title: const Text(
              'Konuyu sil',
              style: TextStyle(color: AppColors.overdue),
            ),
            subtitle: const Text('Notu ve çalışma kayıtları da silinir.'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await ref.read(databaseProvider).deleteTopic(topic.id);
            },
          ),
        ],
      ),
    ),
  );
}

/// Konunun durumunu tek bakışta veren nokta.
///
/// Üç durum için üç ayrı ikon yerine tek bir daire: boş, yarım dolu, dolu.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final TopicStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      TopicStatus.notStarted => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 2),
          ),
        ),
      TopicStatus.inProgress => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.selection, width: 2),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.selection,
              ),
            ),
          ),
        ),
      TopicStatus.done => Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.progress,
          ),
          child: const Icon(
            PhosphorIconsRegular.check,
            size: IconSize.sm,
            color: Colors.white,
          ),
        ),
    };
  }
}

class _EmptyTopics extends StatelessWidget {
  const _EmptyTopics({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IllustrationView(Illustration.studying, height: 150),
            const SizedBox(height: Gap.section),
            Text(
              'Bu derste henüz konu yok',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.sm),
            const Text(
              'Çalışacağın konuları ekle; her birini ayrı takip edip '
              'tekrara sokabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: Gap.xxl),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
              onPressed: onAdd,
              child: const Text('Konu ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
