import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n/app_localizations.dart';
import '../domain/models.dart';
import 'lookup_controller.dart';
import 'runbook_cards.dart';
import 'shared_panels.dart';

class AgentScreen extends ConsumerStatefulWidget {
  const AgentScreen({super.key});

  @override
  ConsumerState<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends ConsumerState<AgentScreen> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runAgent([String? rawValue]) {
    final value = (rawValue ?? _queryController.text).trim();
    _queryController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    return ref.read(agentControllerProvider.notifier).navigate(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final agentState = ref.watch(agentControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text(l10n.agentTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              l10n.agentIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5B5148),
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: l10n.agentInputTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _queryController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _runAgent,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.agentInputHint,
                      prefixIcon: const Icon(Icons.psychology_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => _runAgent(),
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(l10n.agentRun),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: l10n.agentQuickPrompts,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PromptChip(
                    label: 'service lag after deploy',
                    onPressed: () => _runAgent('service lag after deploy'),
                  ),
                  _PromptChip(
                    label: 'cpu and db spike',
                    onPressed: () => _runAgent('cpu and db spike'),
                  ),
                  _PromptChip(
                    label: 'timeout query and memory growth',
                    onPressed: () =>
                        _runAgent('timeout query and memory growth'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            agentState.when(
              data: (response) {
                if (response == null) {
                  return EmptyContentState(
                    title: l10n.agentWaitingTitle,
                    description: l10n.agentWaitingDescription,
                  );
                }
                return _AgentResultPanel(response: response);
              },
              error: (error, stackTrace) => EmptyContentState(
                title: l10n.agentFailed,
                description: l10n.localizeContentError(error.toString()),
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
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onPressed);
  }
}

class _AgentResultPanel extends StatelessWidget {
  const _AgentResultPanel({required this.response});

  final AgentNavigationResponse response;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bestMatch = response.bestMatch;
    final ragAnswer = response.ragAnswer;
    final alternatives = response.candidates
        .where((item) => item.checklist.id != bestMatch?.checklist.id)
        .toList();

    return Column(
      children: [
        if (ragAnswer != null && ragAnswer.answer.trim().isNotEmpty) ...[
          SectionCard(
            title: l10n.ragAnswerTitle,
            child: _RagAnswerCard(answer: ragAnswer),
          ),
          const SizedBox(height: 18),
        ],
        if (bestMatch != null) ...[
          SectionCard(
            title: l10n.agentBestMatch,
            child: _AgentBestMatchCard(item: bestMatch),
          ),
          const SizedBox(height: 18),
        ],
        SectionCard(
          title: l10n.agentClarifiers,
          child: response.clarifiers.isEmpty
              ? Text(
                  l10n.agentNoClarifiers,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6A6058),
                  ),
                )
              : Column(
                  children: response.clarifiers
                      .map(
                        (item) =>
                            _ClarifierLine(value: l10n.localizeClarifier(item)),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: l10n.agentAlternatives,
          child: alternatives.isEmpty
              ? Text(
                  l10n.agentNoCandidates,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6A6058),
                  ),
                )
              : Column(
                  children: alternatives
                      .map((item) => _AgentAlternativeCard(item: item))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _RagAnswerCard extends StatelessWidget {
  const _RagAnswerCard({required this.answer});

  final RagAnswerResponse answer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InfoPill(label: _ragModeLabel(answer, l10n)),
            if (answer.model != null && answer.model!.trim().isNotEmpty)
              InfoPill(label: answer.model!),
          ],
        ),
        const SizedBox(height: 12),
        if (answer.notice != null && answer.notice!.trim().isNotEmpty) ...[
          Text(
            answer.notice!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6A6058),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(answer.answer, style: theme.textTheme.bodyMedium),
        if (answer.citations.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(l10n.ragSources, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: answer.citations
                .take(3)
                .map(
                  (citation) => InfoPill(
                    label:
                        '${citation.title} ${citation.score.toStringAsFixed(2)}',
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  String _ragModeLabel(RagAnswerResponse answer, AppLocalizations l10n) {
    return switch (answer.mode) {
      'llm' => l10n.ragLlmMode,
      'local_fallback' => l10n.ragLocalFallbackMode,
      _ => l10n.ragLocalMode,
    };
  }
}

class _AgentBestMatchCard extends StatelessWidget {
  const _AgentBestMatchCard({required this.item});

  final RankedChecklist item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return RunbookCardFrame(
      onTap: () => context.push(
        '/checklists/${item.checklist.id}?title=${Uri.encodeComponent(item.checklist.title)}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.checklist.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            item.checklist.symptoms.take(2).join(' / '),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6A6058)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoPill(
                label: '${l10n.agentScore} ${item.score.toStringAsFixed(2)}',
              ),
              ...item.checklist.keywords
                  .take(3)
                  .map((keyword) => Chip(label: Text(keyword))),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            onPressed: () => context.push(
              '/checklists/${item.checklist.id}?title=${Uri.encodeComponent(item.checklist.title)}',
            ),
            child: Text(l10n.agentOpenRunbook),
          ),
        ],
      ),
    );
  }
}

class _AgentAlternativeCard extends StatelessWidget {
  const _AgentAlternativeCard({required this.item});

  final RankedChecklist item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RunbookCard(
        title: item.checklist.title,
        subtitle: item.checklist.symptoms.take(2).join(' / '),
        labels: item.checklist.keywords.take(2).toList(),
        onTap: () => context.push(
          '/checklists/${item.checklist.id}?title=${Uri.encodeComponent(item.checklist.title)}',
        ),
        trailing: Column(
          children: [
            Text(
              item.score.toStringAsFixed(2),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.agentScore,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6A6058)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClarifierLine extends StatelessWidget {
  const _ClarifierLine({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.arrow_outward, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
