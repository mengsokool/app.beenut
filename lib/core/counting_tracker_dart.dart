import 'models.dart';

class CountingTrackerDart {
  CountingTrackerDart({
    int stableFrames = 5,
    int timeoutMs = 1500,
  })  : _stableFrames = stableFrames, // ignore: prefer_initializing_formals
        _timeoutMs = timeoutMs; // ignore: prefer_initializing_formals

  int _stableFrames;
  int _timeoutMs;
  final List<InferenceResultDart> _samples = [];
  CountingSnapshotDart _locked = CountingSnapshotDart.empty;
  DateTime? _lastSampleAt;

  void reload({required int stableFrames, required int timeoutMs}) {
    _stableFrames = stableFrames;
    _timeoutMs = timeoutMs;
    reset();
  }

  void reset() {
    _samples.clear();
    _locked = CountingSnapshotDart.empty;
    _lastSampleAt = null;
  }

  CountingSnapshotDart update(bool trayPresent, InferenceResultDart result) {
    if (!trayPresent) {
      reset();
      return _locked;
    }

    final now = DateTime.now();
    final lastSampleAt = _lastSampleAt;
    if (lastSampleAt != null &&
        now.difference(lastSampleAt).inMilliseconds > _timeoutMs) {
      _samples.clear();
      _locked = CountingSnapshotDart.empty;
    }
    _lastSampleAt = now;

    _samples.add(result);
    while (_samples.length > _stableFrames) {
      _samples.removeAt(0);
    }

    if (_samples.length >= _stableFrames) {
      _locked = _lockFromSamples();
    } else {
      _locked = CountingSnapshotDart(
        count: 0,
        detections: const [],
        locked: false,
        samples: _samples.length,
      );
    }
    return _locked;
  }

  CountingSnapshotDart get snapshot => _locked;

  CountingSnapshotDart _lockFromSamples() {
    final counts = _samples.map((s) => s.count).toList()..sort();

    // Lower median calculation
    final medianIndex = (counts.length - 1) ~/ 2;
    final medianCount = counts[medianIndex];

    // Find the latest sample matching the median count
    InferenceResultDart? bestSample;
    for (var i = _samples.length - 1; i >= 0; i--) {
      if (_samples[i].count == medianCount) {
        bestSample = _samples[i];
        break;
      }
    }

    return CountingSnapshotDart(
      count: medianCount,
      locked: true,
      samples: _samples.length,
      detections: bestSample?.detections ?? const [],
    );
  }
}

class InferenceResultDart {
  const InferenceResultDart({
    required this.count,
    required this.processingMs,
    required this.detections,
  });

  final int count;
  final int processingMs;
  final List<Detection> detections;
}

class CountingSnapshotDart {
  const CountingSnapshotDart({
    required this.count,
    required this.detections,
    required this.locked,
    required this.samples,
  });

  static const empty = CountingSnapshotDart(
    count: 0,
    detections: [],
    locked: false,
    samples: 0,
  );

  final int count;
  final List<Detection> detections;
  final bool locked;
  final int samples;
}
