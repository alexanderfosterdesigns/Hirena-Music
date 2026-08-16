/// Formats durations as mm:ss (or h:mm:ss).
String formatDuration(Duration d) {
  final s = d.inSeconds;
  final hours = s ~/ 3600;
  final minutes = (s % 3600) ~/ 60;
  final seconds = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '$minutes:${two(seconds)}';
}

/// Formats a wall-clock position for the player bar.
String formatClock(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
