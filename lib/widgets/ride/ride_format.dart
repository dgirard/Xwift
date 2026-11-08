/// Number and duration formatting for the ride screens (French conventions).
library;

const _minus = '−';

/// 1 decimal at most, comma separator, no trailing ",0": 3 → "3", 3.5 → "3,5".
String formatDecimal(double value, {int decimals = 1}) {
  final rounded = double.parse(value.toStringAsFixed(decimals));
  if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
  return rounded.toStringAsFixed(decimals).replaceAll('.', ',');
}

/// Slope with its sign: "+3,5", "0", "−2".
String formatGrade(double grade) {
  final text = formatDecimal(grade.abs());
  if (grade > 0) return '+$text';
  if (grade < 0) return '$_minus$text';
  return text;
}

/// Signed watts difference: "+12", "−8", "0".
String formatSigned(int value) {
  if (value > 0) return '+$value';
  if (value < 0) return '$_minus${value.abs()}';
  return '0';
}

/// "1:02:03" or "02:03".
String formatClock(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// "850 m" or "12,4 km".
String formatDistance(int meters) {
  if (meters < 1000) return '$meters m';
  return '${formatDecimal(meters / 1000)} km';
}

/// "5 min", "1 h 05".
String formatMinutes(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
}

/// Plain-language description of a slope.
String gradeLabel(double grade) {
  if (grade >= 7) return 'Col';
  if (grade >= 3) return 'Côte';
  if (grade >= 1) return 'Faux-plat';
  if (grade > 0) return 'Presque plat';
  if (grade == 0) return 'Plat';
  if (grade > -3) return 'Faux-plat descendant';
  return 'Descente';
}
