import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/match_controller.dart';
import '../services/match_service.dart';
import 'match_detail_view.dart';

class MatchListView extends GetView<MatchController> {
  const MatchListView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(MatchController());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Aktif Maçlar ⚽"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (controller.matches.isEmpty) {
          return const Center(
            child: Text(
              "Henüz maç yok. İlk maçı sen kur!",
              style: TextStyle(fontSize: 16),
            ),
          );
        }

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

                // 👇 YAN YANA İKİ BUTON BURADA BAŞLIYOR 👇
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- DETAY BUTONU ---
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                      ),
                      onPressed: () {
                        // Maçın ID'sini argüman olarak detay sayfasına gönderiyoruz
                        Get.to(
                          () => const MatchDetailView(),
                          arguments: match.id,
                        );
                      },
                      child: const Text(
                        "Detay",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // --- AYRIL BUTONU ---
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                      ),
                      onPressed: () async {
                        try {
                          await MatchService().leaveMatch(match.id);

                          Get.snackbar(
                            "Başarılı",
                            "${match.title} maçından ayrıldın!",
                            backgroundColor: Colors.green[100],
                            colorText: Colors.green[900],
                          );
                        } catch (e) {
                          Get.snackbar(
                            "Hata",
                            "Maçtan ayrılırken bir sorun oluştu.",
                            backgroundColor: Colors.red[100],
                            colorText: Colors.red[900],
                          );
                        }
                      },
                      child: const Text(
                        "Ayrıl",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),

                // 👆 BUTONLAR BURADA BİTİYOR 👆
              ),
            );
          },
        );
      }),
    );
  }
}
