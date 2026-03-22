import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/match_formation_controller.dart';
import '../../../core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchFormationView extends StatefulWidget {
  const MatchFormationView({super.key});

  @override
  State<MatchFormationView> createState() => _MatchFormationViewState();
}

class _MatchFormationViewState extends State<MatchFormationView> {
  late final MatchFormationController controller;

  @override
  void initState() {
    super.initState();
    final String matchId = Get.arguments as String;
    controller = Get.put(MatchFormationController(matchId: matchId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saha Dizilişi', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: kGreen),
            onPressed: () {
              // Share logic if needed
            },
          )
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: kGreen));
        }

        return Column(
          children: [
            _buildFormationSelector(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: _buildPitch(),
              ),
            ),

            _buildSaveButton(),
          ],
        );
      }),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
      ),
      child: ElevatedButton(
        onPressed: controller.saveFormation,
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreen,
          foregroundColor: const Color(0xFF0F1712), // kDarkBg
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Dizilişi Kaydet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFormationSelector() {
    if (!controller.isCaptain) {
       // Sadece kaptan formu değiştirebilir, diğerleri için widget'ı tamamen gizle
       return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: controller.availableFormations.map((form) {
          final isSelected = controller.selectedFormation.value == form;
          return GestureDetector(
            onTap: () => controller.changeFormation(form),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? Colors.transparent : Colors.transparent,
              ),
              child: Text(
                form,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected ? kGreen : AppColors.subText(context),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPitch() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A22), // Koyu gri-yeşil 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 2),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12, width: 2),
              ),
            ),
          ),
          // Diziliş
          _buildPlayersPositioned(),
        ],
      ),
    );
  }

  Widget _buildPlayersPositioned() {
    final formatStr = controller.selectedFormation.value;
    List<int> formationRows = [1]; // Kaleci
    formationRows.addAll(formatStr.split('-').map((e) => int.parse(e)));
    
    List<List<int>> assignedIndices = [];
    int counter = 0;
    for (int count in formationRows) {
        List<int> r = [];
        for (int i=0; i<count; i++) {
            r.add(counter);
            counter++;
        }
        assignedIndices.add(r);
    }
    
    final renderIndices = assignedIndices.reversed.toList();
    final opponentRenderIndices = assignedIndices; 

    return Column(
      children: [
        // Rakip Yarı Saha
        Expanded(
          child: Column(
            children: opponentRenderIndices.map((rowSlots) {
              return Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    // Rakip kısmı da tıklanabilir, esnek yapıdaki _buildPlayerSlot'u kullanıyoruz
                    // Slotları sayıyla (örn opponent_0) vermek için rowSlots'u düzenleyebiliriz,
                    // Veya burada da ana numaratörü (0..maxPlayers-1) kullanabiliriz.
                    // Şimdilik üst yarı için 'opponent_$slotId' olarak benzersiz anahtar üretip slot açalım ki onlara da yerleşilebilsin.
                    children: rowSlots.map((slotId) {
                      return Flexible(child: _buildPlayerSlot('opponent_$slotId'));
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        // Orta saha çizgisi
        Container(width: double.infinity, height: 2, color: Colors.white12),
        // Bizim Yarı Saha
        Expanded(
          child: Column(
            children: renderIndices.map((rowSlots) {
              return Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: rowSlots.map((slotId) {
                    return Flexible(child: _buildPlayerSlot(slotId.toString()));
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }



  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return "?";
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return "${parts[0][0]}${parts.last[0]}".toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  Widget _buildPlayerSlot(String positionId) {
    String? assignedUid = controller.positions[positionId];
    final List<dynamic> currentPlayers = controller.matchData.value?['currentPlayers'] ?? [];
    
    // 🔥 UX KRİTİK DÜZELTME: Oyuncu maçtan ayrılmışsa slot anında boşa düşsün 🔥
    if (assignedUid != null && !currentPlayers.contains(assignedUid)) {
       assignedUid = null;
    }

    Map<String, dynamic>? playerInfo;
    if (assignedUid != null) {
       playerInfo = controller.playerDetails[assignedUid];
    }
    
    final bool isEmpty = assignedUid == null;
    final bool isCaptainProfile = assignedUid != null && assignedUid == controller.matchData.value?['createdBy'];

    // Avatarlar için geçerli URL olup olmadığını kontrol et
    final String? photoUrl = playerInfo?['avatarUrl'] ?? playerInfo?['profileImageUrl'] ?? playerInfo?['photoUrl'] ?? playerInfo?['avatar'] ?? playerInfo?['image'];
    final bool hasValidUrl = photoUrl != null && photoUrl.trim().isNotEmpty && photoUrl.startsWith('http');
    
    ImageProvider? imageProvider;
    if (hasValidUrl) {
      imageProvider = CachedNetworkImageProvider(photoUrl.trim());
    }

    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isCreator = controller.matchData.value?['createdBy'] == currentUserId;
    final bool isOccupantNotCreator = assignedUid != currentUserId;
    final bool showKickButton = isCreator && !isEmpty && isOccupantNotCreator;

    return GestureDetector(
      onTap: () {
         if (isEmpty) {
             controller.moveToPosition(positionId);
         }
      },
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEmpty ? Colors.white12 : Colors.white,
                  border: Border.all(
                    color: isEmpty ? Colors.transparent : kGreen,
                    width: 2,
                  ),
                ),
                child: isEmpty 
                   ? const Icon(Icons.add, color: Colors.white, size: 36)
                    : CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: imageProvider,
                      child: imageProvider == null
                          ? Text(
                              _getInitials(playerInfo?['name']),
                              style: const TextStyle(
                                color: Colors.black54, 
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            )
                          : null,
                   ),
              ),
              if (isCaptainProfile)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                     padding: const EdgeInsets.all(4),
                     decoration: const BoxDecoration(
                       color: Colors.amber,
                       shape: BoxShape.circle,
                     ),
                     child: const Text('C', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ),
              if (showKickButton)
                Positioned(
                  top: -2,
                  right: -2,
                  child: GestureDetector(
                    onTap: () {
                      Get.defaultDialog(
                        title: 'Oyuncuyu Çıkar',
                        middleText: '\nBu oyuncuyu sahadan ve maçtan çıkarmak istediğinize emin misiniz?',
                        textCancel: 'İptal',
                        textConfirm: 'Çıkar',
                        confirmTextColor: Colors.white,
                        buttonColor: Colors.redAccent,
                        cancelTextColor: Colors.grey,
                        onConfirm: () {
                          Get.back();
                          controller.kickPlayerFromFormation(assignedUid!, positionId);
                        },
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cancel,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isCaptainProfile ? const Color(0xFF1E2836) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            /// Ensure text container isn't infinitely wide causing scale down
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              isEmpty ? "Boş" : (playerInfo?['name'] ?? "Oyuncu"),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCaptainProfile ? Colors.white : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          )
        ],
      ),
     ),
    ),
   );
  }

}
