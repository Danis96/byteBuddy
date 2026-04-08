/// Formatting helpers that turn raw sensor values into display strings.
library;

/// e.g. 73.4 → "73.4%"
String formatPercent(double? value) {
  if (value == null || value < 0) return '--';
  return '${value.toStringAsFixed(1)}%';
}

/// e.g. 73.4 → "73%"  (rounded, no decimal)
String formatCompactPercent(double? value) {
  if (value == null || value < 0) return '--';
  return '${value.round()}%';
}

/// e.g. 87 → "87%"
String formatBattery(int? value) {
  if (value == null || value < 0) return '--';
  return '$value%';
}

/// Alias kept for ring-label usage — identical output to [formatBattery].
String formatCompactBattery(int? value) => formatBattery(value);

/// e.g. 8192 MB → "8.0 GB"
String formatMemory(int? value) {
  if (value == null || value <= 0) return '--';
  final gb = value / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}

/// e.g. 8192 MB out of 16 384 MB → "50%"
String formatMemoryPercent(int? value) {
  if (value == null || value <= 0) return '--';
  return '${(memoryProgress(value) * 100).round()}%';
}

/// e.g. 2400 → "2400"  (raw RPM string, unit shown in the label)
String formatFanValue(int? value) {
  if (value == null || value <= 0) return '--';
  return '$value';
}

/// e.g. 2400 RPM out of 5 000 → "48%"
String formatFanPercent(int? value) {
  if (value == null || value <= 0) return '--';
  return '${(fanProgress(value) * 100).round()}%';
}

/// e.g. 67.3 → "67.3°C"
String formatTemperature(double? value) {
  if (value == null || value < 0) return '--';
  return '${value.toStringAsFixed(1)}°C';
}

/// e.g. 67.3°C out of 100°C → "67%"
String formatTempPercent(double? value) {
  if (value == null || value < 0) return '--';
  return '${(tempProgress(value) * 100).round()}%';
}

// ---------------------------------------------------------------------------
// Progress helpers (0.0 – 1.0) — kept here because they are tightly coupled
// to the formatters that call them and share the same domain.
// ---------------------------------------------------------------------------

/// Memory used (MB) as a fraction of 16 GB (16 384 MB).
double memoryProgress(int? value) {
  if (value == null || value <= 0) return 0;
  return safeUnit(value / 16384);
}

/// Fan speed (RPM) as a fraction of the assumed max (5 000 RPM).
double fanProgress(int? value) {
  if (value == null || value <= 0) return 0;
  return safeUnit(value / 5000);
}

/// CPU temperature as a fraction of the assumed max (100 °C).
double tempProgress(double? value) {
  if (value == null || value < 0) return 0;
  return safeUnit(value / 100);
}

/// Clamps [value] to [0, 1].
double safeUnit(num value) => value.clamp(0, 1).toDouble();