import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n/app_localizations.dart';
import '../domain/models.dart';
import 'lookup_controller.dart';
import 'runbook_cards.dart';
import 'shared_panels.dart';

class ChecklistDetailScreen extends ConsumerWidget {
  const ChecklistDetailScreen({
    super.key,
    required this.checklistId,
    required this.titleHint,
  });

  final String checklistId;
  final String titleHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistState = ref.watch(checklistDetailProvider(checklistId));
    final favorites = ref.watch(favoritesProvider).value ?? const [];
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(titleHint.isEmpty ? l10n.runbook : titleHint),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(favoritesProvider.notifier).toggle(checklistId),
            icon: Icon(
              favorites.contains(checklistId)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            tooltip: favorites.contains(checklistId) ? l10n.saved : l10n.save,
          ),
        ],
      ),
      body: checklistState.when(
        data: (checklist) {
          final related = ref.watch(relatedChecklistsProvider(checklist));
          final recentChain = ref.watch(
            recentChecklistChainProvider(checklist.id),
          );
          return _RecentTracker(
            checklistId: checklist.id,
            child: PageFrame(
              safeTop: false,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  checklist.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: checklist.keywords
                      .map((keyword) => Chip(label: Text(keyword)))
                      .toList(),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: l10n.copyTools,
                  titleSpacing: 12,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _copyToClipboard(
                          context,
                          _buildChecklistSummary(checklist, l10n),
                          l10n.runbookSummaryCopied,
                        ),
                        icon: const Icon(Icons.content_copy),
                        label: Text(l10n.copySummary),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: checklist.immediateActions.isEmpty
                            ? null
                            : () => _copyToClipboard(
                                context,
                                _buildActionSummary(checklist),
                                l10n.immediateStepsCopied,
                              ),
                        icon: const Icon(Icons.playlist_add_check),
                        label: Text(l10n.copySteps),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionCard(
                  title: l10n.immediateActions,
                  titleSpacing: 12,
                  child: Column(
                    children: checklist.immediateActions
                        .map((step) => _StepLine(step: step))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: l10n.decisionTree,
                  titleSpacing: 12,
                  child: Column(
                    children: checklist.decisionTree
                        .map(
                          (branch) => _LinePair(
                            left: branch.condition,
                            right: branch.action,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: l10n.symptoms,
                  titleSpacing: 12,
                  child: _BulletList(items: checklist.symptoms),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: l10n.rootCause,
                  titleSpacing: 12,
                  child: _BulletList(items: checklist.rootCause),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: l10n.longTermFix,
                  titleSpacing: 12,
                  child: _BulletList(items: checklist.longTermFix),
                ),
                if (recentChain.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: l10n.recent,
                    titleSpacing: 12,
                    child: Column(
                      children: recentChain
                          .map(
                            (item) => _RelatedChecklistTile(
                              checklist: item,
                              isFavorite: favorites.contains(item.id),
                              onTap: () => context.pushReplacement(
                                '/checklists/${item.id}?title=${Uri.encodeComponent(item.title)}',
                              ),
                              onFavoriteTap: () => ref
                                  .read(favoritesProvider.notifier)
                                  .toggle(item.id),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                if (related.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: l10n.related,
                    titleSpacing: 12,
                    child: Column(
                      children: related
                          .map(
                            (item) => _RelatedChecklistTile(
                              checklist: item,
                              isFavorite: favorites.contains(item.id),
                              onTap: () => context.pushReplacement(
                                '/checklists/${item.id}?title=${Uri.encodeComponent(item.title)}',
                              ),
                              onFavoriteTap: () => ref
                                  .read(favoritesProvider.notifier)
                                  .toggle(item.id),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

Future<void> _copyToClipboard(
  BuildContext context,
  String value,
  String successMessage,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(successMessage)));
}

String _buildChecklistSummary(Checklist checklist, AppLocalizations l10n) {
  final buffer = StringBuffer()
    ..writeln(checklist.title)
    ..writeln('${l10n.checklistSummaryId}: ${checklist.id}');

  if (checklist.keywords.isNotEmpty) {
    buffer.writeln(
      '${l10n.checklistSummaryKeywords}: ${checklist.keywords.join(', ')}',
    );
  }
  if (checklist.symptoms.isNotEmpty) {
    buffer.writeln(
      '${l10n.checklistSummarySymptoms}: ${checklist.symptoms.join(' / ')}',
    );
  }
  if (checklist.immediateActions.isNotEmpty) {
    buffer.writeln('${l10n.checklistSummaryImmediateActions}:');
    for (final step in checklist.immediateActions) {
      buffer.writeln('${step.step}. ${step.action}');
    }
  }

  return buffer.toString().trim();
}

String _buildActionSummary(Checklist checklist) {
  return checklist.immediateActions
      .map((step) => '${step.step}. ${step.action}')
      .join('\n');
}

String buildChecklistSummaryForTest(Checklist checklist) =>
    _buildChecklistSummary(checklist, AppLocalizations.english);

class _RelatedChecklistTile extends StatelessWidget {
  const _RelatedChecklistTile({
    required this.checklist,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Checklist checklist;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return RunbookCard(
      title: checklist.title,
      subtitle: checklist.symptoms.take(2).join(' / '),
      labels: checklist.keywords.take(2).toList(),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 8),
      titleSubtitleSpacing: 4,
      subtitleLabelsSpacing: 8,
      trailing: Column(
        children: [
          IconButton(
            onPressed: onFavoriteTap,
            icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_border),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _RecentTracker extends ConsumerStatefulWidget {
  const _RecentTracker({required this.checklistId, required this.child});

  final String checklistId;
  final Widget child;

  @override
  ConsumerState<_RecentTracker> createState() => _RecentTrackerState();
}

class _RecentTrackerState extends ConsumerState<_RecentTracker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentProvider.notifier).push(widget.checklistId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.step});

  final ChecklistStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${step.step}.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(step.action)),
        ],
      ),
    );
  }
}

class _LinePair extends StatelessWidget {
  const _LinePair({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              left,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(right)),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('- '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
