import '../../features/lookup/domain/models.dart';
import '../../features/knowledge/domain/models.dart' as knowledge;

class RagSidecarClient {
  Future<LookupResponse?> search(
    String query, {
    required ContentBootstrap bootstrap,
  }) async {
    return null;
  }

  Future<AgentNavigationResponse?> navigateAgent(
    String query, {
    required ContentBootstrap bootstrap,
  }) async {
    return null;
  }

  Future<RagAnswerResponse?> answerQuestion(
    String query, {
    required ContentBootstrap bootstrap,
  }) async {
    return null;
  }

  Future<knowledge.KnowledgeSearchResponse?> searchKnowledge(
    String query, {
    required knowledge.LearningBundle bundle,
  }) async {
    return null;
  }

  Future<knowledge.TutorAnswerResponse?> answerLearningQuestion(
    String query, {
    required knowledge.LearningBundle bundle,
  }) async {
    return null;
  }

  Future<knowledge.GeneratedCardsResponse?> generateCards({
    required List<String> materialIds,
    required knowledge.LearningBundle bundle,
    int limit = 6,
  }) async {
    return null;
  }

  void dispose() {}
}
