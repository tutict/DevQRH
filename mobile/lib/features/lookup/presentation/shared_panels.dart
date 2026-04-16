import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.borderRadius = 24,
    this.titleSpacing = 14,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final Widget child;
  final double borderRadius;
  final double titleSpacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: titleSpacing),
          child,
        ],
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.label,
    this.mediumText = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final String label;
  final bool mediumText;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final baseStyle = mediumText
        ? Theme.of(context).textTheme.bodyMedium
        : Theme.of(context).textTheme.bodySmall;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF2E7D8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: baseStyle?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class EmptyContentState extends StatelessWidget {
  const EmptyContentState({
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
