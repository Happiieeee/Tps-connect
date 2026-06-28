class TimeUtils {
  /// Convert any UTC timestamp string to IST DateTime
  static DateTime toIST(dynamic ts) {
    if (ts == null) return DateTime.now();
    try {
      final dt = DateTime.parse(ts.toString()).toUtc();
      return dt.add(const Duration(hours: 5, minutes: 30));
    } catch (_) { return DateTime.now(); }
  }

  /// Format as 12hr time — e.g. 6:47 PM
  static String formatTime(dynamic ts) {
    final dt = toIST(ts);
    final hour   = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Format as full date + time — e.g. 9 May 2026 · 6:47 PM
  static String formatFull(dynamic ts) {
    final dt = toIST(ts);
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final hour   = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month-1]} ${dt.year} · $hour:$minute $period';
  }

  /// Format date only — e.g. 9 May 2026
  static String formatDate(dynamic ts) {
    final dt = toIST(ts);
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month-1]} ${dt.year}';
  }

  /// Today label — e.g. Saturday, 9 May 2026
  static String todayLabel() {
    final now = DateTime.now().add(
        const Duration(hours: 5, minutes: 30));
    const days = ['Monday','Tuesday','Wednesday',
                  'Thursday','Friday','Saturday','Sunday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday-1]}, ${now.day} '
        '${months[now.month-1]} ${now.year}';
  }
}
