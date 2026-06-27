import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models.dart';
import 'knowledge_controller.dart';
import 'knowledge_widgets.dart';

class MaterialDetailScreen extends ConsumerWidget {
  const MaterialDetailScreen({super.key, required this.materialId});

  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialState = ref.watch(materialDetailProvider(materialId));
    final favorites = ref.watch(favoriteMaterialsProvider).value ?? const [];
    final cards = ref.watch(studyCardsProvider);

    return materialState.when(
      data: (material) {
        final related = ref.watch(relatedMaterialsProvider(material));
        final relatedCards = cards
            .where((card) => card.sourceMaterialIds.contains(material.id))
            .toList();
        final chunks = material.chunks.isNotEmpty
            ? material.chunks
            : _splitContent(material.content);
        return _RecentTracker(
          materialId: material.id,
          child: Scaffold(
            appBar: AppBar(
              title: Text(material.title),
              actions: [
                IconButton(
                  onPressed: () => ref
                      .read(favoriteMaterialsProvider.notifier)
                      .toggle(material.id),
                  icon: Icon(
                    favorites.contains(material.id)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                  ),
                  tooltip: favorites.contains(material.id) ? 'Saved' : 'Save',
                ),
              ],
            ),
            body: KnowledgePageFrame(
              safeTop: false,
              children: [
                KnowledgeSection(
                  title: 'Summary',
                  trailing: FilledButton.tonalIcon(
                    onPressed: () => ref
                        .read(cardGenerationProvider.notifier)
                        .generate(materialIds: [material.id], limit: 4),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Make cards'),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          KnowledgePill(label: materialTypeLabel(material.type)),
                          ...material.tags.map((tag) => KnowledgePill(label: tag)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        material.summary.trim().isEmpty
                            ? 'No summary provided.'
                            : material.summary,
                      ),
                      if (material.source.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Source: ${material.source}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF526071),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                KnowledgeSection(
                  title: 'Key Points',
                  child: chunks.isEmpty
                      ? const Text('No key points available.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: chunks
                              .take(8)
                              .map(
                                (chunk) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 3),
                                        child: Icon(Icons.arrow_right, size: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(chunk)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 18),
                KnowledgeSection(
                  title: 'Related Cards',
                  child: relatedCards.isEmpty
                      ? const KnowledgeEmptyState(
                          title: 'No cards from this material',
                          description: 'Import a bundle that includes cards or configure the sidecar and model to generate them.',
                          icon: Icons.style_outlined,
                        )
                      : Column(
                          children: relatedCards
                              .map(
                                (card) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: StudyCardTile(card: card),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 18),
                KnowledgeSection(
                  title: 'Related Materials',
                  child: related.isEmpty
                      ? const Text('No related materials yet.')
                      : Column(
                          children: related
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: MaterialListTileCard(
                                    material: item,
                                    onTap: () => context.push('/materials/${item.id}'),
                                    trailing: const Icon(Icons.chevron_right),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Material')),
        body: KnowledgePageFrame(
          safeTop: false,
          children: [
            KnowledgeEmptyState(
              title: 'Material unavailable',
              description: error.toString(),
              icon: Icons.error_outline,
            ),
          ],
        ),
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Material')),
        body: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  List<String> _splitContent(String value) {
    return value
        .split(RegExp(r'[。.!?！？\n]+'))
        .map((item) => item.trim())
        .where((item) => item.length >= 8)
        .toList();
  }
}

class _RecentTracker extends ConsumerStatefulWidget {
  const _RecentTracker({required this.materialId, required this.child});

  final String materialId;
  final Widget child;

  @override
  ConsumerState<_RecentTracker> createState() => _RecentTrackerState();
}

class _RecentTrackerState extends ConsumerState<_RecentTracker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(recentMaterialsProvider.notifier).push(widget.materialId);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
