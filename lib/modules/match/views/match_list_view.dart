import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/match_controller.dart';

class MatchListView extends GetView<MatchController> {
  const MatchListView({super.key});

  @override
  Widget build(BuildContext context) {
    // Controller'ı sayfaya bağlıyoruz
    Get.put(MatchController());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Aktif Maçlar ⚽"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        // Eğer liste boşsa ekranda uyarı gösterelim
        if (controller.matches.isEmpty) {
          return const Center(
            child: Text(
              "Henüz maç yok. İlk maçı sen kur!",
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        // Maçlar varsa listeyi ekrana basalım
        return ListView.builder(
          itemCount: controller.matches.length,
          itemBuilder: (context, index) {
            final match = controller.matches[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 4,
              child: ListTile(
                leading: const Icon(
                  Icons.sports_soccer,
                  size: 40,
                  color: Colors.green,
                ),
                title: Text(
                  match.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Kapasite: ${match.maxPlayers} Kişi\nTarih: ${match.date.toString().substring(0, 16)}",
                ),
                isThreeLine: true,
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                  ),
                  onPressed: () {
                    Get.snackbar(
                      "Yakında!",
                      "Maça katılma özelliği birazdan eklenecek 😎",
                    );
                  },
                  child: const Text(
                    "Katıl",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
