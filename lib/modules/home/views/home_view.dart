import 'package:flutter/material.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ana Sayfa ⚽"),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "Home UI Başladı",
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
