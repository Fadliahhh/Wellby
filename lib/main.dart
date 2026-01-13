// main.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_usage/app_usage.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:workmanager/workmanager.dart';

// Pastikan file-file ini ada di proyek Anda
import 'firebase_options.dart';
import 'notification_service.dart';
import 'ml_service.dart';
import 'feature_engineering.dart';
import 'insight_page.dart';
import 'secrets.dart';

// =======================================================
//                  CONSTANT
// =======================================================
const usageCheckTask = "wellbyUsageCheckTask";

// =======================================================
//                  BACKGROUND CALLBACK
// =======================================================
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task != usageCheckTask) return Future.value(false);

    print("[WM] Agen Bangun!");
    final appUsage = AppUsage();
    final notificationService = NotificationService();
    await notificationService.init(fromBackground: true);

    await notificationService.showNotification(
      999,
      'Wellby sedang memantau 🌱',
      'Menganalisis data penggunaanmu di background...',
    );

    await Future.delayed(const Duration(seconds: 5));
    await notificationService.cancelNotification(999);

    try {
      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(const Duration(minutes: 15));

      List<AppUsageInfo> info = await appUsage.getAppUsage(startDate, endDate);

      if (info.isEmpty) {
        print("[WM] Data 15m kosong.");
        return Future.value(true);
      }

      const int timeLimitMinutes = 10;
      final targetApps = [
        'Tiktok',
        'Instagram',
        'Mobile Legend',
        'Youtube'
      ];

      for (var app in info) {
        final appNameLower = app.appName.toLowerCase();

        if (targetApps.any((target) => appNameLower.contains(target.toLowerCase())) &&
            app.usage.inMinutes >= timeLimitMinutes) {
          print("[WM] Penggunaan >${timeLimitMinutes}m: ${app.appName}");
          await notificationService.showNotification(
            app.appName.hashCode,
            'Waktu Istirahat, Kawan!',
            'Agen Wellby melihat Anda main ${app.appName} >${timeLimitMinutes} menit. Yuk, istirahat!',
          );
          break;
        }
      }

      print("[WM] Cek selesai.");
      return Future.value(true);
    } catch (e) {
      print("[WM] ERROR: $e");
      return Future.value(false);
    }
  });
}

// =======================================================
//                  MAIN APP
// =======================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().init();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  await Workmanager().registerPeriodicTask(
    "1",
    usageCheckTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  runApp(const MyApp());
}

// =======================================================
//                  AUTH GATE
// =======================================================
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _signInAnonymously();
  }

  Future<void> _signInAnonymously() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      if (mounted) setState(() {});
    } catch (e) {
      print("Error login anonim: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FirebaseAuth.instance.currentUser == null
        ? Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor)),
            ),
          )
        : const DataCollectionPage();
  }
}

// =======================================================
//                  APP THEME (DARK MODERN)
// =======================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Color(0xFF00BFA6);
    final Color surfaceColor = Color(0xFF101216);
    final Color cardColor = Color(0xFF121316);
    final Color backgroundColor = Color(0xFF0B0C0E);
    final Color mutedText = Colors.grey[400]!;
    final Color subtle = Colors.grey[500]!;

    final baseTextTheme = Theme.of(context).textTheme;
    final poppinsTextTheme = GoogleFonts.poppinsTextTheme(baseTextTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return MaterialApp(
      title: 'Wellby Digital Wellbeing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: Colors.teal[700]!,
          surface: surfaceColor,
          background: backgroundColor,
          onBackground: Colors.white,
          onSurface: Colors.white,
          onPrimary: Colors.black,
          error: Colors.red[400]!,
        ),
        textTheme: poppinsTextTheme.copyWith(
          titleLarge: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          titleMedium: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          bodyMedium: GoogleFonts.poppins(
              fontSize: 14, color: mutedText, height: 1.5),
          labelSmall: GoogleFonts.poppins(
              fontSize: 11, color: subtle, letterSpacing: 0.5),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        cardTheme: CardThemeData(
          color: cardColor,
          elevation: 6,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF0F1113),
          hintStyle: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
          prefixIconColor: Colors.grey[400],
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Color(0xFF1A1C1E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: primaryColor, width: 2.0),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
            elevation: 4,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Color(0xFF1A1C1E)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Color(0xFF151617),
          labelStyle: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// =======================================================
//                  MAIN PAGE (REFACTORED DARK)
// =======================================================
class DataCollectionPage extends StatefulWidget {
  const DataCollectionPage({super.key});

  @override
  State<DataCollectionPage> createState() => _DataCollectionPageState();
}

class _DataCollectionPageState extends State<DataCollectionPage> {
  final AppUsage _appUsage = AppUsage();
  final MlService _mlService = MlService();
  final TextEditingController _questionController = TextEditingController();

  List<AppUsageInfo> _usageInfo = [];
  bool _isLoading = false;
  String _lastInsight = "";
  String _currentPatternLabel = "Memuat...";
  bool _isMonitoringActive = false;

  @override
  void initState() {
    super.initState();
    _trainModelIfNeeded();
    _predictCurrentPattern();
  }

  Future<void> _trainModelIfNeeded() async {
    await _mlService.trainModel();
    if (mounted) _predictCurrentPattern();
  }

  Future<void> _predictCurrentPattern() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || !mounted) return;

    setState(() => _currentPatternLabel = "Memprediksi...");

    try {

      //menentukan rentang waktu
      DateTime endDate = DateTime.now(); 
      DateTime startDate = endDate.subtract(const Duration(hours: 24)); 
      //eksekusi pengambilan data
      List<AppUsageInfo> info = await _appUsage.getAppUsage(startDate, endDate); 

      if (info.isNotEmpty) {
        final usageData = info
            .where((app) => app.usage.inMinutes > 0)
            .map((app) => {'appName': app.appName, 'usageMinutes': app.usage.inMinutes})
            .toList();

        if (usageData.isNotEmpty) {
          final todayVector = createFeatureVector(usageData);
          final predictedCluster = await _mlService.predictPattern(todayVector);
          final patternLabel = _mlService.getPatternLabel(predictedCluster);
          if (mounted) setState(() => _currentPatternLabel = patternLabel);
        } else {
          setState(() => _currentPatternLabel = "Data Kosong");
        }
      } else {
        setState(() => _currentPatternLabel = "Data Kosong");
      }
    } catch (e) {
      print("Error prediksi pola: $e");
      setState(() => _currentPatternLabel = "Gagal Prediksi");
    }
  }

  Future<void> _activateWorkManager() async {
    try {
      await Workmanager().registerPeriodicTask(
        "2",
        usageCheckTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
      );

      final notification = NotificationService();
      await notification.init();
      await notification.showNotification(
        12345,
        'Pemantauan Aktif',
        'Wellby mulai memantau penggunaanmu di latar belakang.',
      );

      setState(() => _isMonitoringActive = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pemantauan Latar Belakang Aktif!'),
            backgroundColor: Colors.green),
      );
      print("[APP] Background monitoring aktif!");
    } catch (e) {
      print("[APP] Error aktifkan Workmanager: $e");
    }
  }

  Future<void> generateInsight(
    String userId,
    List<Map<String, dynamic>> usageData,
    String dailyPatternLabel, {
    String? userQuestion,
  }) async {
    print("[AI] Mulai generate insight...");
    setState(() => _lastInsight = "Menganalisis data Anda...");

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: geminiApiKey,
        systemInstruction: Content.text(
          'Anda "Welby", AI wellbeing. Analisis data 24 jam & jawab pertanyaan pengguna berdasarkan pola harian ("$dailyPatternLabel"). '
          'FOKUS: Beri jawaban singkat (3-4 kalimat) yang relevan & positif.',
        ),
      );

      usageData.sort((a, b) => b['usageMinutes'].compareTo(a['usageMinutes']));
      final promptData = usageData
          .map((app) => "- ${app['appName']}: ${app['usageMinutes']} menit")
          .join("\n");

      final bool hasQuestion =
          userQuestion != null && userQuestion.trim().isNotEmpty;
      final contextPrompt =
          'Pola hari ini: "$dailyPatternLabel".\nData 24 jam terakhir:\n$promptData\n\n';
      final String fullPrompt = hasQuestion
          ? contextPrompt + 'Pertanyaan pengguna: "$userQuestion"\n\nJawab pertanyaan ini.'
          : contextPrompt + 'Berikan analisis singkat dan satu saran.';

      print("[AI] Mengirim prompt...");
      final response = await model.generateContent([Content.text(fullPrompt)]);
      final insightText = response.text ?? "Tidak ada respons.";

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('insights')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'insight': insightText,
        'patternLabel': dailyPatternLabel,
      });

      setState(() => _lastInsight = insightText);
      print("[AI] Wawasan disimpan.");
    } catch (e) {
      print("[AI] Error generateInsight: $e");
      setState(() => _lastInsight = "Gagal menganalisis data: $e");
    }
  }

  void requestPermission() async {
    if (Platform.isAndroid) {
      try {
        const intent =
            AndroidIntent(action: 'android.settings.USAGE_ACCESS_SETTINGS');
        await intent.launch();
      } catch (e) {
        print("Error buka settings: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal membuka pengaturan: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void getAndUploadUsageStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _lastInsight = "";
      _currentPatternLabel = "Memprediksi...";
    });

    FocusScope.of(context).unfocus();

    try {
      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(const Duration(hours: 24));
      List<AppUsageInfo> info = await _appUsage.getAppUsage(startDate, endDate);

      if (info.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Data kosong.')));
        setState(() {
          _isLoading = false;
          _currentPatternLabel = "Data Kosong";
        });
        return;
      }

      setState(() =>
          _usageInfo = info..sort((a, b) => b.usage.compareTo(a.usage)));

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("UserID null.");

      final usageData = info
          .where((app) => app.usage.inMinutes > 0)
          .map((app) => {
                'appName': app.appName,
                'packageName': app.packageName,
                'usageMinutes': app.usage.inMinutes,
              })
          .toList();

      if (usageData.isEmpty) {
        setState(() {
          _isLoading = false;
          _currentPatternLabel = "Data Kosong (0 menit)";
        });
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('usageLogs')
          .add({
            'timestamp': FieldValue.serverTimestamp(),
            'apps': usageData,
          });

      final todayVector = createFeatureVector(usageData);
      final predictedCluster = await _mlService.predictPattern(todayVector);
      final dailyPatternLabel = _mlService.getPatternLabel(predictedCluster);

      setState(() => _currentPatternLabel = dailyPatternLabel);

      await generateInsight(userId, usageData, dailyPatternLabel,
          userQuestion: _questionController.text);

      if (_questionController.text.isNotEmpty) {
        _questionController.clear();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Analisis Selesai!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      print("Error getAndUploadUsageStats: $e");
      setState(() => _currentPatternLabel = "Gagal Prediksi");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // =======================================================
  //                 BUILD METHOD (DARK)
  // =======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.shield_rounded, size: 20, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 12),
            Text('Wellby', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: Colors.white70),
            tooltip: 'Riwayat Wawasan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InsightPage()),
            ),
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildStatusHeader(context),
          const SizedBox(height: 20),
          _buildActionButtons(context),
          const SizedBox(height: 20),
          _buildAiInsightCard(context),
          const SizedBox(height: 20),
          _buildAppUsageList(context),
          const SizedBox(height: 24),
          Center(
            child: Text(
              "ID Pengguna: ${FirebaseAuth.instance.currentUser?.uid.substring(0, 6) ?? '...'}",
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // =======================================================
  //                 HELPER WIDGETS (DARK)
  // =======================================================

  Widget _buildStatusHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pola Hari Ini', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF0F1113),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          if (_currentPatternLabel == "Memprediksi...")
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(Icons.bolt_rounded, size: 16, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(_currentPatternLabel, style: textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Icon(
              Icons.analytics_rounded,
              size: 40,
              color: Theme.of(context).primaryColor.withOpacity(0.85),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isMonitoringActive ? Colors.green[600] : Theme.of(context).primaryColor,
            minimumSize: const Size(double.infinity, 52),
          ),
          icon: Icon(
            _isMonitoringActive ? Icons.check_circle_outline_rounded : Icons.play_circle_fill_rounded,
            size: 20,
            color: _isMonitoringActive ? Colors.white : Colors.black,
          ),
          label: Text(_isMonitoringActive ? "Pemantauan Aktif" : "Aktifkan Pemantauan Latar"),
          onPressed: _isMonitoringActive ? null : _activateWorkManager,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Beri Izin Akses'),
                onPressed: requestPermission,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFF1A1C1E)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E1F22),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.insights_rounded, size: 18),
                label: const Text('Insight Wellby!'),
                onPressed: _isLoading ? null : getAndUploadUsageStats,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiInsightCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.speaker_rounded, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 8),
                Text('Wawasan dari Welby', style: textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _lastInsight.isEmpty
                    ? 'Belum ada wawasan.\nKlik "Analisis Hari Ini" untuk memulai.'
                    : _lastInsight,
                key: ValueKey<String>(_lastInsight),
                style: textTheme.bodyMedium,
              ),
            ),
            const Divider(height: 32),
            Text('Tanya sesuatu:', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'Ketik pertanyaan Anda di sini...',
                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: Theme.of(context).primaryColor,
                        onPressed: getAndUploadUsageStats,
                      ),
              ),
              onSubmitted: (_) => getAndUploadUsageStats(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppUsageList(BuildContext context) {
    if (_usageInfo.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data Penggunaan (24 Jam)', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(
                  maxHeight: 400,
                ),
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _usageInfo.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final app = _usageInfo[index];
                    if (app.usage.inMinutes == 0) return const SizedBox.shrink();

                    // visual intensity based on usage
                    final minutes = app.usage.inMinutes;
                    final intensity = (minutes / 120).clamp(0.0, 1.0);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color.lerp(Color(0xFF0F1113), Theme.of(context).primaryColor.withOpacity(0.12), intensity),
                        child: Icon(Icons.apps_rounded, color: Theme.of(context).primaryColor, size: 20),
                      ),
                      title: Text(
                        app.appName,
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${app.packageName}', style: textTheme.bodyMedium?.copyWith(color: Colors.grey[500], fontSize: 12)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("${minutes} mnt", style: textTheme.titleMedium?.copyWith(fontSize: 14)),
                          const SizedBox(height: 4),
                          Container(
                            width: 64,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.grey[850],
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: intensity,
                              child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Theme.of(context).primaryColor)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
