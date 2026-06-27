import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/i18n/locale_controller.dart';
import '../../../app/theme/theme_controller.dart';
import 'knowledge_controller.dart';
import 'knowledge_widgets.dart';

class KnowledgeSettingsScreen extends ConsumerWidget {
  const KnowledgeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(knowledgeSyncProvider);
    final bundle = syncState.bundle;
    final localeMode = ref.watch(appLocaleModeProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: KnowledgePageFrame(
        safeTop: false,
        children: [
          KnowledgeSection(
            title: 'Local Data',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    KnowledgePill(label: 'v${_shortVersion(bundle?.manifest.version)}'),
                    KnowledgePill(label: knowledgeSourceLabel(syncState.source)),
                    KnowledgePill(label: syncState.hasContent ? 'Ready' : 'Empty'),
                  ],
                ),
                const SizedBox(height: 12),
                _KeyValue(label: 'Package', value: bundle?.manifest.name ?? 'Not loaded'),
                _KeyValue(label: 'Materials', value: '${bundle?.materials.length ?? 0}'),
                _KeyValue(label: 'Decks', value: '${bundle?.decks.length ?? 0}'),
                _KeyValue(label: 'Cards', value: '${bundle?.cards.length ?? 0}'),
                _KeyValue(label: 'Updated', value: compactDate(syncState.lastSyncedAt)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: syncState.isSyncing ? null : () => _importPackage(context, ref),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import JSON bundle'),
                    ),
                    OutlinedButton.icon(
                      onPressed: syncState.isSyncing
                          ? null
                          : () => ref.read(knowledgeSyncProvider.notifier).restoreBundledContent(),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Restore built-in'),
                    ),
                  ],
                ),
                if (syncState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    syncState.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          KnowledgeSection(
            title: 'Model Configuration',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI card generation and tutor answers use the Go sidecar when available.'),
                SizedBox(height: 8),
                Text('Set DEVQRH_LLM_API_KEY, DEVQRH_LLM_BASE_URL, and DEVQRH_LLM_MODEL for an OpenAI-compatible provider. Without a model, search and review stay offline.'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          KnowledgeSection(
            title: 'Learning Package Health',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KeyValue(label: 'Schema', value: '${bundle?.manifest.schemaVersion ?? '-'}'),
                _KeyValue(label: 'Locale', value: bundle?.manifest.defaultLocale ?? '-'),
                _KeyValue(label: 'Source type', value: bundle?.manifest.sourceType ?? '-'),
                _KeyValue(
                  label: 'Validation warnings',
                  value: '${bundle?.validationReport.warnings.length ?? 0}',
                ),
                _KeyValue(
                  label: 'Validation errors',
                  value: '${bundle?.validationReport.errors.length ?? 0}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          KnowledgeSection(
            title: 'Display',
            child: Column(
              children: [
                DropdownButtonFormField<AppLocaleMode>(
                  initialValue: localeMode,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    prefixIcon: Icon(Icons.language),
                  ),
                  items: const [
                    DropdownMenuItem(value: AppLocaleMode.system, child: Text('Follow system')),
                    DropdownMenuItem(value: AppLocaleMode.english, child: Text('English')),
                    DropdownMenuItem(value: AppLocaleMode.chinese, child: Text('Chinese')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(appLocaleModeProvider.notifier).setMode(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ThemeMode>(
                  initialValue: themeMode,
                  decoration: const InputDecoration(
                    labelText: 'Theme',
                    prefixIcon: Icon(Icons.brightness_6_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('Follow system')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(appThemeModeProvider.notifier).setMode(value);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importPackage(BuildContext context, WidgetRef ref) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected package is empty.')),
      );
      return;
    }
    final imported = await ref
        .read(knowledgeSyncProvider.notifier)
        .importPackage(utf8.decode(bytes));
    if (!context.mounted) {
      return;
    }
    final message = imported
        ? 'Imported ${file.name}'
        : ref.read(knowledgeSyncProvider).errorMessage ?? 'Import failed';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _shortVersion(String? version) {
    if (version == null || version.isEmpty) {
      return 'Not loaded';
    }
    return version.substring(0, version.length > 8 ? 8 : version.length);
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
