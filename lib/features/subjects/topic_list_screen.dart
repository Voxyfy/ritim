import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_fab.dart';
import '../../core/widgets/illustration.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';

/// Bir dersin konuları.
///
/// Ders adı rota parametresi olarak değil `extra` ile geliyor: başlığı
/// çizebilmek için tek satırlık bir veritabanı sorgusu açmaya değmez ve
/// kullanıcı buraya zaten ders listesinden giriyor.
class TopicListScreen extends ConsumerStatefulWidget {
  const TopicListScreen({
    required this.subjectId,
    required this.subjectName,
    super.key,
  });

  final int subjectId;
  final String subjectName;

  @override
  ConsumerState<TopicListScreen> createState() => _TopicListScreenState();
}

/// Sağa kaydırma bitirir, uzun basma çoklu seçimi açar.
///
/// Konuyu bitirmek için detaya girip anahtara basmak üç dokunuştu; bir
/// üniteyi bitiren öğrenci bunu on konu için arka arkaya yapıyordu. Silme de
/// uzun basmadan seçim çubuğuna taşındı: tek konu silmek için açılan sayfa,
/// on konuyu silmeyi on ayrı sayfaya çeviriyordu.
class _TopicListScreenState extends ConsumerState<TopicListScreen> {
  final _selected = <int>{};

  bool get _selecting => _selected.isNotEmpty;

  void _toggleSelected(int topicId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(topicId)) _selected.add(topicId);
    });
  }

  /// Bitti işaretini çevirir; geri al önceki durumu birebir geri yazıyor.
  /// "Çalışıyorsun" bir konu yanlışlıkla bitirilip geri alındığında
  /// "başlamadın"a düşmemeli.
  Future<void> _toggleDone(Topic topic) async {
    unawaited(HapticFeedback.lightImpact());
    final db = ref.read(databaseProvider);
    final previous = topic.status;
    final done = previous == TopicStatus.done;
    await db.setTopicDone(topic.id, done: !done);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            done ? '"${topic.name}" geri alındı' : '"${topic.name}" bitti',
          ),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () => db.setTopicStatus(topic.id, previous),
          ),
        ),
      );
  }

  Future<void> _markSelectedDone() async {
    final db = ref.read(databaseProvider);
    for (final id in _selected) {
      await db.setTopicStatus(id, TopicStatus.done);
    }
    if (mounted) setState(_selected.clear);
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text(count == 1 ? 'Konuyu sil' : '$count konuyu sil'),
        content: Text(
          count == 1
              ? 'Notu ve çalışma kayıtları da silinir.'
              : 'Notları ve çalışma kayıtları da silinir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.overdue,
              minimumSize: const Size(100, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final db = ref.read(databaseProvider);
    for (final id in _selected) {
      await db.deleteTopic(id);
    }
    if (mounted) setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final subjectId = widget.subjectId;
    final subjectName = widget.subjectName;
    final topics = ref.watch(topicsProvider(subjectId));
    final noteCounts =
        ref.watch(noteCountsProvider(subjectId)).valueOrNull ?? const {};
    // Ders rengi için ayrı sorgu yok: ders listesi zaten akışta ve bellekte.
    final subject = ref
        .watch(subjectsProvider)
        .valueOrNull
        ?.where((s) => s.id == subjectId)
        .firstOrNull;
    final colour = subject == null
        ? const SubjectColor(AppColors.textSecondary, AppColors.surfaceMuted)
        : SubjectPalette.at(subject.colorIndex);

    return PopScope(
      // Seçim açıkken geri hareketi önce seçimi kapatıyor, ekranı değil.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Kapat',
                  icon: const Icon(PhosphorIconsRegular.x),
                  onPressed: () => setState(_selected.clear),
                ),
                title: Text('${_selected.length} seçildi'),
                actions: [
                  IconButton(
                    tooltip: 'Bitti olarak işaretle',
                    icon: const Icon(PhosphorIconsRegular.checkCircle),
                    onPressed: _markSelectedDone,
                  ),
                  IconButton(
                    tooltip: 'Sil',
                    icon: const Icon(
                      PhosphorIconsRegular.trash,
                      color: AppColors.overdue,
                    ),
                    onPressed: _deleteSelected,
                  ),
                ],
              )
            : AppBar(title: Text(subjectName)),
        floatingActionButton: _selecting
            ? null
            : AppFab(
                heroTag: 'konu-ekle',
                onPressed: () => _addTopic(context, ref, subjectId),
              ),
        body: topics.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) =>
              Center(child: Text('Konular okunamadı: $error')),
          data: (list) => list.isEmpty
              ? _EmptyTopics(onAdd: () => _addTopic(context, ref, subjectId))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    Gap.sm,
                    Gap.page,
                    Gap.listBottom,
                  ),
                  itemCount: list.length,
                  // Konular bir müfredat sırası; kartlar yerine zaman
                  // çizgisi, böylece "nerede kaldım" sorusunun cevabı
                  // çizginin dolu düğümlerinin bittiği yer oluyor.
                  itemBuilder: (context, index) {
                    final topic = list[index];
                    final notes = noteCounts[topic.id] ?? 0;
                    final selected = _selected.contains(topic.id);
                    final meta = [
                      if (topic.status == TopicStatus.inProgress)
                        'çalışıyorsun',
                      if (topic.status == TopicStatus.done) 'bitti',
                      if (notes > 0) '$notes not',
                    ];
                    return Dismissible(
                      key: ValueKey(topic.id),
                      // Seçim sırasında kaydırma kapalı: iki hareket aynı
                      // satırda farklı şeyler yapmasın.
                      direction: _selecting
                          ? DismissDirection.none
                          : DismissDirection.startToEnd,
                      background: _SwipeDone(
                        colour: colour,
                        undo: topic.status == TopicStatus.done,
                      ),
                      // Satır yerinde kalıyor; yalnızca durumu değişiyor.
                      confirmDismiss: (_) async {
                        await _toggleDone(topic);
                        return false;
                      },
                      child: AnimatedContainer(
                        duration: Motion.quick,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(
                            color: selected
                                ? AppColors.selection
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: _selecting
                              ? () => _toggleSelected(topic.id)
                              : () => context.go(
                                  '${Routes.subjects}/$subjectId/${topic.id}',
                                  extra: subjectName,
                                ),
                          onLongPress: () => _toggleSelected(topic.id),
                          borderRadius: BorderRadius.circular(Radii.md),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SyllabusNode(
                                  colour: colour,
                                  index: index + 1,
                                  status: topic.status,
                                  isFirst: index == 0,
                                  isLast: index == list.length - 1,
                                ),
                                const SizedBox(width: Gap.md),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: Gap.md,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          topic.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        if (meta.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            meta.join(' · '),
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                if (_selecting)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: Gap.md,
                                    ),
                                    child: Icon(
                                      selected
                                          ? PhosphorIconsFill.checkCircle
                                          : PhosphorIconsRegular.circle,
                                      size: IconSize.lg,
                                      color: selected
                                          ? AppColors.selection
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// Sağa kaydırırken satırın altında beliren işaret, ders renginde.
class _SwipeDone extends StatelessWidget {
  const _SwipeDone({required this.colour, required this.undo});

  final SubjectColor colour;

  /// Konu zaten bitmişse kaydırma işareti kaldırıyor.
  final bool undo;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
      decoration: BoxDecoration(
        color: colour.wash,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            undo
                ? PhosphorIconsRegular.arrowCounterClockwise
                : PhosphorIconsFill.checkCircle,
            size: IconSize.md,
            color: colour.ink,
          ),
          const SizedBox(width: Gap.sm),
          Text(
            undo ? 'Geri al' : 'Bitti',
            style: TextStyle(color: colour.ink, fontWeight: FontWeight.w700),
          ),
        ],
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
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

/// Müfredat çizgisindeki düğüm.
///
/// Ortak [TimelineNode]'un üç durumlu kuzeni: orada düğüm bitince soluyor,
/// burada bitmiş konu dersin mürekkebiyle doluyor ve beyaz onay alıyor —
/// listede ilerlemenin kendisi görünmeli, solan düğüm "önemsiz" gibi okunurdu.
/// Bitmemiş konu sıra numarasını taşıyor; çalışılan konunun kenarı mürekkep,
/// böylece üç durum renk olmadan da (dolu / çerçeveli / düz) ayrılıyor.
class _SyllabusNode extends StatelessWidget {
  const _SyllabusNode({
    required this.colour,
    required this.index,
    required this.status,
    required this.isFirst,
    required this.isLast,
  });

  static const _size = 40.0;

  final SubjectColor colour;
  final int index;
  final TopicStatus status;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final done = status == TopicStatus.done;
    Widget line(bool visible) => Expanded(
      child: Center(
        child: Container(
          width: 2,
          color: visible ? AppColors.border : Colors.transparent,
        ),
      ),
    );

    return SizedBox(
      width: _size,
      child: Column(
        children: [
          line(!isFirst),
          AnimatedContainer(
            duration: Motion.base,
            curve: Motion.curve,
            width: _size,
            height: _size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? colour.ink : colour.wash,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: status == TopicStatus.inProgress
                  ? Border.all(color: colour.ink, width: 2)
                  : null,
            ),
            child: done
                ? const Icon(
                    PhosphorIconsRegular.check,
                    size: IconSize.md,
                    color: Colors.white,
                  )
                : Text(
                    '$index',
                    style: TextStyle(
                      color: colour.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
          line(!isLast),
        ],
      ),
    );
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
