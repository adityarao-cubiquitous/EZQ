import '../../queue/domain/queue_entry.dart';

/// Returns the wall-clock remaining wait for a persisted queue estimate.
///
/// The estimate is anchored to the server-backed join timestamp, so rebuilding
/// a widget, rotating the device, or reopening the route cannot restart it.
int remainingQueueWaitMinutes(QueueEntry entry, {DateTime? now}) {
  final estimate = entry.estimatedWaitMinutes.clamp(0, 24 * 60);
  if (estimate == 0) return 0;

  final currentTime = now ?? DateTime.now();
  final elapsedSeconds = currentTime.difference(entry.joinedAt).inSeconds;
  if (elapsedSeconds <= 0) return estimate;

  final elapsedMinutes = elapsedSeconds ~/ Duration.secondsPerMinute;
  return (estimate - elapsedMinutes).clamp(0, estimate);
}
