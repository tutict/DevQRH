import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import 'lookup_controller.dart';

class ChecklistDetailScreen extends ConsumerWidget {
  const ChecklistDetailScreen({
    super.key,
    required this.checklistId,
    required this.titleHint,
  });

  final String checklistId;
  final String titleHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistState = ref.watch(checklistDetailProvider(checklistId));
    final favorites = ref.watch(favoritesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(titleHint.isEmpty ? 'Checklist' : titleHint),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(favoritesProvider.notifier).toggle(checklistId),
            icon: Icon(
              favorites.contains(checklistId)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
          ),
        ],
      ),
      body: checklistState.when(
        data: (checklist) {
          ref.read(recentProvider.notifier).push(checklist.id);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                checklist.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: checklist.keywords
                    .map((keyword) => Chip(label: Text(keyword)))
                    .toList(),
              ),
              const SizedBox(height: 20),
              _DetailSection(
                title: 'Immediate Actions',
                child: Column(
                  children: checklist.immediateActions
                      .map((step) => _StepLine(step: step))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Decision Tree',
                child: Column(
                  children: checklist.decisionTree
                      .map(
                        (branch) => _LinePair(
                          left: branch.condition,
                          right: branch.action,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Symptoms',
                child: _BulletList(items: checklist.symptoms),
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Root Cause',
                child: _BulletList(items: checklist.rootCause),
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Long Term Fix',
                child: _BulletList(items: checklist.longTermFix),
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.step});

  final ChecklistStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${step.step}.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(step.action)),
        ],
      ),
    );
  }
}

class _LinePair extends StatelessWidget {
  const _LinePair({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              left,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(right)),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('- '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
