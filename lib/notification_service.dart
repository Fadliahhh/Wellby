import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inisialisasi notifikasi
  /// Gunakan [fromBackground: true] jika dipanggil dari WorkManager
  @pragma('vm:entry-point')
  Future<void> init({bool fromBackground = false}) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // Inisialisasi plugin notifikasi
    await _notificationsPlugin.initialize(initializationSettings);

    // 🧠 Minta izin notifikasi hanya saat app di UI (bukan di background)
    if (!fromBackground) {
      try {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (e) {
        print('[NotificationService] Gagal minta izin notifikasi: $e');
      }
    }
  }

  /// Menampilkan notifikasi sederhana
  Future<void> showNotification(int id, String title, String body) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'wellby_channel_id', // channel ID unik
      'Wellby Recommendations', // nama channel
      channelDescription: 'Notifikasi untuk rekomendasi digital wellbeing',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
      );
      print('[NotificationService] Notifikasi tampil: $title');
    } catch (e) {
      print('[NotificationService] Gagal tampilkan notifikasi: $e');
    }
  }

  /// Menghapus notifikasi berdasarkan ID
  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      print('[NotificationService] Notifikasi $id dibatalkan');
    } catch (e) {
      print('[NotificationService] Gagal batalkan notifikasi: $e');
    }
  }

  /// Menghapus semua notifikasi aktif
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      print('[NotificationService] Semua notifikasi dibatalkan');
    } catch (e) {
      print('[NotificationService] Gagal batalkan semua notifikasi: $e');
    }
  }
}
