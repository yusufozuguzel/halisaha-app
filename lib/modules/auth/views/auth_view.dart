import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class AuthView extends GetView<AuthController> {
  AuthView({super.key});

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login / Register")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),

            Obx(
              () => ElevatedButton(
                onPressed: () {
                  controller.submit(
                    emailController.text,
                    passwordController.text,
                  );
                },
                child: Text(controller.isLogin.value ? "Login" : "Register"),
              ),
            ),

            TextButton(
              onPressed: () {
                controller.isLogin.toggle();
              },
              child: const Text("Switch Mode"),
            ),
          ],
        ),
      ),
    );
  }
}
