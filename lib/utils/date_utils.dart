import 'package:intl/intl.dart';

class DateUtils {
  DateUtils._();

  // =====================
  // Formatting
  // =====================

  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy • h:mm a').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static String getShortDate(DateTime date) {
    return DateFormat('MM/dd/yyyy').format(date);
  }

  static String getDayName(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  static String getMonthName(DateTime date) {
    return DateFormat('MMMM').format(date);
  }

  // =====================
  // Relative Time
  // =====================

  static String getRelativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inDays >= 365) {
      final years = difference.inDays ~/ 365;
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }

    if (difference.inDays >= 30) {
      final months = difference.inDays ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }

    if (difference.inDays >= 7) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }

    if (difference.inDays >= 1) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    }

    if (difference.inHours >= 1) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    }

    if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }

    return 'Just now';
  }

  // =====================
  // Day Checks
  // =====================

  static bool isToday(DateTime date) {
    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  static bool isYesterday(DateTime date) {
    final yesterday =
        DateTime.now().subtract(const Duration(days: 1));

    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  // =====================
  // Difference
  // =====================

  static int getDaysBetween(
    DateTime start,
    DateTime end,
  ) {
    return end.difference(start).inDays;
  }

  // =====================
  // Expiry Helpers
  // =====================

  static int getDaysLeft(DateTime expiryDate) {
    return expiryDate.difference(DateTime.now()).inDays;
  }

  static bool isExpired(DateTime expiryDate) {
    return expiryDate.isBefore(DateTime.now());
  }

  static bool isExpiringSoon(
    DateTime expiryDate, {
    int days = 7,
  }) {
    final left = getDaysLeft(expiryDate);

    return left >= 0 && left <= days;
  }

  static String getExpiryText(DateTime expiryDate) {
    final days = getDaysLeft(expiryDate);

    if (days < 0) {
      return 'Expired';
    }

    if (days == 0) {
      return 'Expires today';
    }

    if (days == 1) {
      return '1 day left';
    }

    return '$days days left';
  }

  // =====================
  // Start / End
  // =====================

  static DateTime getStartOfDay(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  static DateTime getEndOfDay(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    );
  }

  static DateTime getStartOfWeek(DateTime date) {
    return date.subtract(
      Duration(days: date.weekday - 1),
    );
  }

  static DateTime getEndOfWeek(DateTime date) {
    return date.add(
      Duration(days: 7 - date.weekday),
    );
  }

  static DateTime getStartOfMonth(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      1,
    );
  }

  static DateTime getEndOfMonth(DateTime date) {
    final nextMonth =
        DateTime(date.year, date.month + 1);

    return nextMonth.subtract(
      const Duration(days: 1),
    );
  }

  // =====================
  // Timestamp
  // =====================

  static int currentTimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }
}