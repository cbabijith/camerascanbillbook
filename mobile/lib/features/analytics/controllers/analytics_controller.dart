import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics_metrics.dart';
import '../repositories/analytics_repository.dart';

enum DateRange { today, d7, d30, month, all, custom }

class AnalyticsState {
  final List<BranchAnalytics> data;
  final bool isLoading;
  final DateRange range;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String? errorMessage;

  AnalyticsState({
    this.data = const [],
    this.isLoading = false,
    this.range = DateRange.month,
    this.customStart,
    this.customEnd,
    this.errorMessage,
  });

  AnalyticsState copyWith({
    List<BranchAnalytics>? data,
    bool? isLoading,
    DateRange? range,
    DateTime? customStart,
    DateTime? customEnd,
    String? errorMessage,
  }) {
    return AnalyticsState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      range: range ?? this.range,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      errorMessage: errorMessage,
    );
  }
}

class AnalyticsController extends Notifier<AnalyticsState> {
  AnalyticsRepository get _repository => ref.read(analyticsRepositoryProvider);

  @override
  AnalyticsState build() {
    Future.microtask(() => fetchData());
    return AnalyticsState();
  }

  Future<void> fetchData() async {
    state = state.copyWith(isLoading: true);
    final dates = _getRangeDates(state.range, state.customStart, state.customEnd);

    try {
      final list = await _repository.getAnalyticsData(
        dates['start']!.toIso8601String(),
        dates['end']!.toIso8601String(),
      );
      state = state.copyWith(data: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  void setRange(DateRange newRange, {DateTime? start, DateTime? end}) {
    state = state.copyWith(range: newRange, customStart: start, customEnd: end);
    fetchData();
  }

  Map<String, DateTime> _getRangeDates(DateRange range, DateTime? customStart, DateTime? customEnd) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + 1);

    switch (range) {
      case DateRange.today:
        final start = DateTime(now.year, now.month, now.day);
        return {'start': start, 'end': end};
      case DateRange.d7:
        final start = now.subtract(const Duration(days: 7));
        return {'start': start, 'end': end};
      case DateRange.d30:
        final start = now.subtract(const Duration(days: 30));
        return {'start': start, 'end': end};
      case DateRange.month:
        final start = DateTime(now.year, now.month, 1);
        return {'start': start, 'end': end};
      case DateRange.all:
        final start = DateTime(2000, 1, 1);
        return {'start': start, 'end': end};
      case DateRange.custom:
        final start = customStart ?? DateTime(2000, 1, 1);
        final customE = customEnd ?? now;
        final adjustedEnd = DateTime(customE.year, customE.month, customE.day + 1);
        return {'start': start, 'end': adjustedEnd};
    }
  }
}

// Providers
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) => AnalyticsRepository());

final analyticsControllerProvider = NotifierProvider<AnalyticsController, AnalyticsState>(AnalyticsController.new);
