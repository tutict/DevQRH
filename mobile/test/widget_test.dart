import 'dart:convert';

import 'package:devqrh_mobile/app/devqrh_app.dart';
import 'package:devqrh_mobile/core/sidecar/rag_sidecar_client.dart';
import 'package:devqrh_mobile/core/storage/local_store.dart';
import 'package:devqrh_mobile/features/knowledge/data/knowledge_repository.dart';
import 'package:devqrh_mobile/features/knowledge/data/offline_knowledge_matcher.dart';
import 'package:devqrh_mobile/features/knowledge/data/review_scheduler.dart';
import 'package:devqrh_mobile/features/knowledge/domain/models.dart';
import 'package:devqrh_mobile/features/knowledge/presentation/knowledge_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders learning home shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: DevQrhApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('应手'), findsOneWidget);
    expect(find.text('Study'), findsWidgets);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Ask'), findsWidgets);
    expect(find.text('Cards'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Search Materials'), findsOneWidget);
  });

  test('parses learning bundle schema with materials, decks, and cards', () {
    final bundle = LearningBundle.fromJson(sampleLearningBundleJson());

    expect(bundle.manifest.packageId, 'test.learning');
    expect(bundle.manifest.defaultLocale, 'zh-CN');
    expect(bundle.materials, hasLength(2));
    expect(bundle.materials.first.type, MaterialType.engineering);
    expect(bundle.decks.single.cardIds, contains('card_retry_idempotency'));
    expect(bundle.cards.single.sourceMaterialIds, ['engineering_api_retry']);
  });

  test('offline matcher ranks the strongest study material first', () {
    final bundle = LearningBundle.fromJson(sampleLearningBundleJson());
    final response = OfflineKnowledgeMatcher().search(
      query: 'api retry idempotency',
      materials: bundle.materials,
      config: bundle.matchingConfig,
    );

    expect(response.bestMatch?.id, 'engineering_api_retry');
    expect(response.candidates, isNotEmpty);
    expect(response.candidates.first.score, greaterThan(0.5));
  });

  test('local tutor answer stays grounded in cited learning material', () {
    final repository = KnowledgeRepository(FakeLocalStore());
    final bundle = LearningBundle.fromJson(sampleLearningBundleJson());

    final answer = repository.answerQuestionCached(
      'Should API clients retry validation errors?',
      bundle: bundle,
    );

    expect(answer.mode, 'local');
    expect(answer.answer, contains('API Retry Strategy'));
    expect(answer.answer, contains('Key points'));
    expect(answer.citations.first.id, 'engineering_api_retry');
  });

  test('card generation returns a clear error when sidecar or model is unavailable', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = KnowledgeRepository(
      FakeLocalStore(),
      sidecarClient: UnavailableSidecarClient(),
    );
    await repository.importPackage(jsonEncode(sampleLearningBundleJson()));

    final generated = await repository.generateCards(
      materialIds: const ['engineering_api_retry'],
      limit: 2,
    );

    expect(generated.mode, 'error');
    expect(generated.cards, isEmpty);
    expect(generated.notice, contains('AI card generation is unavailable'));
  });

  test('review scheduler updates due date and lapse state from grades', () {
    final scheduler = ReviewScheduler();
    final now = DateTime(2026, 6, 27, 9);
    final state = ReviewState.newCard('card_retry_idempotency', now: now);

    final good = scheduler.schedule(
      state: state,
      grade: ReviewGrade.good,
      now: now,
    );
    expect(good.updatedState.intervalDays, 1);
    expect(good.nextDueAt, now.add(const Duration(days: 1)));
    expect(good.updatedState.repetitionCount, 1);

    final again = scheduler.schedule(
      state: good.updatedState,
      grade: ReviewGrade.again,
      now: now,
    );
    expect(again.updatedState.intervalDays, 0);
    expect(again.updatedState.repetitionCount, 0);
    expect(again.updatedState.lapses, 1);
    expect(again.nextDueAt, now.add(const Duration(minutes: 10)));
  });

  test('related material scoring prefers shared tags and concepts', () {
    final bundle = LearningBundle.fromJson(sampleLearningBundleJson());
    final retry = bundle.materials.first;
    final mysql = bundle.materials.last;
    final relatedRetry = StudyMaterial(
      id: 'retry_budget',
      title: 'Retry Budget Notes',
      type: MaterialType.engineering,
      tags: const ['engineering', 'api', 'retry'],
      summary: 'Retry budgets and backoff protect downstream services.',
      content: 'Clients need bounded retry policies with jitter.',
    );

    expect(
      relatedMaterialScore(retry, relatedRetry),
      greaterThan(relatedMaterialScore(retry, mysql)),
    );
  });
}

Map<String, dynamic> sampleLearningBundleJson() {
  return {
    'manifest': {
      'schemaVersion': 1,
      'packageId': 'test.learning',
      'name': 'Test Learning Bundle',
      'version': '20260627',
      'generatedAt': 1782499200000,
      'defaultLocale': 'zh-CN',
      'sourceType': 'test',
    },
    'matchingConfig': {
      'partialMinLength': 2,
      'synonymGroups': [
        ['api', 'service', 'client'],
        ['retry', 'backoff', 'idempotency'],
        ['mysql', 'sql', 'index'],
      ],
      'weights': {
        'exactQueryId': 1.0,
        'exactIdToken': 1.0,
        'exactTitleToken': 0.95,
        'exactKeywordToken': 0.9,
        'exactSymptomToken': 0.78,
        'exactContextToken': 0.6,
        'synonymKeyword': 0.72,
        'synonymPrimary': 0.62,
        'synonymAny': 0.5,
        'partialKeyword': 0.48,
        'partialPrimary': 0.4,
        'partialAny': 0.28,
        'tokenAverage': 0.88,
        'keywordCoverage': 0.12,
        'exactTitleBoost': 0.12,
        'partialTitleBoost': 0.07,
        'partialIdBoost': 0.07,
        'phraseBoost': 0.04,
      },
    },
    'materials': [
      {
        'id': 'engineering_api_retry',
        'title': 'API Retry Strategy',
        'type': 'engineering',
        'tags': ['engineering', 'api', 'retry'],
        'summary': 'Retries should be bounded, idempotent, observable, and paired with backoff.',
        'content': 'Retry only idempotent requests or requests with an idempotency key. Use exponential backoff with jitter and stop retrying validation errors.',
        'source': 'test/api_retry.md',
        'chunks': [
          'Retry only idempotent requests or requests with an idempotency key.',
          'Use exponential backoff with jitter and a bounded retry budget.',
          'Do not retry validation errors.',
        ],
      },
      {
        'id': 'engineering_mysql_index',
        'title': 'MySQL Composite Index',
        'type': 'engineering',
        'tags': ['database', 'mysql', 'sql', 'index'],
        'summary': 'Composite indexes follow the leftmost-prefix rule.',
        'content': 'A query should match columns from left to right and avoid skipping the leading column.',
        'source': 'test/mysql_index.md',
        'chunks': ['Composite indexes follow the leftmost-prefix rule.'],
      },
    ],
    'decks': [
      {
        'id': 'engineering',
        'title': 'Engineering Docs',
        'goal': 'Review practical engineering documentation.',
        'tags': ['engineering'],
        'cardIds': ['card_retry_idempotency'],
      },
    ],
    'cards': [
      {
        'id': 'card_retry_idempotency',
        'deckId': 'engineering',
        'front': 'What must be true before retrying an API request?',
        'back': 'The request must be idempotent or carry an idempotency key.',
        'explanation': 'Unsafe retries can duplicate writes or amplify outages.',
        'tags': ['api', 'retry'],
        'difficulty': 2,
        'sourceMaterialIds': ['engineering_api_retry'],
      },
    ],
  };
}

class UnavailableSidecarClient extends RagSidecarClient {
  @override
  Future<GeneratedCardsResponse?> generateCards({
    required List<String> materialIds,
    required LearningBundle bundle,
    int limit = 6,
  }) async {
    return null;
  }

  @override
  void dispose() {}
}

class FakeLocalStore extends LocalStore {}
