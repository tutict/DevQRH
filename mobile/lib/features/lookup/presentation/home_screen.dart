import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models.dart';
import 'lookup_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(lookupControllerProvider.notifier).search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lookupState = ref.watch(lookupControllerProvider);
    final contentSyncState = ref.watch(contentSyncProvider);
    final manifest = contentSyncState.bootstrap?.manifest;
    final favoritesState = ref.watch(favoritesProvider);
    final recentState = ref.watch(recentProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text('DevQRH', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Fast lookup for incident paths. Type symptoms. Get the next move.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5B5148),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search symptom', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _queryController,
                    onChanged: _onQueryChanged,
                    onSubmitted: (value) => ref
                        .read(lookupControllerProvider.notifier)
                        .search(value),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'service lag / CPU 100% / timeout query',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Quick entry',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _QuickChip(label: 'CPU 100%'),
                  _QuickChip(label: 'service lag'),
                  _QuickChip(label: 'timeout query'),
                  _QuickChip(label: 'memory leak'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Content sync',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contentSyncState.isSyncing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: LinearProgressIndicator(),
                    ),
                  _MetaRow(
                    label: 'Version',
                    value: manifest == null
                        ? 'Not synced'
                        : manifest.version.substring(
                            0,
                            manifest.version.length > 8
                                ? 8
                                : manifest.version.length,
                          ),
                  ),
                  const SizedBox(height: 10),
                  _MetaRow(
                    label: 'Checklist count',
                    value: manifest?.checklistCount.toString() ?? '0',
                  ),
                  const SizedBox(height: 10),
                  _MetaRow(
                    label: 'Source',
                    value: switch (contentSyncState.source) {
                      ContentSource.cache => 'Cache',
                      ContentSource.network => 'Network',
                      ContentSource.none => 'None',
                    },
                  ),
                  const SizedBox(height: 10),
                  _MetaRow(
                    label: 'Last sync',
                    value: _formatSyncTime(contentSyncState.lastSyncedAt),
                  ),
                  const SizedBox(height: 10),
                  _MetaRow(
                    label: 'Favorites',
                    value: '${favoritesState.valueOrNull?.length ?? 0}',
                  ),
                  const SizedBox(height: 10),
                  _MetaRow(
                    label: 'Recent',
                    value: '${recentState.valueOrNull?.length ?? 0}',
                  ),
                  if (contentSyncState.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      contentSyncState.errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFB14622),
                      ),
                    ),
                    if (contentSyncState.nextRetryAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Auto retry ${contentSyncState.retryCount}/2 at ${_formatSyncTime(contentSyncState.nextRetryAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6A6058),
                        ),
                      ),
                    ] else if (contentSyncState.hasContent) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Cached content is still available.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6A6058),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  FilledButton.tonal(
                    onPressed: contentSyncState.isSyncing
                        ? null
                        : () => ref
                              .read(contentSyncProvider.notifier)
                              .sync(manual: true),
                    child: Text(contentSyncState.actionLabel),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Top matches',
              child: lookupState.when(
                data: (result) {
                  if (result == null || result.candidates.isEmpty) {
                    return const _EmptyState(
                      title: 'Waiting for input',
                      description:
                          'Type one incident symptom and the app returns the top 3 paths.',
                    );
                  }
                  return Column(
                    children: result.candidates
                        .asMap()
                        .entries
                        .map(
                          (entry) => _ResultTile(
                            rank: entry.key + 1,
                            item: entry.value,
                            isFavorite:
                                favoritesState.valueOrNull?.contains(
                                  entry.value.checklist.id,
                                ) ??
                                false,
                            onTap: () {
                              ref
                                  .read(recentProvider.notifier)
                                  .push(entry.value.checklist.id);
                              context.push(
                                '/checklists/${entry.value.checklist.id}?title=${Uri.encodeComponent(entry.value.checklist.title)}',
                              );
                            },
                            onFavoriteTap: () {
                              ref
                                  .read(favoritesProvider.notifier)
                                  .toggle(entry.value.checklist.id);
                            },
                          ),
                        )
                        .toList(),
                  );
                },
                error: (error, stackTrace) => _EmptyState(
                  title: 'Search failed',
                  description: error.toString(),
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends ConsumerWidget {
  const _QuickChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionChip(
      label: Text(label),
      onPressed: () =>
          ref.read(lookupControllerProvider.notifier).search(label),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.rank,
    required this.item,
    required this.onTap,
    required this.onFavoriteTap,
    required this.isFavorite,
  });

  final int rank;
  final RankedChecklist item;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFD95C18),
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.checklist.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.checklist.symptoms.take(2).join(' / '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6A6058),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ScorePill(score: item.score),
                      ...item.checklist.keywords
                          .take(2)
                          .map((keyword) => Chip(label: Text(keyword))),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onFavoriteTap,
              icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_border),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF171411),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        score.toStringAsFixed(2),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String _formatSyncTime(DateTime? value) {
  if (value == null) {
    return 'Never';
  }

  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
