import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'knowledge_controller.dart';

class KnowledgePageFrame extends StatelessWidget {
  const KnowledgePageFrame({
    super.key,
    required this.children,
    this.safeTop = true,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 28),
    this.maxWidth = 980,
  });

  final List<Widget> children;
  final bool safeTop;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding.resolve(Directionality.of(context));
    return SafeArea(
      top: safeTop,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 720 ? 24.0 : 16.0;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  resolvedPadding.top,
                  horizontalPadding,
                  resolvedPadding.bottom,
                ),
                children: children,
              ),
            ),
          );
        },
      ),
    );
  }
}

class KnowledgeSection extends StatelessWidget {
  const KnowledgeSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class KnowledgePill extends StatelessWidget {
  const KnowledgePill({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class KnowledgeEmptyState extends StatelessWidget {
  const KnowledgeEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF526071),
            ),
          ),
        ],
      ),
    );
  }
}

class MaterialListTileCard extends StatelessWidget {
  const MaterialListTileCard({
    super.key,
    required this.material,
    required this.onTap,
    this.trailing,
    this.subtitle,
    this.score,
  });

  final StudyMaterial material;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? subtitle;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = subtitle ?? material.summary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_typeIcon(material.type), color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(material.title, style: theme.textTheme.titleMedium),
                  if (detail.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF526071),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      KnowledgePill(label: materialTypeLabel(material.type)),
                      if (score != null)
                        KnowledgePill(label: score!.toStringAsFixed(2)),
                      ...material.tags
                          .take(3)
                          .map((tag) => KnowledgePill(label: tag)),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

class StudyCardTile extends StatelessWidget {
  const StudyCardTile({
    super.key,
    required this.card,
    this.state,
    this.onTap,
    this.trailing,
  });

  final StudyCard card;
  final ReviewState? state;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.front, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    card.back,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF526071),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      KnowledgePill(label: buildCardMasteryLabel(state)),
                      KnowledgePill(label: 'interval ${state?.intervalDays ?? 0}d'),
                      ...card.tags.take(2).map((tag) => KnowledgePill(label: tag)),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

IconData _typeIcon(MaterialType type) {
  return switch (type) {
    MaterialType.exam => Icons.school_outlined,
    MaterialType.engineering => Icons.integration_instructions_outlined,
    MaterialType.course => Icons.menu_book_outlined,
    MaterialType.project => Icons.account_tree_outlined,
    MaterialType.note => Icons.note_alt_outlined,
  };
}

String compactDate(DateTime? value) {
  if (value == null) {
    return 'Never';
  }
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
