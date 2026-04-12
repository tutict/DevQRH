import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models.dart';
import 'favorites_screen.dart';
import 'lookup_controller.dart';

class RecentScreen extends ConsumerWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentState = ref.watch(recentProvider);
    final checklistIndex = ref.watch(checklistIndexProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recent')),
      body: recentState.when(
        data: (ids) {
          final items = ids
              .map((id) => checklistIndex[id])
              .whereType<Checklist>()
              .toList();
          if (items.isEmpty) {
            return const EmptyTabState(
              title: 'No recent items',
              description: 'Open any checklist and it will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemBuilder: (context, index) {
              final checklist = items[index];
              return ChecklistListTile(
                checklist: checklist,
                subtitle: checklist.symptoms.take(2).join(' / '),
                trailingIcon: Icons.chevron_right,
                onTap: () => context.push(
                  '/checklists/${checklist.id}?title=${Uri.encodeComponent(checklist.title)}',
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemCount: items.length,
          );
        },
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
