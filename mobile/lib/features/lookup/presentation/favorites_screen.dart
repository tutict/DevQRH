import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n/app_localizations.dart';
import '../domain/models.dart';
import 'lookup_controller.dart';
import 'page_overview_card.dart';
import 'runbook_cards.dart';
import 'shared_panels.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesProvider);
    final syncState = ref.watch(contentSyncProvider);
    final totalRunbooks = syncState.bootstrap?.manifest.checklistCount ?? 0;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favoritesTitle),
        actions: [
          IconButton(
            onPressed: () => context.push('/catalog'),
            icon: const Icon(Icons.grid_view_outlined),
            tooltip: l10n.catalog,
          ),
        ],
      ),
      body: favoritesState.when(
        data: (ids) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: PageOverviewCard(
                  title: l10n.savedRunbooks,
                  description: buildCollectionSummaryForTest(
                    count: ids.length,
                    totalCount: totalRunbooks,
                    activityLabel: l10n.saved,
                    source: syncState.source,
                    l10n: l10n,
                  ),
                  pills: [
                    l10n.favoritesCount(ids.length),
                    l10n.runbooksCount(totalRunbooks),
                    contentSourceShortLabel(syncState.source, l10n: l10n),
                  ],
                ),
              ),
              Expanded(
                child: ids.isEmpty
                    ? EmptyContentState(
                        title: l10n.noFavorites,
                        description: l10n.bookmarkRunbooksHint,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        itemBuilder: (context, index) {
                          return SavedChecklistTile(
                            checklistId: ids[index],
                            subtitleBuilder: (checklist) =>
                                buildSavedChecklistSubtitle(
                                  checklist,
                                  preferSymptoms: false,
                                ),
                            trailingIcon: Icons.bookmark,
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemCount: ids.length,
                      ),
              ),
            ],
          );
        },
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

String buildSavedChecklistSubtitle(
  Checklist checklist, {
  required bool preferSymptoms,
}) {
  final primary = preferSymptoms ? checklist.symptoms : checklist.keywords;
  final secondary = preferSymptoms ? checklist.keywords : checklist.symptoms;

  final primaryLabel = primary
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(preferSymptoms ? 2 : 3)
      .join(' / ');
  if (primaryLabel.isNotEmpty) {
    return primaryLabel;
  }

  final secondaryLabel = secondary
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(preferSymptoms ? 3 : 2)
      .join(' / ');
  if (secondaryLabel.isNotEmpty) {
    return secondaryLabel;
  }

  return checklist.id;
}

String buildCollectionSummaryForTest({
  required int count,
  required int totalCount,
  required String activityLabel,
  required ContentSource source,
  AppLocalizations? l10n,
}) {
  final strings = l10n ?? AppLocalizations.english;
  return strings.collectionSummary(
    count,
    totalCount,
    activityLabel,
    contentSourceShortLabel(source, l10n: strings),
  );
}

class SavedChecklistTile extends ConsumerWidget {
  const SavedChecklistTile({
    super.key,
    required this.checklistId,
    required this.subtitleBuilder,
    required this.trailingIcon,
  });

  final String checklistId;
  final String Function(Checklist checklist) subtitleBuilder;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistState = ref.watch(checklistSummaryProvider(checklistId));

    return checklistState.when(
      data: (checklist) {
        if (checklist == null) {
          return _UnavailableChecklistTile(
            checklistId: checklistId,
            trailingIcon: trailingIcon,
          );
        }

        return RunbookCard(
          title: checklist.title,
          subtitle: subtitleBuilder(checklist),
          trailing: Icon(trailingIcon),
          onTap: () => context.push(
            '/checklists/${checklist.id}?title=${Uri.encodeComponent(checklist.title)}',
          ),
        );
      },
      error: (error, stackTrace) => _UnavailableChecklistTile(
        checklistId: checklistId,
        trailingIcon: trailingIcon,
      ),
      loading: () => const _ChecklistTilePlaceholder(),
    );
  }
}

class _ChecklistTilePlaceholder extends StatelessWidget {
  const _ChecklistTilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        context.l10n.loadingRunbook,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6A6058)),
      ),
    );
  }
}

class _UnavailableChecklistTile extends StatelessWidget {
  const _UnavailableChecklistTile({
    required this.checklistId,
    required this.trailingIcon,
  });

  final String checklistId;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checklistId,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.runbookNotCachedYet,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6A6058),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(trailingIcon),
        ],
      ),
    );
  }
}
