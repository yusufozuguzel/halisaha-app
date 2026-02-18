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
      appBar: AppBar(title: const Text("Auth")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                onPressed: () => controller.submit(
                  emailController.text,
                  passwordController.text,
                ),
                child: Text(controller.isLogin.value ? "Login" : "Register"),
              ),
            ),
            TextButton(
              onPressed: () {
                controller.isLogin.toggle();
              },
              child: Obx(
                () => Text(
                  controller.isLogin.value
                      ? "Hesabın yok mu? Register"
                      : "Zaten hesabın var mı? Login",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
