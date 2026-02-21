import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:halisaha_app/modules/auth/controllers/auth_controller.dart';

class HomeView extends StatelessWidget {
  HomeView({super.key});

  final AuthController authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home Screen"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authController.logout();
            },
          ),
        ],
      ),
      body: const Center(child: Text("Hoşgeldin")),
    );
  }
}
