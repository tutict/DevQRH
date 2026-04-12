import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models.dart';
import 'lookup_controller.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesProvider);
    final checklistIndex = ref.watch(checklistIndexProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favoritesState.when(
        data: (ids) {
          final items = ids
              .map((id) => checklistIndex[id])
              .whereType<Checklist>()
              .toList();
          if (items.isEmpty) {
            return const EmptyTabState(
              title: 'No favorites',
              description:
                  'Bookmark high-frequency runbooks for one-tap access.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemBuilder: (context, index) {
              final checklist = items[index];
              return ChecklistListTile(
                checklist: checklist,
                subtitle: checklist.keywords.take(3).join(' / '),
                trailingIcon: Icons.bookmark,
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

class ChecklistListTile extends StatelessWidget {
  const ChecklistListTile({
    super.key,
    required this.checklist,
    required this.subtitle,
    required this.trailingIcon,
    required this.onTap,
  });

  final Checklist checklist;
  final String subtitle;
  final IconData trailingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    checklist.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6A6058),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(trailingIcon),
          ],
        ),
      ),
    );
  }
}

class EmptyTabState extends StatelessWidget {
  const EmptyTabState({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
