import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n/app_localizations.dart';
import 'favorites_screen.dart';
import 'lookup_controller.dart';
import 'page_overview_card.dart';
import 'shared_panels.dart';

class RecentScreen extends ConsumerWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentState = ref.watch(recentProvider);
    final syncState = ref.watch(contentSyncProvider);
    final totalRunbooks = syncState.bootstrap?.manifest.checklistCount ?? 0;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recentTitle),
        actions: [
          IconButton(
            onPressed: () => context.push('/catalog'),
            icon: const Icon(Icons.grid_view_outlined),
            tooltip: l10n.catalog,
          ),
        ],
      ),
      body: recentState.when(
        data: (ids) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: PageOverviewCard(
                  title: l10n.recentActivity,
                  description: buildCollectionSummaryForTest(
                    count: ids.length,
                    totalCount: totalRunbooks,
                    activityLabel: l10n.viewed,
                    source: syncState.source,
                    l10n: l10n,
                  ),
                  pills: [
                    l10n.recentCount(ids.length),
                    l10n.runbooksCount(totalRunbooks),
                    contentSourceShortLabel(syncState.source, l10n: l10n),
                  ],
                ),
              ),
              Expanded(
                child: ids.isEmpty
                    ? EmptyContentState(
                        title: l10n.noRecentRunbooks,
                        description: l10n.openRunbookHint,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        itemBuilder: (context, index) {
                          return SavedChecklistTile(
                            checklistId: ids[index],
                            subtitleBuilder: (checklist) =>
                                buildSavedChecklistSubtitle(
                                  checklist,
                                  preferSymptoms: true,
                                ),
                            trailingIcon: Icons.chevron_right,
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
