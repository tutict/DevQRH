import '../../features/lookup/domain/models.dart';

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

  void dispose() {}
}
