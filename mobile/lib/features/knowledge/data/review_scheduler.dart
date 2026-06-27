import '../domain/models.dart';

class ReviewScheduler {
  ReviewResult schedule({
    required ReviewState state,
    required ReviewGrade grade,
    DateTime? now,
  }) {
    final reviewedAt = now ?? DateTime.now();
    final next = switch (grade) {
      ReviewGrade.again => _again(state, reviewedAt),
      ReviewGrade.hard => _hard(state, reviewedAt),
      ReviewGrade.good => _good(state, reviewedAt),
      ReviewGrade.easy => _easy(state, reviewedAt),
    };
    return ReviewResult(
      cardId: next.cardId,
      nextDueAt: next.dueAt,
      updatedState: next,
    );
  }

  ReviewState _again(ReviewState state, DateTime now) {
    return ReviewState(
      cardId: state.cardId,
      easeFactor: _clampEase(state.easeFactor - 0.2),
      intervalDays: 0,
      repetitionCount: 0,
      dueAt: now.add(const Duration(minutes: 10)),
      lastReviewedAt: now,
      lapses: state.lapses + 1,
    );
  }

  ReviewState _hard(ReviewState state, DateTime now) {
    final interval = state.intervalDays <= 0 ? 1 : state.intervalDays + 1;
    return ReviewState(
      cardId: state.cardId,
      easeFactor: _clampEase(state.easeFactor - 0.15),
      intervalDays: interval,
      repetitionCount: state.repetitionCount + 1,
      dueAt: now.add(Duration(days: interval)),
      lastReviewedAt: now,
      lapses: state.lapses,
    );
  }

  ReviewState _good(ReviewState state, DateTime now) {
    final interval = switch (state.repetitionCount) {
      0 => 1,
      1 => 3,
      _ => (state.intervalDays * state.easeFactor).round().clamp(4, 3650),
    };
    return ReviewState(
      cardId: state.cardId,
      easeFactor: state.easeFactor,
      intervalDays: interval,
      repetitionCount: state.repetitionCount + 1,
      dueAt: now.add(Duration(days: interval)),
      lastReviewedAt: now,
      lapses: state.lapses,
    );
  }

  ReviewState _easy(ReviewState state, DateTime now) {
    final ease = _clampEase(state.easeFactor + 0.15);
    final interval = switch (state.repetitionCount) {
      0 => 3,
      1 => 7,
      _ => (state.intervalDays * ease * 1.3).round().clamp(7, 3650),
    };
    return ReviewState(
      cardId: state.cardId,
      easeFactor: ease,
      intervalDays: interval,
      repetitionCount: state.repetitionCount + 1,
      dueAt: now.add(Duration(days: interval)),
      lastReviewedAt: now,
      lapses: state.lapses,
    );
  }

  double _clampEase(double value) {
    if (value < 1.3) {
      return 1.3;
    }
    if (value > 3.2) {
      return 3.2;
    }
    return double.parse(value.toStringAsFixed(2));
  }
}
