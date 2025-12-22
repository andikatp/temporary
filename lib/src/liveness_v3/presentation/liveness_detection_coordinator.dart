import 'package:flutter/foundation.dart';

/// Coordinates the liveness detection flow and step progression
class LivenessDetectionCoordinator extends ChangeNotifier {
  int _currentIndex = 0;
  final int _totalSteps;
  bool _isProcessing = false;

  LivenessDetectionCoordinator({required int totalSteps})
    : _totalSteps = totalSteps;

  int get currentIndex => _currentIndex;
  int get totalSteps => _totalSteps;
  bool get isProcessing => _isProcessing;
  bool get isCompleted => _currentIndex >= _totalSteps;

  /// Progress as a percentage (0.0 to 1.0)
  double get progress => _totalSteps > 0 ? _currentIndex / _totalSteps : 0.0;

  /// Advance to the next step
  void nextStep() {
    if (isCompleted) return;

    _currentIndex++;
    notifyListeners();
  }

  /// Reset to first step
  void reset() {
    _currentIndex = 0;
    _isProcessing = false;
    notifyListeners();
  }

  /// Mark processing state
  void setProcessing(bool processing) {
    if (_isProcessing != processing) {
      _isProcessing = processing;
      notifyListeners();
    }
  }
}
