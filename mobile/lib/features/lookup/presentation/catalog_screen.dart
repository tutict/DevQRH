import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n/app_localizations.dart';
import '../../../core/storage/local_store.dart';
import '../domain/models.dart';
import 'lookup_controller.dart';
import 'page_overview_card.dart';
import 'runbook_cards.dart';
import 'shared_panels.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';
  Set<String> _selectedTags = <String>{};
  List<String> _recentTags = const [];
  List<CatalogFilterPreset> _presets = const [];
  CatalogSort _sort = CatalogSort.titleAsc;
  bool _preferencesReady = false;

  @override
  void initState() {
    super.initState();
    _restorePreferences();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _restorePreferences() async {
    final localStore = ref.read(localStoreProvider);
    final snapshot = await localStore.loadCatalogPreferences();
    final presets = await localStore.loadCatalogPresets();
    if (!mounted) {
      return;
    }

    final restoredSort = CatalogSort.values.where(
      (item) => item.name == snapshot.sort,
    );
    final filter = snapshot.filter.trim();
    _filterController.value = TextEditingValue(
      text: filter,
      selection: TextSelection.collapsed(offset: filter.length),
    );

    setState(() {
      _filter = filter;
      _selectedTags = snapshot.selectedTags.toSet();
      _recentTags = snapshot.recentTags;
      _presets = presets;
      _sort = restoredSort.isEmpty ? CatalogSort.titleAsc : restoredSort.first;
      _preferencesReady = true;
    });
  }

  Future<void> _savePreferences() {
    return ref
        .read(localStoreProvider)
        .saveCatalogPreferences(
          filter: _filter,
          selectedTags: _selectedTags.toList(),
          sort: _sort.name,
          recentTags: _recentTags,
        );
  }

  Future<void> _setFilter(String value) async {
    setState(() => _filter = value);
    await _savePreferences();
  }

  Future<void> _toggleTag(String value) async {
    final nextSelectedTags = Set<String>.from(_selectedTags);
    if (nextSelectedTags.contains(value)) {
      nextSelectedTags.remove(value);
    } else {
      nextSelectedTags.add(value);
    }

    final nextRecentTags = value == _favoritesTag
        ? _recentTags
        : List<String>.from(
            [value, ..._recentTags.where((tag) => tag != value)].take(6),
          );

    setState(() {
      _selectedTags = nextSelectedTags;
      _recentTags = nextRecentTags;
    });
    await _savePreferences();
  }

  Future<void> _clearTags() async {
    setState(() => _selectedTags = <String>{});
    await _savePreferences();
  }

  Future<void> _setSort(CatalogSort value) async {
    setState(() => _sort = value);
    await _savePreferences();
  }

  Future<void> _savePreset() async {
    final presetName = await _promptPresetName();
    if (!mounted || presetName == null) {
      return;
    }

    final normalizedName = presetName.trim();
    if (normalizedName.isEmpty) {
      return;
    }

    final nextPreset = CatalogFilterPreset(
      name: normalizedName,
      filter: _filter.trim(),
      selectedTags: _selectedTags.toList()..sort(),
      sort: _sort.name,
    );

    final nextPresets = [
      nextPreset,
      ..._presets.where(
        (preset) => preset.name.toLowerCase() != normalizedName.toLowerCase(),
      ),
    ].take(8).toList();

    setState(() => _presets = nextPresets);
    await ref.read(localStoreProvider).saveCatalogPresets(nextPresets);
  }

  Future<void> _applyPreset(CatalogFilterPreset preset) async {
    final filter = preset.filter.trim();
    final restoredSort = CatalogSort.values.where(
      (item) => item.name == preset.sort,
    );

    _filterController.value = TextEditingValue(
      text: filter,
      selection: TextSelection.collapsed(offset: filter.length),
    );

    setState(() {
      _filter = filter;
      _selectedTags = preset.selectedTags.toSet();
      _sort = restoredSort.isEmpty ? CatalogSort.titleAsc : restoredSort.first;
      _recentTags = [
        ...preset.selectedTags.where((tag) => tag != _favoritesTag),
        ..._recentTags.where((tag) => !preset.selectedTags.contains(tag)),
      ].take(6).cast<String>().toList();
    });
    await _savePreferences();
  }

  Future<void> _deletePreset(String presetName) async {
    final nextPresets = _presets
        .where((preset) => preset.name != presetName)
        .toList();
    setState(() => _presets = nextPresets);
    await ref.read(localStoreProvider).saveCatalogPresets(nextPresets);
  }

  Future<String?> _promptPresetName() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.saveViewDialogTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.saveViewDialogHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(contentSyncProvider);
    final allChecklists = ref.watch(contentCatalogProvider);
    final favorites = ref.watch(favoritesProvider).valueOrNull ?? const [];
    final availableTags = _topTags(allChecklists);
    final recentTags = _visibleRecentTags(allChecklists);
    final filtered = _applyFilters(
      allChecklists,
      _filter,
      _selectedTags,
      favorites,
    );
    final sorted = _applySort(filtered, favorites, _sort);
    final activeSummary = _buildActiveSummary(
      sorted.length,
      allChecklists.length,
      context.l10n,
    );
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.catalog)),
      body: PageFrame(
        safeTop: false,
        children: [
          SectionCard(
            title: l10n.findRunbooks,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.filterRunbooksHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF526071),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.views,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _canSavePreset ? _savePreset : null,
                      icon: const Icon(Icons.bookmark_add),
                      label: Text(l10n.saveView),
                    ),
                  ],
                ),
                if (_presets.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _presets
                        .map(
                          (preset) => InputChip(
                            label: Text(preset.name),
                            onPressed: () => _applyPreset(preset),
                            onDeleted: () => _deletePreset(preset.name),
                          ),
                        )
                        .toList(),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.saveViewHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF526071),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _filterController,
                  onChanged: _setFilter,
                  decoration: InputDecoration(
                    hintText: l10n.filterPlaceholder,
                    prefixIcon: const Icon(Icons.filter_list),
                    suffixIcon: _filter.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () async {
                              _filterController.clear();
                              await _setFilter('');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tags,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (_selectedTags.isNotEmpty)
                      TextButton(
                        onPressed: _clearTags,
                        child: Text(l10n.clearTags),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilterChip(
                      label: Text(l10n.favoritesTab),
                      selected: _selectedTags.contains(_favoritesTag),
                      onSelected: (_) => _toggleTag(_favoritesTag),
                    ),
                    ...availableTags.map(
                      (tag) => FilterChip(
                        label: Text(tag),
                        selected: _selectedTags.contains(tag),
                        onSelected: (_) => _toggleTag(tag),
                      ),
                    ),
                  ],
                ),
                if (recentTags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(l10n.recentTags, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: recentTags
                        .map(
                          (tag) => ActionChip(
                            label: Text(tag),
                            onPressed: () => _toggleTag(tag),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<CatalogSort>(
                  key: ValueKey(_sort),
                  initialValue: _sort,
                  hint: _preferencesReady ? null : Text(l10n.loading),
                  decoration: InputDecoration(
                    labelText: l10n.sort,
                    prefixIcon: const Icon(Icons.swap_vert),
                  ),
                  items: CatalogSort.values
                      .map(
                        (sort) => DropdownMenuItem(
                          value: sort,
                          child: Text(catalogSortLabel(sort, l10n)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _setSort(value);
                  },
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ...activeSummary.map(
                      (item) => InfoPill(label: item, mediumText: true),
                    ),
                    InfoPill(
                      label: l10n.runbooksCount(allChecklists.length),
                      mediumText: true,
                    ),
                    InfoPill(
                      label: l10n.favoritesCount(favorites.length),
                      mediumText: true,
                    ),
                    InfoPill(
                      label: contentSourceShortLabel(
                        syncState.source,
                        l10n: l10n,
                      ),
                      mediumText: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!syncState.hasContent) ...[
            EmptyContentState(
              title: l10n.noHandbookLoadedTitle,
              description: syncState.errorMessage == null
                  ? l10n.noHandbookLoadedDescription
                  : l10n.openSettingsForImportIssue,
            ),
          ] else if (sorted.isEmpty) ...[
            EmptyContentState(
              title: l10n.noMatchingRunbooks,
              description: (_filter.trim().isEmpty && _selectedTags.isEmpty)
                  ? l10n.noRunbookContentAvailable
                  : l10n.broaderFilterHint,
            ),
          ] else ...[
            Text(
              _filter.trim().isEmpty
                  ? (_selectedTags.isEmpty
                        ? l10n.allRunbooks
                        : l10n.filteredBy(
                            _selectedTags
                                .map(
                                  (tag) => tag == _favoritesTag
                                      ? l10n.favoritesTab.toLowerCase()
                                      : tag,
                                )
                                .join(', '),
                          ))
                  : l10n.matchedRunbooks(sorted.length),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...sorted.map(
              (checklist) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CatalogTile(
                  checklist: checklist,
                  subtitle: _buildSubtitle(checklist),
                  isFavorite: favorites.contains(checklist.id),
                  onTap: () => context.push(
                    '/checklists/${checklist.id}?title=${Uri.encodeComponent(checklist.title)}',
                  ),
                  onFavoriteTap: () =>
                      ref.read(favoritesProvider.notifier).toggle(checklist.id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Checklist> _applyFilters(
    List<Checklist> checklists,
    String rawFilter,
    Set<String> selectedTags,
    List<String> favorites,
  ) {
    final filter = rawFilter.trim().toLowerCase();

    return checklists.where((checklist) {
      if (selectedTags.contains(_favoritesTag) &&
          !favorites.contains(checklist.id)) {
        return false;
      }
      for (final selectedTag in selectedTags.where(
        (tag) => tag != _favoritesTag,
      )) {
        if (!checklist.keywords.any(
          (keyword) => keyword.toLowerCase() == selectedTag.toLowerCase(),
        )) {
          return false;
        }
      }
      if (filter.isEmpty) {
        return true;
      }

      final haystack = [
        checklist.title,
        ...checklist.keywords,
        ...checklist.symptoms,
        ...checklist.rootCause,
        ...checklist.longTermFix,
      ].join(' ').toLowerCase();
      return haystack.contains(filter) ||
          checklist.id.toLowerCase().contains(filter);
    }).toList();
  }

  List<Checklist> _applySort(
    List<Checklist> checklists,
    List<String> favorites,
    CatalogSort sort,
  ) {
    final sorted = List<Checklist>.from(checklists);
    sorted.sort((left, right) {
      switch (sort) {
        case CatalogSort.titleAsc:
          return left.title.compareTo(right.title);
        case CatalogSort.titleDesc:
          return right.title.compareTo(left.title);
        case CatalogSort.favoritesFirst:
          final leftFavorite = favorites.contains(left.id);
          final rightFavorite = favorites.contains(right.id);
          final favoriteCompare =
              (rightFavorite ? 1 : 0) - (leftFavorite ? 1 : 0);
          if (favoriteCompare != 0) {
            return favoriteCompare;
          }
          return left.title.compareTo(right.title);
        case CatalogSort.symptomCount:
          final compare = right.symptoms.length.compareTo(left.symptoms.length);
          if (compare != 0) {
            return compare;
          }
          return left.title.compareTo(right.title);
      }
    });
    return sorted;
  }

  List<String> _topTags(List<Checklist> checklists) {
    final counts = <String, int>{};
    for (final checklist in checklists) {
      for (final keyword in checklist.keywords) {
        final normalized = keyword.trim();
        if (normalized.isEmpty) {
          continue;
        }
        counts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final entries = counts.entries.toList()
      ..sort((left, right) {
        final countCompare = right.value.compareTo(left.value);
        if (countCompare != 0) {
          return countCompare;
        }
        return left.key.compareTo(right.key);
      });

    return entries.take(8).map((entry) => entry.key).toList();
  }

  List<String> _visibleRecentTags(List<Checklist> checklists) {
    final validTags = checklists
        .expand((checklist) => checklist.keywords)
        .map((keyword) => keyword.trim())
        .where((keyword) => keyword.isNotEmpty)
        .toSet();

    if (validTags.isEmpty) {
      return _recentTags.take(6).toList();
    }

    return _recentTags.where(validTags.contains).take(6).toList();
  }

  List<String> _buildActiveSummary(
    int matchedCount,
    int totalCount,
    AppLocalizations l10n,
  ) {
    final items = <String>[
      l10n.matchedSummary(matchedCount, totalCount),
      l10n.sortedBy(catalogSortLabel(_sort, l10n)),
    ];

    final normalizedFilter = _filter.trim();
    if (normalizedFilter.isNotEmpty) {
      items.add(l10n.searchSummary(normalizedFilter));
    }

    for (final tag in _selectedTags) {
      items.add(
        tag == _favoritesTag ? l10n.favoritesOnly : l10n.tagSummary(tag),
      );
    }

    return items;
  }

  String _buildSubtitle(Checklist checklist) {
    final symptoms = checklist.symptoms.take(2).join(' / ');
    if (symptoms.isNotEmpty) {
      return symptoms;
    }

    final keywords = checklist.keywords.take(3).join(' / ');
    if (keywords.isNotEmpty) {
      return keywords;
    }

    return checklist.id;
  }

  bool get _canSavePreset =>
      _filter.trim().isNotEmpty ||
      _selectedTags.isNotEmpty ||
      _sort != CatalogSort.titleAsc;
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.checklist,
    required this.subtitle,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Checklist checklist;
  final String subtitle;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return RunbookCard(
      title: checklist.title,
      subtitle: subtitle,
      labels: checklist.keywords.take(3).toList(),
      onTap: onTap,
      trailing: Column(
        children: [
          IconButton(
            onPressed: onFavoriteTap,
            icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_border),
            tooltip: isFavorite ? context.l10n.saved : context.l10n.save,
          ),
          const SizedBox(height: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

enum CatalogSort { titleAsc, titleDesc, favoritesFirst, symptomCount }

const String _favoritesTag = '__favorites__';

String catalogSortLabel(CatalogSort sort, AppLocalizations l10n) {
  return switch (sort) {
    CatalogSort.titleAsc => l10n.titleAsc,
    CatalogSort.titleDesc => l10n.titleDesc,
    CatalogSort.favoritesFirst => l10n.favoritesFirst,
    CatalogSort.symptomCount => l10n.mostSymptoms,
  };
}
