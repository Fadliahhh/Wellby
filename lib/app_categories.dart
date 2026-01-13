// lib/app_categories.dart

// Definisikan kategori yang kita inginkan
enum AppCategory {
  socialMedia,
  game,
  productivity,
  communication,
  entertainment, // Tambahan: Youtube, Netflix, dll.
  utility,       // Tambahan: Settings, File Manager, dll.
  other,
}

// Fungsi untuk memetakan nama aplikasi ke kategori
// PENTING: Sesuaikan daftar ini selengkap mungkin!
AppCategory getCategoryForApp(String appName) {
  final lowerAppName = appName.toLowerCase();

  // Media Sosial
  if (lowerAppName.contains('tiktok') ||
      lowerAppName.contains('instagram') ||
      lowerAppName.contains('facebook') ||
      lowerAppName.contains('twitter') ||
      lowerAppName.contains('x') || // Tambahan untuk Twitter
      lowerAppName.contains('snapchat') ||
      lowerAppName.contains('pinterest')) {
    return AppCategory.socialMedia;
  }

  // Game
  if (lowerAppName.contains('mobile legends') ||
      lowerAppName.contains('pubg') ||
      lowerAppName.contains('free fire') ||
      lowerAppName.contains('genshin impact') ||
      lowerAppName.contains('among us') ||
      lowerAppName.contains('clash of clans') ||
      lowerAppName.contains('candy crush')) {
    return AppCategory.game;
  }

  // Produktivitas / Belajar / Kerja
  if (lowerAppName.contains('vscode') || // Contoh nama dari PC
      lowerAppName.contains('visual studio') ||
      lowerAppName.contains('word') ||
      lowerAppName.contains('excel') ||
      lowerAppName.contains('powerpoint') ||
      lowerAppName.contains('docs') ||    // Google Docs
      lowerAppName.contains('sheets') ||  // Google Sheets
      lowerAppName.contains('slides') ||  // Google Slides
      lowerAppName.contains('classroom') ||
      lowerAppName.contains('zoom') ||
      lowerAppName.contains('meet') ||    // Google Meet
      lowerAppName.contains('drive') ||   // Google Drive
      lowerAppName.contains('github') ||
      lowerAppName.contains('notion') ||
      lowerAppName.contains('evernote') ||
      lowerAppName.contains('calculator') ||
      lowerAppName.contains('calendar')) {
    return AppCategory.productivity;
  }

  // Komunikasi
  if (lowerAppName.contains('whatsapp') ||
      lowerAppName.contains('telegram') ||
      lowerAppName.contains('line') ||
      lowerAppName.contains('discord') ||
      lowerAppName.contains('messages') || // SMS
      lowerAppName.contains('phone') ||   // Panggilan telepon
      lowerAppName.contains('gmail') ||
      lowerAppName.contains('email')) {
    return AppCategory.communication;
  }

  // Hiburan (selain game/medsos)
  if (lowerAppName.contains('youtube') ||
      lowerAppName.contains('netflix') ||
      lowerAppName.contains('spotify') ||
      lowerAppName.contains('disney+') ||
      lowerAppName.contains('viu') ||
      lowerAppName.contains('gallery') || // Melihat foto/video
      lowerAppName.contains('photos') ||  // Google Photos
      lowerAppName.contains('music')) {
    return AppCategory.entertainment;
  }


  // Jika tidak cocok dengan kategori di atas
  return AppCategory.other;
}