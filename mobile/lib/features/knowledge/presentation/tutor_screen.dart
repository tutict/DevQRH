import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'knowledge_controller.dart';
import 'knowledge_widgets.dart';

class TutorScreen extends ConsumerStatefulWidget {
  const TutorScreen({super.key});

  @override
  ConsumerState<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends ConsumerState<TutorScreen> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _ask([String? rawQuery]) async {
    final query = (rawQuery ?? _queryController.text).trim();
    _queryController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    await ref.read(tutorControllerProvider.notifier).ask(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tutorControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ask Materials')),
      body: KnowledgePageFrame(
        safeTop: false,
        children: [
          KnowledgeSection(
            title: 'Question',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _queryController,
                  minLines: 2,
                  maxLines: 5,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _ask,
                  decoration: const InputDecoration(
                    hintText: 'Ask about a concept, exam topic, or project document...',
                    prefixIcon: Icon(Icons.psychology_alt_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _ask(),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Ask'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          KnowledgeSection(
            title: 'Prompt Ideas',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ActionChip(
                  label: const Text('怎么判断英语阅读主旨题？'),
                  onPressed: () => _ask('怎么判断英语阅读主旨题？'),
                ),
                ActionChip(
                  label: const Text('Explain API retry strategy'),
                  onPressed: () => _ask('Explain API retry strategy'),
                ),
                ActionChip(
                  label: const Text('SQL index leftmost prefix'),
                  onPressed: () => _ask('SQL index leftmost prefix'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          state.when(
            data: (answer) {
              if (answer == null) {
                return const KnowledgeEmptyState(
                  title: 'Waiting for a question',
                  description: 'The answer is grounded in local materials. If the sidecar or model is unavailable, local search still works.',
                  icon: Icons.chat_bubble_outline,
                );
              }
              return Column(
                children: [
                  KnowledgeSection(
                    title: 'Answer',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            KnowledgePill(label: _modeLabel(answer.mode)),
                            if (answer.notice != null && answer.notice!.trim().isNotEmpty)
                              KnowledgePill(label: 'notice'),
                          ],
                        ),
                        if (answer.notice != null && answer.notice!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            answer.notice!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF526071),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(answer.answer, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  KnowledgeSection(
                    title: 'Sources',
                    child: answer.citations.isEmpty
                        ? const Text('No cited source returned.')
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: answer.citations
                                .map(
                                  (citation) => ActionChip(
                                    label: Text(
                                      '${citation.title} ${citation.score.toStringAsFixed(2)}',
                                    ),
                                    onPressed: () => context.push('/materials/${citation.id}'),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              );
            },
            error: (error, stackTrace) => KnowledgeEmptyState(
              title: 'Question failed',
              description: error.toString(),
              icon: Icons.error_outline,
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(String mode) {
    return switch (mode) {
      'llm' => 'LLM answer',
      'local_fallback' => 'Local fallback',
      'error' => 'Error',
      _ => 'Local answer',
    };
  }
}
