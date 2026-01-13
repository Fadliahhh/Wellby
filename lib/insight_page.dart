import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Kita pakai package intl untuk format tanggal

class InsightPage extends StatelessWidget {
  const InsightPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Dapatkan ID pengguna yang sedang login
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
          body: Center(child: Text("Error: User tidak ditemukan.")));
    }

    // Buat query ke Firestore
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('insights')
        .orderBy('timestamp', descending: true); // Urutkan dari yang terbaru

    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Wawasan AI", 
          style: TextStyle(
          color: Colors.white, // 🎨 ubah warna teks di sini
          fontWeight: FontWeight.bold,
        ),),
        backgroundColor: const Color.fromARGB(255, 6, 143, 75),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(), // "Dengarkan" query ini
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("Belum ada wawasan yang dibuat.",
                    style: TextStyle(fontSize: 16)));
          }

          // Jika ada data, tampilkan sebagai daftar
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              var insightText = data['insight'] ?? 'Tidak ada teks';

              // Format timestamp (jika ada)
              var t = data['timestamp'] as Timestamp?;
              String dateString = 'Baru saja';
              if (t != null) {
                // Gunakan package 'intl' untuk format yang cantik
                dateString =
                    DateFormat('E, d MMM yyyy - HH:mm').format(t.toDate());
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateString,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        insightText,
                        style: const TextStyle(
                            fontSize: 15, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}