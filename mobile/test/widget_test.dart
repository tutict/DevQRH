import 'dart:convert';

import 'package:devqrh_mobile/app/devqrh_app.dart';
import 'package:devqrh_mobile/core/storage/local_store.dart';
import 'package:devqrh_mobile/features/lookup/data/lookup_repository.dart';
import 'package:devqrh_mobile/features/lookup/domain/models.dart';
import 'package:devqrh_mobile/features/lookup/presentation/checklist_detail_screen.dart';
import 'package:devqrh_mobile/features/lookup/presentation/favorites_screen.dart';
import 'package:devqrh_mobile/features/lookup/presentation/home_screen.dart';
import 'package:devqrh_mobile/features/lookup/presentation/lookup_controller.dart';
import 'package:devqrh_mobile/features/lookup/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders DevQRH home shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: DevQrhApp()));
    await tester.pumpAndSettle();

    expect(find.text('DevQRH'), findsOneWidget);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Agent'), findsWidgets);
    expect(find.text('Favorites'), findsWidgets);
    expect(find.text('Recent'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('restores catalog filter preferences', (tester) async {
    SharedPreferences.setMockInitialValues({
      'catalog_filter': 'mysql',
      'catalog_selected_tags': ['database', 'slow'],
      'catalog_recent_tags': ['database', 'timeout'],
      'catalog_sort': 'favoritesFirst',
      'catalog_presets': jsonEncode([
        {
          'name': 'DB focus',
          'filter': 'mysql',
          'selectedTags': ['database'],
          'sort': 'favoritesFirst',
        },
      ]),
    });

    await tester.pumpWidget(const ProviderScope(child: DevQrhApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text, 'mysql');
    expect(find.text('Favorites first'), findsOneWidget);
    expect(find.text('Recent tags'), findsOneWidget);
    expect(find.text('database'), findsWidgets);
    expect(find.text('DB focus'), findsOneWidget);
  });

  test('ranks related runbooks from shared keywords and symptoms', () {
    final cpuChecklist = Checklist(
      id: 'cpu_100',
      title: 'CPU 100%',
      keywords: const ['cpu', 'thread'],
      symptoms: const ['high cpu', 'service lag'],
      immediateActions: const [],
      decisionTree: const [],
      rootCause: const ['busy threads'],
      longTermFix: const ['optimize workload'],
    );
    final ioChecklist = Checklist(
      id: 'io_bottleneck',
      title: 'IO Bottleneck',
      keywords: const ['thread', 'storage'],
      symptoms: const ['service lag', 'slow writes'],
      immediateActions: const [],
      decisionTree: const [],
      rootCause: const ['storage pressure'],
      longTermFix: const ['scale disk throughput'],
    );
    final memoryChecklist = Checklist(
      id: 'memory_leak',
      title: 'Memory Leak',
      keywords: const ['memory', 'heap'],
      symptoms: const ['oom', 'high heap'],
      immediateActions: const [],
      decisionTree: const [],
      rootCause: const ['retained objects'],
      longTermFix: const ['fix object lifecycle'],
    );

    final container = ProviderContainer(
      overrides: [
        contentCatalogProvider.overrideWithValue([
          cpuChecklist,
          ioChecklist,
          memoryChecklist,
        ]),
      ],
    );
    addTearDown(container.dispose);

    final related = container.read(relatedChecklistsProvider(cpuChecklist));

    expect(related.map((item) => item.id), contains('io_bottleneck'));
    expect(related.map((item) => item.id), isNot(contains('cpu_100')));
  });

  test('builds checklist summary text for clipboard copy', () {
    final checklist = Checklist(
      id: 'cpu_100',
      title: 'CPU 100%',
      keywords: const ['cpu', 'thread'],
      symptoms: const ['high cpu', 'service lag'],
      immediateActions: [
        ChecklistStep(step: 1, action: 'check top'),
        ChecklistStep(step: 2, action: 'inspect hot threads'),
      ],
      decisionTree: const [],
      rootCause: const ['busy threads'],
      longTermFix: const ['optimize workload'],
    );

    final summary = buildChecklistSummaryForTest(checklist);

    expect(summary, contains('CPU 100%'));
    expect(summary, contains('ID: cpu_100'));
    expect(summary, contains('Keywords: cpu, thread'));
    expect(summary, contains('1. check top'));
  });

  test('builds recent checklist chain from recent ids', () {
    final cpuChecklist = Checklist(
      id: 'cpu_100',
      title: 'CPU 100%',
      keywords: const ['cpu'],
      symptoms: const ['high cpu'],
      immediateActions: const [],
      decisionTree: const [],
      rootCause: const [],
      longTermFix: const [],
    );
    final ioChecklist = Checklist(
      id: 'io_bottleneck',
      title: 'IO Bottleneck',
      keywords: const ['storage'],
      symptoms: const ['service lag'],
      immediateActions: const [],
      decisionTree: const [],
      rootCause: const [],
      longTermFix: const [],
    );
    final mysqlChecklist = Checklist(
      id: 'mysql_slow',
      title: 'MySQL Slow',
      keywords: const ['database'],
      symptoms: const ['slow query'],
      immediateActions: const [],
      decisionTree: const [],
      rootCause: const [],
      longTermFix: const [],
    );

    final recentController = RecentController(FakeLocalStore())
      ..state = const AsyncData(['cpu_100', 'io_bottleneck', 'mysql_slow']);

    final container = ProviderContainer(
      overrides: [
        contentCatalogProvider.overrideWithValue([
          cpuChecklist,
          ioChecklist,
          mysqlChecklist,
        ]),
        recentProvider.overrideWith((ref) => recentController),
      ],
    );
    addTearDown(container.dispose);

    final recentChain = container.read(recentChecklistChainProvider('cpu_100'));

    expect(recentChain.map((item) => item.id).toList(), [
      'io_bottleneck',
      'mysql_slow',
    ]);
  });

  test('combines recent searches and catalog content into suggestions', () {
    final checklist = Checklist(
      id: 'mysql_slow',
      title: 'MySQL Slow',
      keywords: const ['database', 'query'],
      symptoms: const ['timeout query', 'service lag'],
      immediateActions: const [],
      decisionTree: const [],
      rootCause: const [],
      longTermFix: const [],
    );

    final recentSearchesController = RecentSearchesController(FakeLocalStore())
      ..state = const AsyncData(['mysql timeout', 'cpu spike']);

    final container = ProviderContainer(
      overrides: [
        contentCatalogProvider.overrideWithValue([checklist]),
        recentSearchesProvider.overrideWith((ref) => recentSearchesController),
      ],
    );
    addTearDown(container.dispose);

    final suggestions = container.read(searchSuggestionsProvider('mysql'));

    expect(suggestions, contains('mysql timeout'));
    expect(suggestions, contains('MySQL Slow'));
    expect(suggestions, isNotEmpty);
  });

  test('builds explainable match hints for a search result', () {
    final checklist = Checklist(
      id: 'mysql_slow',
      title: 'MySQL Slow',
      keywords: const ['database', 'query'],
      symptoms: const ['timeout query', 'service lag'],
      immediateActions: const [],
      decisionTree: const [],
      rootCause: const ['slow storage'],
      longTermFix: const ['optimize indexes'],
    );

    final hints = buildMatchHints('timeout query', checklist);

    expect(hints, isNotEmpty);
    expect(
      hints.any((item) => item.contains('keyword') || item.contains('symptom')),
      isTrue,
    );
  });

  test('builds compact checklist preview text for result cards', () {
    final checklist = Checklist(
      id: 'cpu_100',
      title: 'CPU 100%',
      keywords: const ['cpu', 'thread'],
      symptoms: const ['high cpu', 'service lag'],
      immediateActions: [
        ChecklistStep(step: 1, action: 'check top'),
        ChecklistStep(step: 2, action: 'inspect hot threads'),
      ],
      decisionTree: const [],
      rootCause: const ['busy threads'],
      longTermFix: const [],
    );

    final preview = buildChecklistPreviewForTest(checklist);

    expect(preview, contains('Symptoms: high cpu / service lag'));
    expect(preview, contains('Next: 1. check top'));
    expect(preview, contains('Root cause: busy threads'));
  });

  test('builds agent navigation response from cached runbooks', () {
    final repository = LookupRepository(FakeLocalStore());
    final response = repository.navigateAgentCached(
      'service lag after deploy',
      checklists: [
        Checklist(
          id: 'cpu_100',
          title: 'CPU 100%',
          keywords: const ['cpu', 'thread'],
          symptoms: const ['service lag', 'high cpu'],
          immediateActions: const [],
          decisionTree: const [],
          rootCause: const ['busy threads'],
          longTermFix: const ['optimize workload'],
        ),
        Checklist(
          id: 'mysql_slow',
          title: 'MySQL Slow',
          keywords: const ['database', 'query'],
          symptoms: const ['timeout query', 'slow query'],
          immediateActions: const [],
          decisionTree: const [],
          rootCause: const ['missing index'],
          longTermFix: const ['optimize indexes'],
        ),
      ],
      matchingConfig: MatchingConfig(
        partialMinLength: 3,
        synonymGroups: const [
          ['slow', 'lag', 'latency'],
          ['service', 'api', 'app'],
        ],
        weights: MatchingWeights(
          exactQueryId: 1.0,
          exactIdToken: 1.0,
          exactTitleToken: 0.95,
          exactKeywordToken: 0.90,
          exactSymptomToken: 0.78,
          exactContextToken: 0.60,
          synonymKeyword: 0.72,
          synonymPrimary: 0.62,
          synonymAny: 0.50,
          partialKeyword: 0.48,
          partialPrimary: 0.40,
          partialAny: 0.28,
          tokenAverage: 0.88,
          keywordCoverage: 0.12,
          exactTitleBoost: 0.12,
          partialTitleBoost: 0.07,
          partialIdBoost: 0.07,
          phraseBoost: 0.04,
        ),
      ),
    );

    expect(response.bestMatch, isNotNull);
    expect(response.candidates, isNotEmpty);
    expect(response.clarifiers, isNotEmpty);
    expect(response.clarifiers.first, startsWith('check: '));
  });

  test('builds saved runbook subtitle with keyword and symptom fallback', () {
    final keywordFirst = Checklist(
      id: 'cpu_100',
      title: 'CPU 100%',
      keywords: const ['cpu', 'thread'],
      symptoms: const ['high cpu'],
      immediateActions: const [],
      decisionTree: const [],
      rootCause: const [],
      longTermFix: const [],
    );
    final symptomFallback = Checklist(
      id: 'io_wait',
      title: 'IO Wait',
      keywords: const [],
      symptoms: const ['slow writes', 'queue spike'],
      immediateActions: const [],
      decisionTree: const [],
      rootCause: const [],
      longTermFix: const [],
    );
    final idFallback = Checklist(
      id: 'mystery_case',
      title: 'Mystery',
      keywords: const [],
      symptoms: const [],
      immediateActions: const [],
      decisionTree: const [],
      rootCause: const [],
      longTermFix: const [],
    );

    expect(
      buildSavedChecklistSubtitle(keywordFirst, preferSymptoms: false),
      'cpu / thread',
    );
    expect(
      buildSavedChecklistSubtitle(symptomFallback, preferSymptoms: false),
      'slow writes / queue spike',
    );
    expect(
      buildSavedChecklistSubtitle(idFallback, preferSymptoms: true),
      'mystery_case',
    );
  });

  test('builds collection summary text for list headers', () {
    final summary = buildCollectionSummaryForTest(
      count: 3,
      totalCount: 12,
      activityLabel: 'saved',
      source: ContentSource.bundled,
    );

    expect(summary, contains('3 saved'));
    expect(summary, contains('12 runbooks'));
    expect(summary, contains('source bundled'));
  });

  test('builds settings overview summary text', () {
    final summary = buildSettingsOverviewForTest(
      manifest: ContentManifest(
        version: '1234567890abcdef',
        checklistCount: 8,
        generatedAt: 1,
      ),
      state: ContentSyncState(
        source: ContentSource.imported,
        bootstrap: ContentBootstrap(
          manifest: ContentManifest(
            version: '1234567890abcdef',
            checklistCount: 8,
            generatedAt: 1,
          ),
          matchingConfig: MatchingConfig(
            partialMinLength: 3,
            synonymGroups: const [],
            weights: MatchingWeights(
              exactQueryId: 1.0,
              exactIdToken: 1.0,
              exactTitleToken: 0.95,
              exactKeywordToken: 0.90,
              exactSymptomToken: 0.78,
              exactContextToken: 0.60,
              synonymKeyword: 0.72,
              synonymPrimary: 0.62,
              synonymAny: 0.50,
              partialKeyword: 0.48,
              partialPrimary: 0.40,
              partialAny: 0.28,
              tokenAverage: 0.88,
              keywordCoverage: 0.12,
              exactTitleBoost: 0.12,
              partialTitleBoost: 0.07,
              partialIdBoost: 0.07,
              phraseBoost: 0.04,
            ),
          ),
          checklists: [],
        ),
      ),
    );

    expect(summary, contains('Version 12345678'));
    expect(summary, contains('source imported'));
    expect(summary, contains('ready'));
  });

  test('builds compact home sync summary text', () {
    final summary = buildHomeSyncSummaryForTest(
      source: ContentSource.imported,
      manifest: ContentManifest(
        version: '1234567890abcdef',
        checklistCount: 4,
        generatedAt: 1,
      ),
      lastSyncedAt: DateTime(2026, 4, 13, 12, 0),
    );

    expect(summary, contains('Version 12345678'));
    expect(summary, contains('from imported package'));
    expect(summary, contains('updated 2026-04-13 12:00'));
  });
}

class FakeLocalStore extends LocalStore {}
