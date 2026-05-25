import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n/app_localizations.dart';
import '../../../app/i18n/locale_controller.dart';
import '../domain/models.dart';
import 'lookup_controller.dart';
import 'page_overview_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentSyncState = ref.watch(contentSyncProvider);
    final manifest = contentSyncState.bootstrap?.manifest;
    final localeMode = ref.watch(appLocaleModeProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          IconButton(
            onPressed: () => context.push('/catalog'),
            icon: const Icon(Icons.grid_view_outlined),
            tooltip: l10n.catalog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          PageOverviewCard(
            title: l10n.libraryStatus,
            description: buildSettingsOverviewForTest(
              manifest: manifest,
              state: contentSyncState,
              l10n: l10n,
            ),
            pills: [
              'v${_shortVersion(manifest)}',
              _contentSourceLabel(contentSyncState.source, l10n: l10n),
              contentSyncState.hasContent ? l10n.ready : l10n.empty,
            ],
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            title: l10n.handbookLibrary,
            lines: [
              l10n.version,
              _shortVersion(manifest, l10n: l10n),
              l10n.runbooksLabel,
              '${manifest?.checklistCount ?? 0}',
              l10n.source,
              _contentSourceLabel(contentSyncState.source, l10n: l10n),
              l10n.updated,
              _formatSyncTime(contentSyncState.lastSyncedAt, l10n: l10n),
            ],
            actions: [
              FilledButton.tonalIcon(
                onPressed: contentSyncState.isSyncing
                    ? null
                    : () => _importPackage(context, ref),
                icon: const Icon(Icons.upload_file),
                label: Text(l10n.importPackage),
              ),
              OutlinedButton.icon(
                onPressed: contentSyncState.isSyncing
                    ? null
                    : () => _restoreBundledContent(context, ref),
                icon: const Icon(Icons.restart_alt),
                label: Text(l10n.useBuiltInLibrary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            title: l10n.displayLanguage,
            lines: [l10n.language, l10n.languageModeLabel(localeMode)],
            actions: [
              DropdownButtonFormField<AppLocaleMode>(
                initialValue: localeMode,
                decoration: InputDecoration(
                  labelText: l10n.language,
                  prefixIcon: const Icon(Icons.language),
                ),
                items: AppLocaleMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(l10n.languageModeLabel(mode)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  ref.read(appLocaleModeProvider.notifier).setMode(value);
                },
              ),
            ],
          ),
          if (contentSyncState.errorMessage != null) ...[
            const SizedBox(height: 14),
            _SettingsCard(
              title: l10n.lastIssue,
              lines: [
                l10n.issue,
                l10n.localizeContentError(contentSyncState.errorMessage!),
                l10n.fallback,
                contentSyncState.hasContent
                    ? l10n.currentHandbookStaysAvailable
                    : l10n.noHandbookLoaded,
              ],
            ),
          ],
          const SizedBox(height: 14),
          _SettingsCard(
            title: l10n.packageFormat,
            lines: [
              l10n.accepted,
              l10n.jsonPackage,
              l10n.fields,
              'manifest, matchingConfig, checklists',
              l10n.tip,
              l10n.standalonePackageTip,
            ],
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            title: l10n.appScope,
            lines: [
              l10n.purpose,
              l10n.singleAppIncidentHandbook,
              l10n.delivery,
              'Android / iOS / Web / Desktop',
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _importPackage(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'devqrh'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectedPackageEmpty)));
      return;
    }

    final imported = await ref
        .read(contentSyncProvider.notifier)
        .importPackage(utf8.decode(bytes));
    if (!context.mounted) {
      return;
    }

    final rawMessage =
        ref.read(contentSyncProvider).errorMessage ?? l10n.importFailed;
    final message = imported
        ? l10n.importedPackageMessage(file.name)
        : l10n.localizeContentError(rawMessage);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restoreBundledContent(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref.read(contentSyncProvider.notifier).restoreBundledContent();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.builtInLibraryRestored)),
    );
  }
}

String buildSettingsOverviewForTest({
  required ContentManifest? manifest,
  required ContentSyncState state,
  AppLocalizations? l10n,
}) {
  final strings = l10n ?? AppLocalizations.english;
  return strings.settingsOverview(
    _shortVersion(manifest, l10n: strings),
    _contentSourceLabel(state.source, l10n: strings),
    state.hasContent ? strings.ready : strings.empty,
  );
}

String _shortVersion(ContentManifest? manifest, {AppLocalizations? l10n}) {
  if (manifest == null) {
    return (l10n ?? AppLocalizations.english).notLoadedLabel;
  }

  return manifest.version.substring(
    0,
    manifest.version.length > 8 ? 8 : manifest.version.length,
  );
}

String _contentSourceLabel(ContentSource source, {AppLocalizations? l10n}) {
  final strings = l10n ?? AppLocalizations.english;
  return switch (source) {
    ContentSource.bundled => strings.bundledShort,
    ContentSource.imported => strings.importedShort,
    ContentSource.none => strings.offlineShort,
  };
}

String _formatSyncTime(DateTime? value, {AppLocalizations? l10n}) {
  if (value == null) {
    return (l10n ?? AppLocalizations.english).builtInLabel;
  }

  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.lines,
    this.actions = const [],
  });

  final String title;
  final List<String> lines;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (var i = 0; i < lines.length; i += 2) ...[
            Text(
              lines[i],
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6A6058)),
            ),
            const SizedBox(height: 4),
            Text(lines[i + 1]),
            if (i < lines.length - 2) const SizedBox(height: 12),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}
