import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models.dart';
import 'knowledge_controller.dart';
import 'knowledge_widgets.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';
  MaterialType? _type;
  String? _tag;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncState = ref.watch(knowledgeSyncProvider);
    final materials = ref.watch(studyMaterialsProvider);
    final favorites = ref.watch(favoriteMaterialsProvider).value ?? const [];
    final tags = _topTags(materials);
    final filtered = _filterMaterials(materials, favorites);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Import package',
          ),
        ],
      ),
      body: KnowledgePageFrame(
        safeTop: false,
        children: [
          KnowledgeSection(
            title: 'Materials',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _filterController,
                  onChanged: (value) => setState(() => _filter = value),
                  decoration: InputDecoration(
                    hintText: 'Filter by title, tag, summary, or content',
                    prefixIcon: const Icon(Icons.filter_list),
                    suffixIcon: _filter.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _filterController.clear();
                              setState(() => _filter = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilterChip(
                      label: const Text('Favorites'),
                      selected: _tag == _favoriteTag,
                      onSelected: (_) => setState(() {
                        _tag = _tag == _favoriteTag ? null : _favoriteTag;
                      }),
                    ),
                    ...MaterialType.values.map(
                      (type) => FilterChip(
                        label: Text(materialTypeLabel(type)),
                        selected: _type == type,
                        onSelected: (_) => setState(() {
                          _type = _type == type ? null : type;
                        }),
                      ),
                    ),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: tags
                        .map(
                          (tag) => FilterChip(
                            label: Text(tag),
                            selected: _tag == tag,
                            onSelected: (_) => setState(() {
                              _tag = _tag == tag ? null : tag;
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    KnowledgePill(label: '${filtered.length} visible'),
                    KnowledgePill(label: '${materials.length} total'),
                    KnowledgePill(label: knowledgeSourceLabel(syncState.source)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!syncState.hasContent)
            const KnowledgeEmptyState(
              title: 'No learning bundle loaded',
              description: 'Restore the built-in bundle or import a JSON learning bundle in Settings.',
              icon: Icons.folder_off_outlined,
            )
          else if (filtered.isEmpty)
            const KnowledgeEmptyState(
              title: 'No matching material',
              description: 'Clear filters or try a broader keyword.',
              icon: Icons.search_off_outlined,
            )
          else ...[
            Text('Browse', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...filtered.map(
              (material) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MaterialListTileCard(
                  material: material,
                  onTap: () {
                    ref.read(recentMaterialsProvider.notifier).push(material.id);
                    context.push('/materials/${material.id}');
                  },
                  trailing: IconButton(
                    onPressed: () => ref
                        .read(favoriteMaterialsProvider.notifier)
                        .toggle(material.id),
                    icon: Icon(
                      favorites.contains(material.id)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                    tooltip: favorites.contains(material.id)
                        ? 'Saved'
                        : 'Save material',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<StudyMaterial> _filterMaterials(
    List<StudyMaterial> materials,
    List<String> favorites,
  ) {
    final filter = _filter.trim().toLowerCase();
    return materials.where((material) {
      if (_type != null && material.type != _type) {
        return false;
      }
      if (_tag == _favoriteTag && !favorites.contains(material.id)) {
        return false;
      }
      if (_tag != null &&
          _tag != _favoriteTag &&
          !material.tags.any((tag) => tag.toLowerCase() == _tag!.toLowerCase())) {
        return false;
      }
      if (filter.isEmpty) {
        return true;
      }
      final haystack = [
        material.id,
        material.title,
        material.summary,
        material.content,
        material.source,
        material.type.name,
        ...material.tags,
        ...material.chunks,
      ].join(' ').toLowerCase();
      return haystack.contains(filter);
    }).toList()
      ..sort((left, right) => left.title.compareTo(right.title));
  }

  List<String> _topTags(List<StudyMaterial> materials) {
    final counts = <String, int>{};
    for (final material in materials) {
      for (final tag in material.tags) {
        final normalized = tag.trim();
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
}

const String _favoriteTag = '__favorite__';
