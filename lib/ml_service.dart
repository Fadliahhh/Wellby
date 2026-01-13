import 'dart:convert'; // untuk json encode/decode (menyimpan centroids di SharedPreferences)
import 'dart:math'; // untuk Random, max, dll
import 'package:cloud_firestore/cloud_firestore.dart'; // akses Firestore
import 'package:firebase_auth/firebase_auth.dart'; // akses user saat ini dari FirebaseAuth
// import 'package:kmeans/kmeans.dart'; // tidak dipakai lagi untuk training (komentar)
import 'package:shared_preferences/shared_preferences.dart'; // penyimpanan lokal sederhana
import 'feature_engineering.dart'; // Pastikan ini mengembalikan List<double>
import 'app_categories.dart'; // enum AppCategory yang dipakai untuk label

class MlService {
  // Konfigurasi dasar
  static const int numberOfClusters = 4; // jumlah cluster default yang diinginkan
  static const String _centroidsKey =
      'kmeans_centroids_kmeans_pkg_v1_final_fix'; // kunci untuk SharedPreferences

  // Cache centroids yang dimuat (agar tidak selalu baca prefs)
  List<List<double>>? _loadedCentroids;

  // ---------- Utility: load centroids dari SharedPreferences ----------
  Future<void> _loadCentroidsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final centroidsJson = prefs.getString(_centroidsKey);
    if (centroidsJson != null) {
      try {
        // Decode JSON menjadi List<List<double>>
        final List<dynamic> decodedList = jsonDecode(centroidsJson);
        _loadedCentroids = decodedList.map((list) {
          // Pastikan setiap item dikonversi ke double
          return List<double>.from(list.map((item) => (item as num).toDouble()));
        }).toList();
        print("[ML Fix] Centroids berhasil dimuat dari Prefs. ✅");
      } catch (e) {
        // Kalau decode gagal, flush cache internal (tetap jangan crash)
        print("[ML Fix] Gagal load centroids: $e");
        _loadedCentroids = null;
      }
    } else {
      print("[ML Fix] Belum ada centroids tersimpan.");
      _loadedCentroids = null;
    }
  }

  // ---------- Pelatihan model (trainModel) ----------
  Future<void> trainModel() async {
    print("[ML Fix] Mulai latih model K-Means...");
    final prefs = await SharedPreferences.getInstance();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return; // jika belum login, batalkan

    try {
      // 1. Ambil Data Riwayat dari Firestore (7 hari terakhir, limit 14 dokumen)
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('usageLogs')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .orderBy('timestamp', descending: true)
          .limit(14)
          .get();

      // Cek apakah data cukup (minimal = numberOfClusters)
      if (querySnapshot.docs.length < numberOfClusters) {
        print(
            "[ML Fix] Data kurang (${querySnapshot.docs.length}/$numberOfClusters)");
        return;
      }

      // 2. Convert setiap dokumen menjadi feature vector via createFeatureVector
      List<List<double>> trainingDataVectorsList = [];
      for (var doc in querySnapshot.docs) {
        final logData = doc.data();
        final List<dynamic> appsDynamic = logData['apps'] ?? [];
        final List<Map<String, dynamic>> appsData =
            List<Map<String, dynamic>>.from(
                appsDynamic.map((item) => Map<String, dynamic>.from(item)));
        if (appsData.isNotEmpty) {
          final vector = createFeatureVector(appsData);
          // sanity check: all vectors must have same length
          if (vector.isNotEmpty) trainingDataVectorsList.add(vector);
        }
      }
      if (trainingDataVectorsList.isEmpty) {
        print("[ML Fix] Tidak ada data feature untuk dilatih.");
        return;
      }

      print(
          "[ML Fix] Latih K-Means dengan ${trainingDataVectorsList.length} data...");

      // Guard safety: jika jumlah data < jumlah cluster, sesuaikan k
      int effectiveK = numberOfClusters;
      if (trainingDataVectorsList.length <= numberOfClusters) {
        effectiveK = max(1, trainingDataVectorsList.length);
        print(
            "[ML Fix] Jumlah data <= jumlah cluster. Mengurangi k menjadi $effectiveK");
      }

      // --- Gunakan KMeans internal untuk menghindari RangeError dari lib eksternal ---
      final List<List<double>> centroidsResult =
          _computeKMeansCentroids(trainingDataVectorsList, effectiveK,
              maxIter: 100, tol: 1e-6);

      _loadedCentroids = centroidsResult; // Simpan ke cache
      print("[ML Fix] Latihan selesai. Centroids:");
      print(_loadedCentroids);

      // 5. Simpan Centroids ke SharedPreferences (jika ada)
      if (_loadedCentroids != null && _loadedCentroids!.isNotEmpty) {
        final centroidsJson = jsonEncode(_loadedCentroids);
        await prefs.setString(_centroidsKey, centroidsJson);
        print("[ML Fix] Centroids tersimpan di SharedPreferences ✅");
      } else {
        print("[ML Fix] Gagal simpan centroids (kosong)");
        await prefs.remove(_centroidsKey);
      }
    } catch (e) {
      // Tangani error umum: log, clear cache, hapus prefs
      print("[ML Fix] Error latih model: $e");
      _loadedCentroids = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_centroidsKey);
    }
  }

  // ---------- Helper: Euclidean Distance Squared ----------
  // Menggunakan squared distance menghindari komputasi sqrt (lebih cepat)
  double _euclideanDistanceSquared(List<double> p1, List<double> p2) {
    if (p1.length != p2.length) {
      throw ArgumentError("Vector length mismatch");
    }
    double sum = 0.0;
    for (int i = 0; i < p1.length; i++) {
      final diff = p1[i] - p2[i];
      sum += diff * diff;
    }
    return sum;
  }

  // ---------- Internal K-Means implementation (k-means++ initialization) ----------
  // Mengembalikan list centroid (List<List<double>>)
  List<List<double>> _computeKMeansCentroids(
      List<List<double>> data, int k,
      {int maxIter = 100, double tol = 1e-6}) {
    final rng = Random();
    final n = data.length;
    final dim = data[0].length;

    // Defensive checks
    if (n == 0) return [];
    if (k <= 0) return [];
    if (k > n) k = n; // tidak mungkin lebih banyak cluster daripada titik data

    // k-means++ initialization
    List<List<double>> centroids = [];

    // pick first centroid randomly (copy data point)
    centroids.add(List<double>.from(data[rng.nextInt(n)]));

    // pick remaining centroids with probability proportional to squared distance
    while (centroids.length < k) {
      // compute distance squared to nearest centroid for each point
      List<double> distances = List<double>.filled(n, 0.0);
      double total = 0.0;
      for (int i = 0; i < n; i++) {
        double minDist = double.infinity;
        for (var c in centroids) {
          final d = _euclideanDistanceSquared(data[i], c);
          if (d < minDist) minDist = d;
        }
        distances[i] = minDist;
        total += minDist;
      }

      if (total <= 0.0) {
        // semua titik sama atau titik menempel ke centroid -> fallback pick berbeda
        for (int i = 0; i < n && centroids.length < k; i++) {
          final candidate = data[i];
          if (!centroids.any((c) => _areVectorsEqual(c, candidate))) {
            centroids.add(List<double>.from(candidate));
          }
        }
        // kalau masih kurang, pick random sampai k terpenuhi
        if (centroids.length < k) {
          while (centroids.length < k) {
            centroids.add(List<double>.from(data[rng.nextInt(n)]));
          }
        }
        break;
      }

      // pick a random point weighted by distances
      double r = rng.nextDouble() * total;
      double cum = 0.0;
      int selected = 0;
      for (int i = 0; i < n; i++) {
        cum += distances[i];
        if (cum >= r) {
          selected = i;
          break;
        }
      }
      // add selected centroid (copy)
      centroids.add(List<double>.from(data[selected]));
    }

    // iterative update loop
    for (int iter = 0; iter < maxIter; iter++) {
      // assign points to nearest centroid
      List<List<int>> clusters = List.generate(k, (_) => []);
      for (int i = 0; i < n; i++) {
        double bestDist = double.infinity;
        int bestIdx = 0;
        for (int j = 0; j < k; j++) {
          final d = _euclideanDistanceSquared(data[i], centroids[j]);
          if (d < bestDist) {
            bestDist = d;
            bestIdx = j;
          }
        }
        clusters[bestIdx].add(i);
      }

      // recompute centroids as mean of members
      double maxShift = 0.0;
      List<List<double>> newCentroids =
          List.generate(k, (_) => List<double>.filled(dim, 0.0));

      for (int j = 0; j < k; j++) {
        final memberIdx = clusters[j];
        if (memberIdx.isEmpty) {
          // jika cluster kosong -> reinitialize centroid ke titik data random
          newCentroids[j] = List<double>.from(data[rng.nextInt(n)]);
          continue;
        }
        // sum anggota
        for (var idx in memberIdx) {
          for (int d = 0; d < dim; d++) {
            newCentroids[j][d] += data[idx][d];
          }
        }
        // bagi rata untuk dapat mean
        for (int d = 0; d < dim; d++) {
          newCentroids[j][d] /= memberIdx.length;
        }

        // hitung seberapa jauh centroid bergeser (squared distance)
        final shift = _euclideanDistanceSquared(centroids[j], newCentroids[j]);
        if (shift > maxShift) maxShift = shift;
      }

      centroids = newCentroids;

      // konvergensi jika pergeseran maksimum <= tol^2 (karena kita pakai squared dist)
      if (maxShift <= tol * tol) {
        // converged
        break;
      }
    }

    return centroids;
  }

  // ---------- Helper: bandingkan vektor dengan toleransi kecil ----------
  bool _areVectorsEqual(List<double> a, List<double> b,
      {double eps = 1e-12}) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > eps) return false;
    }
    return true;
  }

  // ---------- Prediksi cluster untuk vektor hari ini ----------
  Future<int?> predictPattern(List<double> todayVectorList) async {
    print("[ML Fix] Prediksi pola hari ini...");
    if (_loadedCentroids == null) {
      await _loadCentroidsFromPrefs();
    }
    if (_loadedCentroids == null) {
      // kalau belum ada centroids, otomatis coba latih
      print("[ML Fix] Belum ada model, coba latih dulu...");
      await trainModel();
      if (_loadedCentroids == null) {
        print("[ML Fix] Latihan gagal, prediksi dibatalkan.");
        return null;
      }
      print("[ML Fix] Model selesai dilatih, melanjutkan prediksi...");
    }

    try {
      final centroidVectors = _loadedCentroids!;
      int closestClusterIndex = -1;
      double minDistanceSquared = double.infinity;

      for (int i = 0; i < centroidVectors.length; i++) {
        if (centroidVectors[i].length != todayVectorList.length) {
          // panjang fitur tidak cocok -> skip cluster ini
          print("[ML Fix] Panjang vector tidak cocok di cluster $i.");
          continue;
        }
        final distanceSquared =
            _euclideanDistanceSquared(todayVectorList, centroidVectors[i]);
        print("[ML Fix] Jarak² ke Cluster $i: $distanceSquared");
        if (distanceSquared < minDistanceSquared) {
          minDistanceSquared = distanceSquared;
          closestClusterIndex = i;
        }
      }

      if (closestClusterIndex != -1) {
        print("[ML Fix] Prediksi cluster hari ini: $closestClusterIndex ✅");
        return closestClusterIndex;
      }
      return null;
    } catch (e) {
      print("[ML Fix] Error prediksi: $e");
      return null;
    }
  }

  // ---------- Mapping cluster -> label (pakai centroid untuk deteksi dominan) ----------
  String getPatternLabel(int? clusterId) {
    if (clusterId == null) return "Belum Diketahui";
    if (_loadedCentroids != null &&
        clusterId >= 0 &&
        clusterId < _loadedCentroids!.length) {
      final centroid = _loadedCentroids![clusterId];
      double maxVal = -1;
      int maxIndex = -1;
      // cari index fitur dengan nilai tertinggi di centroid untuk menebak kategori dominan
      for (int i = 0; i < centroid.length; i++) {
        if (centroid[i] > maxVal) {
          maxVal = centroid[i];
          maxIndex = i;
        }
      }
      // bandingkan index tertinggi dengan enum AppCategory (asumsi urutan matching)
      if (maxIndex == AppCategory.socialMedia.index) return "Dominan Medsos";
      if (maxIndex == AppCategory.game.index) return "Dominan Game";
      if (maxIndex == AppCategory.productivity.index)
        return "Dominan Produktif";
      if (maxIndex == AppCategory.communication.index)
        return "Dominan Komunikasi";
      if (maxIndex == AppCategory.entertainment.index)
        return "Dominan Hiburan";
      if (maxIndex == AppCategory.utility.index) return "Dominan Utilitas";
    }
    // fallback label
    return "Pola Hari #${(clusterId  -1) + 1}"; // Fallback
  }

  // ---------- Debug helper: tampilkan centroids tersimpan ----------
  Future<void> debugShowStoredCentroids() async {
    final prefs = await SharedPreferences.getInstance();
    final centroidsJson = prefs.getString(_centroidsKey);

    if (centroidsJson == null) {
      print("[ML Debug] Belum ada centroids tersimpan di SharedPreferences ❌");
      return;
    }

    try {
      final List<dynamic> decoded = jsonDecode(centroidsJson);
      final centroids =
          decoded.map((e) => List<double>.from(e.map((v) => (v as num).toDouble()))).toList();
      print("[ML Debug] Centroids yang tersimpan di SharedPreferences:");
      for (int i = 0; i < centroids.length; i++) {
        print("Cluster #$i => ${centroids[i]}");
      }
    } catch (e) {
      print("[ML Debug] Gagal decode centroids: $e");
    }
  }
}
