import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import 'knowledge_controller.dart';
import 'knowledge_widgets.dart';

class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  String? _activeDeckId;
  StudyCard? _reviewingCard;
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final decks = ref.watch(studyDecksProvider);
    final cards = ref.watch(studyCardsProvider);
    final states = ref.watch(reviewStatesProvider).value ?? const <String, ReviewState>{};
    final dueCards = ref.watch(dueCardsProvider);
    final generation = ref.watch(cardGenerationProvider);
    final activeCards = _activeDeckId == null
        ? cards
        : cards.where((card) => card.deckId == _activeDeckId).toList();
    final reviewCard = _reviewingCard ?? (dueCards.isNotEmpty ? dueCards.first : null);

    return Scaffold(
      appBar: AppBar(title: const Text('Cards')),
      body: KnowledgePageFrame(
        safeTop: false,
        children: [
          KnowledgeSection(
            title: 'Review Queue',
            trailing: FilledButton.tonalIcon(
              onPressed: ref.watch(studyMaterialsProvider).isEmpty
                  ? null
                  : () => ref
                      .read(cardGenerationProvider.notifier)
                      .generate(materialIds: const [], limit: 6),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    KnowledgePill(label: '${dueCards.length} due today'),
                    KnowledgePill(label: '${cards.length} total cards'),
                    KnowledgePill(label: '${decks.length} decks'),
                  ],
                ),
                if (generation.isLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                generation.when(
                  data: (result) {
                    if (result == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        result.notice ?? 'Generated ${result.cards.length} cards.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF526071),
                        ),
                      ),
                    );
                  },
                  error: (error, stackTrace) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error.toString(),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          KnowledgeSection(
            title: 'Review',
            child: reviewCard == null
                ? const KnowledgeEmptyState(
                    title: 'Nothing due',
                    description: 'Cards will return here when their next review time arrives.',
                    icon: Icons.check_circle_outline,
                  )
                : _ReviewPanel(
                    card: reviewCard,
                    state: states[reviewCard.id],
                    showAnswer: _showAnswer,
                    onShowAnswer: () => setState(() => _showAnswer = true),
                    onGrade: (grade) async {
                      await ref
                          .read(reviewStatesProvider.notifier)
                          .review(cardId: reviewCard.id, grade: grade);
                      final nextDue = ref.read(dueCardsProvider)
                          .where((card) => card.id != reviewCard.id)
                          .toList();
                      setState(() {
                        _showAnswer = false;
                        _reviewingCard = nextDue.isEmpty ? null : nextDue.first;
                      });
                    },
                  ),
          ),
          const SizedBox(height: 18),
          KnowledgeSection(
            title: 'Decks',
            child: decks.isEmpty
                ? const Text('No decks yet.')
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _activeDeckId == null,
                        onSelected: (_) => setState(() => _activeDeckId = null),
                      ),
                      ...decks.map(
                        (deck) => ChoiceChip(
                          label: Text('${deck.title} (${deck.cardIds.length})'),
                          selected: _activeDeckId == deck.id,
                          onSelected: (_) => setState(() => _activeDeckId = deck.id),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          KnowledgeSection(
            title: 'Cards',
            child: activeCards.isEmpty
                ? const KnowledgeEmptyState(
                    title: 'No cards',
                    description: 'Import a bundle with cards or configure the sidecar and model to generate new cards.',
                    icon: Icons.style_outlined,
                  )
                : Column(
                    children: activeCards
                        .map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: StudyCardTile(
                              card: card,
                              state: states[card.id],
                              onTap: () => setState(() {
                                _reviewingCard = card;
                                _showAnswer = false;
                              }),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.card,
    required this.state,
    required this.showAnswer,
    required this.onShowAnswer,
    required this.onGrade,
  });

  final StudyCard card;
  final ReviewState? state;
  final bool showAnswer;
  final VoidCallback onShowAnswer;
  final ValueChanged<ReviewGrade> onGrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KnowledgePill(label: buildCardMasteryLabel(state)),
            KnowledgePill(label: 'due ${compactDate(state?.dueAt)}'),
          ],
        ),
        const SizedBox(height: 14),
        Text(card.front, style: theme.textTheme.titleLarge),
        if (showAnswer) ...[
          const SizedBox(height: 14),
          Text(card.back, style: theme.textTheme.bodyLarge),
          if (card.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              card.explanation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF526071),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ReviewGrade.values
                .map(
                  (grade) => FilledButton.tonal(
                    onPressed: () => onGrade(grade),
                    child: Text(reviewGradeLabel(grade)),
                  ),
                )
                .toList(),
          ),
        ] else ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onShowAnswer,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Show answer'),
          ),
        ],
      ],
    );
  }
}
