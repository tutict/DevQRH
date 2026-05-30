import 'package:flutter/material.dart';

class RunbookCardFrame extends StatelessWidget {
  const RunbookCardFrame({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 8,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: child,
      ),
    );
  }
}

class RunbookCard extends StatelessWidget {
  const RunbookCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
    this.labels = const [],
    this.borderRadius = 8,
    this.padding = const EdgeInsets.all(14),
    this.titleSubtitleSpacing = 6,
    this.subtitleLabelsSpacing = 10,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget trailing;
  final List<String> labels;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double titleSubtitleSpacing;
  final double subtitleLabelsSpacing;

  @override
  Widget build(BuildContext context) {
    return RunbookCardFrame(
      onTap: onTap,
      borderRadius: borderRadius,
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: titleSubtitleSpacing),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF526071),
                  ),
                ),
                if (labels.isNotEmpty) ...[
                  SizedBox(height: subtitleLabelsSpacing),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: labels
                        .map((label) => Chip(label: Text(label)))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}
