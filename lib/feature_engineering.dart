// lib/feature_engineering.dart (Pastikan seperti ini)

import 'app_categories.dart';

// Fungsi ini MENGEMBALIKAN List<double> (vektor fitur)
List<double> createFeatureVector(List<Map<String, dynamic>> dailyUsageApps) {
  Map<AppCategory, double> minutesPerCategory = {
    for (var category in AppCategory.values) category: 0.0
  };
  for (var appData in dailyUsageApps) {
    String appName = appData['appName'] ?? '';
    double usageMinutes = (appData['usageMinutes'] ?? 0).toDouble();
    AppCategory category = getCategoryForApp(appName);
    minutesPerCategory[category] = (minutesPerCategory[category] ?? 0.0) + usageMinutes;
  }
  List<double> featureVector = AppCategory.values
      .map((category) => minutesPerCategory[category] ?? 0.0)
      .toList();

  // Normalisasi (penting untuk K-Means versi lama)
  double totalMinutes = featureVector.fold(0.0, (sum, val) => sum + val);
  if (totalMinutes > 0) {
    featureVector = featureVector.map((val) => val / totalMinutes).toList();
  }

  print("Feature Vector Dibuat: $featureVector");
  return featureVector;
}

// Fungsi classifyDailyPatternFromMap TIDAK kita pakai lagi (hapus jika mau)