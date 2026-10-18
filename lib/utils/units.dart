import '../models/user_profile.dart';

/// Conversions between metric (how data is stored) and imperial.

const double _kgPerLb = 0.45359237;
const double _cmPerInch = 2.54;

double kgToLb(double kg) => kg / _kgPerLb;
double lbToKg(double lb) => lb * _kgPerLb;

/// Returns (feet, inches) with inches rounded to the nearest whole number.
(int, int) cmToFtIn(double cm) {
  final totalInches = (cm / _cmPerInch).round();
  return (totalInches ~/ 12, totalInches % 12);
}

double ftInToCm(int feet, int inches) => (feet * 12 + inches) * _cmPerInch;

/// "150" instead of "150.0", "150.5" stays "150.5".
String trimNumber(double value, {int decimals = 1}) {
  final s = value.toStringAsFixed(decimals);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

String formatWeight(double? kg, Units units) {
  if (kg == null) return '—';
  return units == Units.imperial
      ? '${trimNumber(kgToLb(kg))} lbs'
      : '${trimNumber(kg)} kg';
}

String formatHeight(double? cm, Units units) {
  if (cm == null) return '—';
  if (units == Units.metric) return '${cm.round()} cm';
  final (ft, inch) = cmToFtIn(cm);
  return '$ft\' $inch"';
}

/// 1380 -> "1,380".
String formatKcal(double value) {
  final s = value.round().abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// A pace like "1 lb / week" or "0.5 kg / week" (always positive).
String formatRate(double kgPerWeek, Units units) => units == Units.imperial
    ? '${trimNumber(kgToLb(kgPerWeek), decimals: 2)} lb / week'
    : '${trimNumber(kgPerWeek, decimals: 2)} kg / week';

/// A signed weight change like "-0.4 lb / week".
String formatTrend(double kgPerWeek, Units units) {
  final v = units == Units.imperial ? kgToLb(kgPerWeek) : kgPerWeek;
  final sign = v > 0 ? '+' : (v < 0 ? '-' : '');
  final unit = units == Units.imperial ? 'lb' : 'kg';
  return '$sign${trimNumber(v.abs(), decimals: 2)} $unit / week';
}
