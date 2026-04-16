import 'package:flutter/material.dart';

import '../../../app/i18n/app_localizations.dart';
import 'lookup_controller.dart';
import 'shared_panels.dart';

class PageOverviewCard extends StatelessWidget {
  const PageOverviewCard({
    super.key,
    required this.title,
    required this.description,
    required this.pills,
  });

  final String title;
  final String description;
  final List<String> pills;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6A6058)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: pills.map((pill) => InfoPill(label: pill)).toList(),
          ),
        ],
      ),
    );
  }
}

String contentSourceShortLabel(
  ContentSource source, {
  AppLocalizations? l10n,
}) {
  final strings = l10n ?? AppLocalizations.english;
  return switch (source) {
    ContentSource.bundled => strings.bundledShort,
    ContentSource.imported => strings.importedShort,
    ContentSource.none => strings.offlineShort,
  };
}
