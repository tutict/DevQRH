import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'knowledge_controller.dart';
import 'knowledge_widgets.dart';

class KnowledgeHomeScreen extends ConsumerStatefulWidget {
  const KnowledgeHomeScreen({super.key});

  @override
  ConsumerState<KnowledgeHomeScreen> createState() => _KnowledgeHomeScreenState();
}

class _KnowledgeHomeScreenState extends ConsumerState<KnowledgeHomeScreen> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  String _liveQuery = '';

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
      ref.read(knowledgeSearchProvider.notifier).search(value);
    });
  }

  void _submit(String value, {bool syncInput = false}) {
    final query = value.trim();
    if (syncInput) {
      _queryController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    setState(() => _liveQuery = query);
    ref.read(knowledgeSearchProvider.notifier).search(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncState = ref.watch(knowledgeSyncProvider);
    final bundle = syncState.bundle;
    final dueCards = ref.watch(dueCardsProvider);
    final recentMaterials = ref.watch(recentMaterialItemsProvider);
    final recentQueries = ref.watch(recentQueriesProvider).value ?? const [];
    final suggestions = ref.watch(searchSuggestionsProvider(_liveQuery));
    final searchState = ref.watch(knowledgeSearchProvider);

    return Scaffold(
      body: KnowledgePageFrame(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('应手', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Offline-first learning, review, and local RAG.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF526071),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.go('/library'),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Library'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              KnowledgePill(label: '${bundle?.materials.length ?? 0} materials'),
              KnowledgePill(label: '${bundle?.cards.length ?? 0} cards'),
              KnowledgePill(label: '${dueCards.length} due today'),
              KnowledgePill(label: knowledgeSourceLabel(syncState.source)),
            ],
          ),
          const SizedBox(height: 18),
          KnowledgeSection(
            title: 'Search Materials',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _queryController,
                  onChanged: _onQueryChanged,
                  onSubmitted: (value) => _submit(value, syncInput: true),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'English vocabulary / SQL index / project API',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                _SuggestionChips(
                  suggestions: suggestions,
                  emptyLabel: recentQueries.isEmpty
                      ? 'Recent queries appear here after your first search.'
                      : 'No suggestion for this input yet.',
                  onTap: (value) => _submit(value, syncInput: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          KnowledgeSection(
            title: 'Today',
            trailing: TextButton(
              onPressed: () => context.go('/cards'),
              child: const Text('Review'),
            ),
            child: dueCards.isEmpty
                ? const KnowledgeEmptyState(
                    title: 'No cards due',
                    description: 'Generated and bundled cards will appear here when they are due.',
                    icon: Icons.check_circle_outline,
                  )
                : Column(
                    children: dueCards
                        .take(3)
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
            title: 'Search Results',
            child: searchState.when(
              data: (result) {
                if (result == null || result.candidates.isEmpty) {
                  return const KnowledgeEmptyState(
                    title: 'Waiting for a query',
                    description: 'Search local study material. If the sidecar is unavailable, Flutter uses the offline matcher.',
                    icon: Icons.manage_search_outlined,
                  );
                }
                return Column(
                  children: result.candidates
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: MaterialListTileCard(
                            material: item.material,
                            score: item.score,
                            onTap: () {
                              ref
                                  .read(recentMaterialsProvider.notifier)
                                  .push(item.material.id);
                              context.push('/materials/${item.material.id}');
                            },
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              error: (error, stackTrace) => KnowledgeEmptyState(
                title: 'Search failed',
                description: error.toString(),
                icon: Icons.error_outline,
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          KnowledgeSection(
            title: 'Continue Learning',
            child: recentMaterials.isEmpty
                ? const KnowledgeEmptyState(
                    title: 'No recent material',
                    description: 'Open a material from search or the library to build your recent list.',
                    icon: Icons.history_outlined,
                  )
                : Column(
                    children: recentMaterials
                        .take(4)
                        .map(
                          (material) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: MaterialListTileCard(
                              material: material,
                              onTap: () => context.push('/materials/${material.id}'),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 18),
          KnowledgeSection(
            title: 'Quick Questions',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ActionChip(
                  label: const Text('考研英语 长难句'),
                  onPressed: () => _submit('考研英语 长难句', syncInput: true),
                ),
                ActionChip(
                  label: const Text('CET-6 vocabulary'),
                  onPressed: () => _submit('CET-6 vocabulary', syncInput: true),
                ),
                ActionChip(
                  label: const Text('API error handling'),
                  onPressed: () => _submit('API error handling', syncInput: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({
    required this.suggestions,
    required this.emptyLabel,
    required this.onTap,
  });

  final List<String> suggestions;
  final String emptyLabel;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return Text(
        emptyLabel,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF526071),
        ),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: suggestions
          .map((item) => ActionChip(label: Text(item), onPressed: () => onTap(item)))
          .toList(),
    );
  }
}
