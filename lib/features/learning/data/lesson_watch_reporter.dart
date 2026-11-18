import 'dart:async';

/// Sends `POST /lessons/{id}/progress/` for time a student actually spends
/// on a lesson.
///
/// Video counts only while it is playing. A text or document lesson counts
/// while it is the one on screen. The server rejects anything outside 1–120
/// seconds and will not credit more than the real time since the last report,
/// so a paused lesson is flushed and then left alone.
class LessonWatchReporter {
  LessonWatchReporter(this._report);

  final Future<void> Function(
    int lessonId, {
    required int watchedSeconds,
    required int positionSeconds,
  })
  _report;

  int? _lessonId;
  int _position = 0;
  int _pending = 0;
  bool _active = false;
  bool _sending = false;
  DateTime _mark = DateTime.now();
  Timer? _timer;

  /// [active] is true while the lesson is being watched or read.
  void setActive({
    required int? lessonId,
    required bool active,
    required int positionSeconds,
  }) {
    final switched = lessonId != _lessonId;
    if (switched) _accumulate();
    if (switched && _lessonId != null && _pending >= 1) {
      _post(_lessonId!, _pending, _position);
      _pending = 0;
    }
    _lessonId = lessonId;
    _position = positionSeconds;
    final nowActive = active && lessonId != null;
    if (nowActive && !_active) _mark = DateTime.now();
    _active = nowActive;
    if (!_active) {
      _accumulate();
      if (_pending >= 1) flush();
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => _onBeat());
  }

  /// Adds [step] of engaged time. Steps over 30 seconds are ignored so a
  /// stalled timer cannot file a long absence as watching.
  void advance(Duration step) {
    final seconds = step.inSeconds;
    if (_active && seconds > 0 && seconds <= 30) _pending += seconds;
    if (_pending >= 20) flush();
  }

  void flush() {
    final id = _lessonId;
    if (id == null || _pending < 1 || _sending) return;
    _post(id, _pending, _position);
  }

  void dispose() {
    _accumulate();
    flush();
    _timer?.cancel();
    _timer = null;
    _active = false;
  }

  void _onBeat() {
    _accumulate();
    if (_pending >= 20) flush();
  }

  void _accumulate() {
    final now = DateTime.now();
    final step = now.difference(_mark);
    _mark = now;
    final seconds = step.inSeconds;
    if (_active && seconds > 0 && seconds <= 30) _pending += seconds;
  }

  Future<void> _post(int lessonId, int pending, int position) async {
    final send = pending.clamp(1, 120);
    _sending = true;
    if (_lessonId == lessonId) {
      _pending = (_pending - send).clamp(0, 100000);
    }
    try {
      await _report(lessonId, watchedSeconds: send, positionSeconds: position);
    } on Object {
      if (_lessonId == lessonId) {
        _pending = (_pending + send).clamp(0, 120);
      }
    } finally {
      _sending = false;
    }
  }
}
