import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ---------------------------------------------------------------------------
// Veri Modeli
// ---------------------------------------------------------------------------
enum _NotifType { matchInvite, matchApproval, friendActivity, systemAlert }

class _NotifItem {
  final String id;
  final String name;
  final String message;
  final String time;
  final _NotifType type;
  final String avatarUrl;
  final bool hasAcceptReject; // Kabul Et / Reddet butonları
  final bool hasApprove; // Onayla butonu
  final bool hasDelete; // Sil butonu
  final bool isHighlighted; // Sol yeşil çizgi

  _NotifItem({
    required this.id,
    required this.name,
    required this.message,
    required this.time,
    required this.type,
    required this.avatarUrl,
    this.hasAcceptReject = false,
    this.hasApprove = false,
    this.hasDelete = false,
    this.isHighlighted = false,
  });
}

// ---------------------------------------------------------------------------
// Sayfa
// ---------------------------------------------------------------------------
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  // ---- Bugünün bildirimleri ----
  final List<_NotifItem> _today = [
    _NotifItem(
      id: 't1',
      name: 'Mehmet Yılmaz',
      message: 'seni "Salı Futbolu" maçına davet etti.',
      time: '2 saat önce',
      type: _NotifType.matchInvite,
      avatarUrl: 'https://picsum.photos/seed/nav1/100/100',
      hasAcceptReject: true,
      isHighlighted: true,
    ),
    _NotifItem(
      id: 't2',
      name: 'Gold Arena Halı Saha',
      message: 'Çarşamba 20:00 rezervasyonun onaylandı!',
      time: '5 saat önce',
      type: _NotifType.matchApproval,
      avatarUrl: 'https://picsum.photos/seed/nav2/100/100',
      hasApprove: true,
    ),
    _NotifItem(
      id: 't3',
      name: 'Ayşe Kaya',
      message: '"Cuma Akşamı" maçına katıldı. Sen de katılmak ister misin?',
      time: '6 saat önce',
      type: _NotifType.friendActivity,
      avatarUrl: 'https://picsum.photos/seed/nav3/100/100',
      hasDelete: true,
    ),
  ];

  // ---- Dünün bildirimleri ----
  final List<_NotifItem> _yesterday = [
    _NotifItem(
      id: 'y1',
      name: 'Sistem',
      message: 'Profilin %80 tamamlandı. Fotoğraf ekleyerek tamamla!',
      time: 'Dün, 14:30',
      type: _NotifType.systemAlert,
      avatarUrl: 'https://picsum.photos/seed/nav4/100/100',
      hasDelete: true,
    ),
    _NotifItem(
      id: 'y2',
      name: 'Ali Demir',
      message: '"Pazar Turnuvası" maçın iptal edildi.',
      time: 'Dün, 09:15',
      type: _NotifType.matchApproval,
      avatarUrl: 'https://picsum.photos/seed/nav5/100/100',
      hasDelete: true,
    ),
  ];

  // ---- Silme: Geri al desteği ----
  void _removeItem(List<_NotifItem> list, _NotifItem item) {
    final idx = list.indexOf(item);
    setState(() => list.remove(item));

    Get.snackbar(
      '',
      '',
      titleText: const SizedBox.shrink(),
      messageText: Row(
        children: [
          const Expanded(
            child: Text(
              'Bildirim silindi.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => list.insert(idx.clamp(0, list.length), item));
              Get.closeCurrentSnackbar();
            },
            child: const Text(
              'Geri Al',
              style: TextStyle(
                color: Color(0xFF2EED7B),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1C2B21),
      borderRadius: 12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  void _onAccept(_NotifItem item) {
    Get.snackbar(
      'Kabul Edildi ✓',
      '${item.name} daveti kabul edildi!',
      backgroundColor: const Color(0xFF1C3A24),
      colorText: const Color(0xFF2EED7B),
      borderRadius: 12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.check_circle, color: Color(0xFF2EED7B)),
    );
  }

  void _onApprove(_NotifItem item) {
    Get.snackbar(
      'Onaylandı ✓',
      '${item.message}',
      backgroundColor: const Color(0xFF1C3A24),
      colorText: const Color(0xFF2EED7B),
      borderRadius: 12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.check_circle, color: Color(0xFF2EED7B)),
    );
  }

  // ---- Ana İkon eşleştirme ----
  IconData _iconFor(_NotifType type) {
    switch (type) {
      case _NotifType.matchInvite:
        return Icons.sports_soccer;
      case _NotifType.matchApproval:
        return Icons.event_available;
      case _NotifType.friendActivity:
        return Icons.people;
      case _NotifType.systemAlert:
        return Icons.notifications;
    }
  }

  Color _iconColorFor(_NotifType type) {
    switch (type) {
      case _NotifType.matchInvite:
        return const Color(0xFF2EED7B);
      case _NotifType.matchApproval:
        return Colors.blueAccent;
      case _NotifType.friendActivity:
        return Colors.orangeAccent;
      case _NotifType.systemAlert:
        return Colors.purpleAccent;
    }
  }

  // ============================
  // BUILD
  // ============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1712),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: (_today.isEmpty && _yesterday.isEmpty)
                  ? _buildEmpty()
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (_today.isNotEmpty) ...[
                          _buildSectionTitle('BUGÜN'),
                          ..._today.map((n) => _buildCard(n, _today)).toList(),
                        ],
                        if (_yesterday.isNotEmpty) ...[
                          _buildSectionTitle('DÜN'),
                          ..._yesterday
                              .map((n) => _buildCard(n, _yesterday))
                              .toList(),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Header ----
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Geri butonu
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Bildirimler',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _today.clear();
                _yesterday.clear();
              });
            },
            child: const Text(
              'Tümünü Oku',
              style: TextStyle(
                color: Color(0xFF2EED7B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Bölüm Başlığı ----
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  // ---- Bildirim Kartı ----
  Widget _buildCard(_NotifItem item, List<_NotifItem> list) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: item.isHighlighted
              ? const Color(0xFF2EED7B).withOpacity(0.07)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isHighlighted
                ? const Color(0xFF2EED7B).withOpacity(0.25)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sol yeşil çizgi (sadece highlighted)
                if (item.isHighlighted)
                  Container(
                    width: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2EED7B),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                // İçerik
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar + İsim + Zaman
                        Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: DecorationImage(
                                      image: NetworkImage(item.avatarUrl),
                                      fit: BoxFit.cover,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: _iconColorFor(item.type),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF0F1712),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      _iconFor(item.type),
                                      color: Colors.white,
                                      size: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.message,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.65),
                                      fontSize: 12,
                                      height: 1.4,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.time,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 10,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                        // Butonlar
                        if (item.hasAcceptReject ||
                            item.hasApprove ||
                            item.hasDelete) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (item.hasAcceptReject) ...[
                                _greenButton('Kabul Et', () => _onAccept(item)),
                                const SizedBox(width: 8),
                                _outlineButton(
                                  'Reddet',
                                  () => _removeItem(list, item),
                                ),
                              ],
                              if (item.hasApprove) ...[
                                _greenButton('Onayla', () => _onApprove(item)),
                                const SizedBox(width: 8),
                                _outlineButton(
                                  'Sil',
                                  () => _removeItem(list, item),
                                ),
                              ],
                              if (item.hasDelete &&
                                  !item.hasAcceptReject &&
                                  !item.hasApprove)
                                _outlineButton(
                                  'Sil',
                                  () => _removeItem(list, item),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _greenButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF2EED7B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0F1712),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _outlineButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: Colors.white.withOpacity(0.2),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Bildirim yok',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
