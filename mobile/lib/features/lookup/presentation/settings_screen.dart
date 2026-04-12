import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import 'lookup_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentSyncState = ref.watch(contentSyncProvider);
    final manifest = contentSyncState.bootstrap?.manifest;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _SettingsCard(
            title: 'Endpoint',
            lines: ['API base URL', AppConfig.apiBaseUrl],
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            title: 'Offline content',
            lines: [
              'Manifest version',
              manifest == null
                  ? 'Not synced'
                  : manifest.version.substring(
                      0,
                      manifest.version.length > 8 ? 8 : manifest.version.length,
                    ),
              'Checklist count',
              '${manifest?.checklistCount ?? 0}',
              'Source',
              switch (contentSyncState.source) {
                ContentSource.cache => 'Cache',
                ContentSource.network => 'Network',
                ContentSource.none => 'None',
              },
              'Last sync',
              _formatSyncTime(contentSyncState.lastSyncedAt),
              'Retry status',
              contentSyncState.nextRetryAt == null
                  ? (contentSyncState.errorMessage == null
                        ? 'Healthy'
                        : 'Manual retry required')
                  : 'Auto retry ${contentSyncState.retryCount}/2 at ${_formatSyncTime(contentSyncState.nextRetryAt)}',
            ],
            action: FilledButton.tonal(
              onPressed: contentSyncState.isSyncing
                  ? null
                  : () => ref
                        .read(contentSyncProvider.notifier)
                        .sync(manual: true),
              child: Text(contentSyncState.actionLabel),
            ),
          ),
          if (contentSyncState.errorMessage != null) ...[
            const SizedBox(height: 14),
            _SettingsCard(
              title: 'Sync issue',
              lines: [
                'Detail',
                contentSyncState.errorMessage!,
                'Fallback',
                contentSyncState.hasContent
                    ? 'Cached content remains available'
                    : 'No local content available',
              ],
            ),
          ],
          const SizedBox(height: 14),
          const _SettingsCard(
            title: 'Product direction',
            lines: [
              'Mode',
              'Cross-platform incident lookup',
              'Delivery',
              'Android / iOS / Web / Desktop',
            ],
          ),
        ],
      ),
    );
  }
}

String _formatSyncTime(DateTime? value) {
  if (value == null) {
    return 'Never';
  }

  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.lines, this.action});

  final String title;
  final List<String> lines;
  final Widget? action;

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
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
