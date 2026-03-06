import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/friends_controller.dart';
import '../../home/views/home_view.dart';
import '../../home/views/my_matches_view.dart';
import '../../home/views/discover_view.dart';
import '../../home/views/profile_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../match/controllers/match_create_controller.dart';
import '../../match/views/match_create_view.dart';

class FriendsView extends StatelessWidget {
  const FriendsView({super.key});

  static const _green = Color(0xFF2EED7B);

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(FriendsController());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: _buildAppBar(context),
        floatingActionButton: _buildFab(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _buildBottomNav(context),
        body: Column(
          children: [
            _buildSearchBar(context, ctrl),
            // Search results overlay when query >= 2 chars
            Obx(() {
              final q = ctrl.searchQuery.value.trim();
              if (q.length >= 2) {
                return Expanded(child: _SearchResultsLayer(ctrl: ctrl));
              }
              return Expanded(
                child: Column(
                  children: [
                    _buildTabBar(context),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _FollowingTab(ctrl: ctrl),
                          _RequestsTab(ctrl: ctrl),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.card(context),
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.text(context),
          size: 20,
        ),
        onPressed: () => Get.back(),
      ),
      title: Text(
        'Arkadaşlar',
        style: TextStyle(
          color: AppColors.text(context),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.person_add_outlined, color: _green),
          onPressed: () => Get.snackbar(
            'Arkadaş Ekle',
            'Arama çubuğuna isim yazarak oyuncu bulabilirsin!',
            backgroundColor: AppColors.card(context),
            colorText: AppColors.text(context),
            borderRadius: 12,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 2),
            icon: const Icon(Icons.person_add, color: _green),
          ),
        ),
      ],
    );
  }

  // ── FAB ────────────────────────────────────────────────────
  Widget _buildFab(BuildContext context) {
    final bg = AppColors.bg(context);
    return GestureDetector(
      onTap: () {
        Get.put(MatchCreateController());
        Get.to(
          () => const MatchCreateView(),
          transition: Transition.downToUp,
          duration: const Duration(milliseconds: 300),
        );
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: _green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.add, size: 32, color: bg),
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────
  Widget _buildSearchBar(BuildContext context, FriendsController ctrl) {
    final card = AppColors.card(context);
    final subText = AppColors.subText(context);
    final textColor = AppColors.text(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => ctrl.searchQuery.value = v,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Arkadaşlarını ara...',
                  hintStyle: TextStyle(color: subText, fontSize: 14),
                  prefixIcon: Obx(
                    () => Icon(
                      ctrl.isSearching.value
                          ? Icons.hourglass_empty
                          : Icons.search,
                      color: subText,
                      size: 20,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            Obx(() {
              if (ctrl.searchQuery.value.isEmpty)
                return const SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.clear, color: subText, size: 18),
                onPressed: () {
                  ctrl.searchQuery.value = '';
                  ctrl.searchResults.clear();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── TabBar ─────────────────────────────────────────────────
  Widget _buildTabBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TabBar(
        labelColor: _green,
        unselectedLabelColor: AppColors.navInactive(context),
        indicatorColor: _green,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: 'Arkadaşlarım'),
          Tab(text: 'İstekler'),
        ],
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    final navBg = AppColors.navBg(context);
    return Container(
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomAppBar(
          color: navBg,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(
                context,
                Icons.home_filled,
                'Ana Sayfa',
                false,
                onTap: () => Get.offAll(
                  () => const HomeView(userName: 'Oyuncu'),
                  transition: Transition.noTransition,
                ),
              ),
              _navItem(
                context,
                Icons.sports_soccer,
                'Maçlarım',
                false,
                onTap: () => Get.offAll(
                  () => MyMatchesView(),
                  transition: Transition.noTransition,
                ),
              ),
              const SizedBox(width: 48),
              _navItem(
                context,
                Icons.explore_outlined,
                'Keşfet',
                false,
                onTap: () => Get.offAll(
                  () => DiscoverView(),
                  transition: Transition.noTransition,
                ),
              ),
              _navItem(
                context,
                Icons.person_outline,
                'Profil',
                false,
                onTap: () => Get.offAll(
                  () => const ProfileView(),
                  transition: Transition.noTransition,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label,
    bool isActive, {
    required VoidCallback onTap,
  }) {
    final color = isActive ? _green : AppColors.navInactive(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: _green.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Search Results Layer ─────────────────────────────────────
class _SearchResultsLayer extends StatelessWidget {
  final FriendsController ctrl;
  const _SearchResultsLayer({required this.ctrl});

  static const _green = Color(0xFF2EED7B);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isSearching.value) {
        return const Center(
          child: CircularProgressIndicator(color: _green, strokeWidth: 2),
        );
      }
      final results = ctrl.searchResults;
      if (results.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 60,
                color: AppColors.subText(context).withOpacity(0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Oyuncu bulunamadı.',
                style: TextStyle(
                  color: AppColors.subText(context),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: results.length,
        separatorBuilder: (_, __) =>
            Divider(color: AppColors.border(context), height: 1),
        itemBuilder: (ctx, i) =>
            _UserTile(user: results[i], ctrl: ctrl, showInviteBtn: false),
      );
    });
  }
}

// ── Following Tab ────────────────────────────────────────────
class _FollowingTab extends StatelessWidget {
  final FriendsController ctrl;
  const _FollowingTab({required this.ctrl});

  static const _green = Color(0xFF2EED7B);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: _green, strokeWidth: 2),
        );
      }
      final list = ctrl.filteredFollowing;
      if (list.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 72,
                  color: _green.withOpacity(0.35),
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz kimseyi takip etmiyorsun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Arama yaparak arkadaşlarını bul ve takip et!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.subText(context),
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: list.length,
        separatorBuilder: (_, __) =>
            Divider(color: AppColors.border(context), height: 1),
        itemBuilder: (ctx, i) =>
            _UserTile(user: list[i], ctrl: ctrl, showInviteBtn: true),
      );
    });
  }
}

// ── Requests Tab ─────────────────────────────────────────────
class _RequestsTab extends StatelessWidget {
  final FriendsController ctrl;
  const _RequestsTab({required this.ctrl});

  static const _green = Color(0xFF2EED7B);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = ctrl.filteredRequests;
      if (list.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                size: 64,
                color: _green.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Bekleyen istek yok.',
                style: TextStyle(
                  color: AppColors.subText(context),
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: list.length,
        separatorBuilder: (_, __) =>
            Divider(color: AppColors.border(context), height: 1),
        itemBuilder: (ctx, i) => _RequestTile(user: list[i], ctrl: ctrl),
      );
    });
  }
}

// ── User Tile (Following list + Search results) ───────────────
class _UserTile extends StatelessWidget {
  final UserModel user;
  final FriendsController ctrl;
  final bool showInviteBtn;

  const _UserTile({
    required this.user,
    required this.ctrl,
    required this.showInviteBtn,
  });

  static const _green = Color(0xFF2EED7B);

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);

    return InkWell(
      onTap: () => Get.to(
        () => const ProfileView(),
        arguments: {'uid': user.uid},
        transition: Transition.cupertino,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Avatar
            _AvatarWidget(user: user, size: 48),
            const SizedBox(width: 12),
            // Name & position
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (user.position.isNotEmpty)
                    Text(
                      user.position.toUpperCase(),
                      style: TextStyle(
                        color: subText,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                      ),
                    ),
                ],
              ),
            ),
            if (showInviteBtn)
              InkWell(
                onTap: () => ctrl.sendMatchInvite(
                  context: context,
                  targetUid: user.uid,
                  targetName: user.name,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Maça Davet Et',
                    style: TextStyle(
                      color: Color(0xFF0F1712),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              )
            else
              // In search results show "Profil Gör"
              InkWell(
                onTap: () => Get.to(
                  () => const ProfileView(),
                  arguments: {'uid': user.uid},
                  transition: Transition.cupertino,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Text(
                    'Profili Gör',
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Request Tile ─────────────────────────────────────────────
class _RequestTile extends StatelessWidget {
  final UserModel user;
  final FriendsController ctrl;
  const _RequestTile({required this.user, required this.ctrl});

  static const _green = Color(0xFF2EED7B);

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);

    return InkWell(
      onTap: () => Get.to(
        () => const ProfileView(),
        arguments: {'uid': user.uid},
        transition: Transition.cupertino,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _AvatarWidget(user: user, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (user.position.isNotEmpty)
                    Text(
                      user.position.toUpperCase(),
                      style: TextStyle(
                        color: subText,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                      ),
                    ),
                ],
              ),
            ),
            // Accept
            InkWell(
              onTap: () async {
                await ctrl.acceptRequest(user.uid);
                Get.snackbar(
                  'Kabul Edildi ✅',
                  '${user.name} artık arkadaşın!',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Kabul Et',
                  style: TextStyle(
                    color: Color(0xFF0F1712),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Reject
            InkWell(
              onTap: () async {
                await ctrl.rejectRequest(user.uid);
                Get.snackbar(
                  'Reddedildi',
                  '${user.name} isteği reddedildi.',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Icon(Icons.close, size: 16, color: subText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar Widget ────────────────────────────────────────────
class _AvatarWidget extends StatelessWidget {
  final UserModel user;
  final double size;
  const _AvatarWidget({required this.user, required this.size});

  static const _green = Color(0xFF2EED7B);

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (user.avatarType == 'base64' && user.avatarData.isNotEmpty) {
      try {
        child = ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.memory(
            base64Decode(user.avatarData),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultIcon(context),
          ),
        );
      } catch (_) {
        child = _defaultIcon(context);
      }
    } else {
      child = _defaultIcon(context);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.card(context),
        border: Border.all(color: _green.withOpacity(0.4), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: child,
      ),
    );
  }

  Widget _defaultIcon(BuildContext context) {
    const icons = [
      Icons.person,
      Icons.sports_soccer,
      Icons.sports_martial_arts,
      Icons.face,
    ];
    final idx = int.tryParse(user.avatarData) ?? 0;
    return Container(
      color: AppColors.overlay(context),
      child: Icon(
        icons[idx % icons.length],
        color: AppColors.text(context),
        size: size * 0.45,
      ),
    );
  }
}
