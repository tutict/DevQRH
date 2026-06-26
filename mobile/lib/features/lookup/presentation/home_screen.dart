import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n/app_localizations.dart';
import '../domain/models.dart';
import 'lookup_controller.dart';
import 'page_overview_card.dart';
import 'runbook_cards.dart';
import 'shared_panels.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  String _liveQuery = '';
  String? _expandedChecklistId;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _liveQuery = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(lookupControllerProvider.notifier).search(value);
    });
  }

  void _submitSearch(String value, {bool syncInput = false}) {
    final query = value.trim();
    setState(() => _liveQuery = query);
    if (syncInput) {
      _queryController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    ref.read(recentSearchesProvider.notifier).push(query);
    ref.read(lookupControllerProvider.notifier).search(query);
  }

  void _toggleExpanded(String checklistId) {
    setState(() {
      _expandedChecklistId = _expandedChecklistId == checklistId
          ? null
          : checklistId;
    });
  }

  Future<void> _copyFirstAction(Checklist checklist) async {
    if (checklist.immediateActions.isEmpty) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: checklist.immediateActions.first.action),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.firstActionCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final lookupState = ref.watch(lookupControllerProvider);
    final contentSyncState = ref.watch(contentSyncProvider);
    final manifest = contentSyncState.bootstrap?.manifest;
    final favoritesState = ref.watch(favoritesProvider);
    final recentState = ref.watch(recentProvider);
    final recentSearchesState = ref.watch(recentSearchesProvider);
    final suggestions = ref.watch(searchSuggestionsProvider(_liveQuery));
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      body: PageFrame(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.appTitle,
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/catalog'),
                icon: const Icon(Icons.grid_view),
                label: Text(l10n.catalog),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.searchIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF526071),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoPill(
                label: l10n.runbooksCount(manifest?.checklistCount ?? 0),
              ),
              InfoPill(
                label: contentSourceShortLabel(
                  contentSyncState.source,
                  l10n: l10n,
                ),
              ),
              InfoPill(
                label: contentSyncState.hasContent ? l10n.ready : l10n.empty,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: l10n.searchSectionTitle,
            titleSpacing: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _queryController,
                  onChanged: _onQueryChanged,
                  onSubmitted: (value) => _submitSearch(value, syncInput: true),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.searchPlaceholder,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 14),
                _SuggestionPanel(
                  title: _liveQuery.trim().isEmpty
                      ? l10n.recentSearchesTitle
                      : l10n.suggestionsTitle,
                  suggestions: suggestions,
                  showClear:
                      _liveQuery.trim().isEmpty &&
                      (recentSearchesState.value?.isNotEmpty ?? false),
                  onSuggestionTap: (value) =>
                      _submitSearch(value, syncInput: true),
                  onClear: () =>
                      ref.read(recentSearchesProvider.notifier).clear(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: l10n.quickSearches,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickChip(
                  label: 'CPU 100%',
                  onPressed: () => _submitSearch('CPU 100%', syncInput: true),
                ),
                _QuickChip(
                  label: 'service lag',
                  onPressed: () =>
                      _submitSearch('service lag', syncInput: true),
                ),
                _QuickChip(
                  label: 'timeout query',
                  onPressed: () =>
                      _submitSearch('timeout query', syncInput: true),
                ),
                _QuickChip(
                  label: 'memory leak',
                  onPressed: () =>
                      _submitSearch('memory leak', syncInput: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: l10n.contentStatus,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (contentSyncState.isSyncing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: LinearProgressIndicator(),
                  ),
                Text(
                  buildHomeSyncSummaryForTest(
                    source: contentSyncState.source,
                    manifest: manifest,
                    lastSyncedAt: contentSyncState.lastSyncedAt,
                    l10n: l10n,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SummaryPill(
                      label: l10n.runbooksCount(manifest?.checklistCount ?? 0),
                    ),
                    _SummaryPill(
                      label: l10n.favoritesCount(
                        favoritesState.value?.length ?? 0,
                      ),
                    ),
                    _SummaryPill(
                      label: l10n.recentCount(
                        recentState.value?.length ?? 0,
                      ),
                    ),
                    _SummaryPill(
                      label: l10n.searchesCount(
                        recentSearchesState.value?.length ?? 0,
                      ),
                    ),
                  ],
                ),
                if (contentSyncState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.localizeContentError(contentSyncState.errorMessage!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  if (contentSyncState.hasContent) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.importedContentFallbackNotice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF526071),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: () => context.go('/settings'),
                  child: Text(l10n.manageLibrary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: l10n.topMatches,
            child: lookupState.when(
              data: (result) {
                if (result == null || result.candidates.isEmpty) {
                  return _EmptyState(
                    title: l10n.waitingForInput,
                    description: l10n.waitingForInputDescription,
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
                          query: result.query,
                          matchHints: ref.watch(
                            matchHintsProvider((
                              result.query,
                              entry.value.checklist,
                            )),
                          ),
                          isFavorite:
                              favoritesState.value?.contains(
                                entry.value.checklist.id,
                              ) ??
                              false,
                          isExpanded:
                              _expandedChecklistId == entry.value.checklist.id,
                          onTap: () => context.push(
                            '/checklists/${entry.value.checklist.id}?title=${Uri.encodeComponent(entry.value.checklist.title)}',
                          ),
                          onExpandTap: () =>
                              _toggleExpanded(entry.value.checklist.id),
                          onCopyFirstAction: () =>
                              _copyFirstAction(entry.value.checklist),
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
                title: l10n.searchFailed,
                description: l10n.localizeContentError(error.toString()),
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
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onPressed);
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    required this.title,
    required this.suggestions,
    required this.onSuggestionTap,
    this.onClear,
    this.showClear = false,
  });

  final String title;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;
  final VoidCallback? onClear;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return Text(
        title == context.l10n.recentSearchesTitle
            ? context.l10n.recentSearchesEmpty
            : context.l10n.suggestionsEmpty,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF526071)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (showClear && onClear != null)
              TextButton(onPressed: onClear, child: Text(context.l10n.clear)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: suggestions
              .map(
                (item) => ActionChip(
                  label: Text(item),
                  onPressed: () => onSuggestionTap(item),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.rank,
    required this.item,
    required this.query,
    required this.matchHints,
    required this.isExpanded,
    required this.onTap,
    required this.onExpandTap,
    required this.onCopyFirstAction,
    required this.onFavoriteTap,
    required this.isFavorite,
  });

  final int rank;
  final RankedChecklist item;
  final String query;
  final List<String> matchHints;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onExpandTap;
  final VoidCallback onCopyFirstAction;
  final VoidCallback onFavoriteTap;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return RunbookCardFrame(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.primary,
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
                    color: const Color(0xFF526071),
                  ),
                ),
                if (matchHints.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.matchSignalsFor(query),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF526071),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: matchHints
                        .map(
                          (hint) => InfoPill(
                            label: context.l10n.localizeMatchHint(hint),
                          ),
                        )
                        .toList(),
                  ),
                ],
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: Text(
                        isExpanded
                            ? context.l10n.hidePreview
                            : context.l10n.showPreview,
                      ),
                      onPressed: onExpandTap,
                    ),
                    if (item.checklist.immediateActions.isNotEmpty)
                      ActionChip(
                        label: Text(context.l10n.copyFirstAction),
                        onPressed: onCopyFirstAction,
                      ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 10),
                  _PreviewPanel(
                    summary: buildChecklistPreviewForTest(
                      item.checklist,
                      l10n: context.l10n,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onFavoriteTap,
            icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_border),
            tooltip: isFavorite ? context.l10n.saved : context.l10n.save,
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(summary, style: Theme.of(context).textTheme.bodyMedium),
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
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(8),
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

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return InfoPill(label: label);
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

String buildHomeSyncSummaryForTest({
  required ContentSource source,
  required ContentManifest? manifest,
  required DateTime? lastSyncedAt,
  AppLocalizations? l10n,
}) {
  final strings = l10n ?? AppLocalizations.english;
  final version = manifest == null
      ? strings.notLoadedLabel.toLowerCase()
      : manifest.version.substring(
          0,
          manifest.version.length > 8 ? 8 : manifest.version.length,
        );
  final sourceLabel = switch (source) {
    ContentSource.bundled => strings.bundledLibrary,
    ContentSource.imported => strings.importedPackage,
    ContentSource.none => strings.noLibrary,
  };
  if (source == ContentSource.imported && lastSyncedAt != null) {
    return strings.versionFromSourceUpdated(
      version,
      sourceLabel,
      _formatSyncTime(lastSyncedAt),
    );
  }
  return strings.versionFromSource(version, sourceLabel);
}

String buildChecklistPreviewForTest(
  Checklist checklist, {
  AppLocalizations? l10n,
}) {
  final strings = l10n ?? AppLocalizations.english;
  final lines = <String>[];
  if (checklist.symptoms.isNotEmpty) {
    lines.add(strings.previewSymptoms(checklist.symptoms.take(2).join(' / ')));
  }
  if (checklist.immediateActions.isNotEmpty) {
    final nextSteps = checklist.immediateActions
        .take(2)
        .map((step) => '${step.step}. ${step.action}')
        .join(' | ');
    lines.add(strings.previewNext(nextSteps));
  }
  if (checklist.rootCause.isNotEmpty) {
    lines.add(strings.previewRootCause(checklist.rootCause.first));
  }
  if (lines.isEmpty) {
    return checklist.title;
  }
  return lines.join('\n');
}
