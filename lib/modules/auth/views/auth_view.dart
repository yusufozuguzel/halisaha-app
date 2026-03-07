import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import 'package:get_storage/get_storage.dart';

class AuthView extends GetView<AuthController> {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1712),
      body: SafeArea(
        child: Obx(
          () => AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: controller.isLogin.value
                ? _LoginForm(controller: controller)
                : _RegisterForm(controller: controller),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  final AuthController controller;
  const _LoginForm({required this.controller});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscureText = true;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    final savedEmail = GetStorage().read<String>('rememberedEmail');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      emailController.text = savedEmail;
      rememberMe = true;
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('login'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF132A1C),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_soccer,
                color: Color(0xFF2EED7B),
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Halı Saha",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Maçlarını organize et, takımını kur.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            "Email veya Kullanıcı Adı",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _CustomTextField(
            controller: emailController,
            hintText: "ornek@email.com veya Kullanıcı Adı",
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Şifre",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  final resetController = TextEditingController();
                  Get.defaultDialog(
                    title: 'Şifreyi Sıfırla',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: const Color(0xFF132A1C),
                    content: Column(
                      children: [
                        const SizedBox(height: 10),
                        TextField(
                          controller: resetController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Email veya Kullanıcı Adı",
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    textCancel: 'İptal',
                    cancelTextColor: Colors.white54,
                    textConfirm: 'Gönder',
                    confirmTextColor: Colors.black,
                    buttonColor: const Color(0xFF2EED7B),
                    onConfirm: () {
                      if (resetController.text.trim().isNotEmpty) {
                        widget.controller.resetPassword(resetController.text);
                        Get.back();
                      }
                    },
                    onCancel: () {},
                  );
                },
                child: const Text(
                  "Unuttun mu?",
                  style: TextStyle(
                    color: Color(0xFF2EED7B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CustomTextField(
            controller: passwordController,
            hintText: "••••••••",
            prefixIcon: Icons.lock_outline,
            obscureText: obscureText,
            suffixIcon: IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: obscureText
                    ? Colors.white.withOpacity(0.4)
                    : Colors.white,
              ),
              onPressed: () {
                setState(() {
                  obscureText = !obscureText;
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Checkbox(
                value: rememberMe,
                onChanged: (val) {
                  setState(() {
                    rememberMe = val ?? false;
                  });
                },
                activeColor: const Color(0xFF2EED7B),
                checkColor: Colors.black,
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
              const Text(
                "Beni Hatırla",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => widget.controller.login(
              emailController.text,
              passwordController.text,
              rememberMe: rememberMe,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2EED7B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Giriş Yap",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "veya",
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
            ],
          ),
          const SizedBox(height: 32),
          _GoogleButton(
            text: "Google ile Devam Et",
            onPressed: () => widget.controller.signInWithGoogle(),
          ),
          const SizedBox(height: 40),
          Center(
            child: RichText(
              text: TextSpan(
                text: "Hesabın yok mu? ",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: "Kayıt Ol",
                    style: const TextStyle(
                      color: Color(0xFF2EED7B),
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        widget.controller.isLogin.value = false;
                      },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  final AuthController controller;
  const _RegisterForm({required this.controller});

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscureText = true;
  bool isAgreed = false;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('register'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => widget.controller.isLogin.value = true,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Hesap Oluştur 🚀",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Futbol dünyasına adım atmak için bilgilerini gir.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "Ad Soyad",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _CustomTextField(
            controller: fullNameController,
            hintText: "Ahmet Yılmaz",
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 20),
          const Text(
            "Email Adresi",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _CustomTextField(
            controller: emailController,
            hintText: "ornek@email.com",
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          const Text(
            "Şifre",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _CustomTextField(
            controller: passwordController,
            hintText: "••••••••",
            prefixIcon: Icons.lock_outline,
            obscureText: obscureText,
            suffixIcon: IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: obscureText
                    ? Colors.white.withOpacity(0.4)
                    : Colors.white,
              ),
              onPressed: () {
                setState(() {
                  obscureText = !obscureText;
                });
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    isAgreed = !isAgreed;
                  });
                },
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2, right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isAgreed
                          ? const Color(0xFF2EED7B)
                          : Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    color: isAgreed
                        ? const Color(0xFF2EED7B)
                        : Colors.transparent,
                  ),
                  child: isAgreed
                      ? const Icon(Icons.check, size: 14, color: Colors.black)
                      : null,
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                      height: 1.5,
                    ),
                    children: const [
                      TextSpan(
                        text: "Kullanım Koşulları",
                        style: TextStyle(color: Color(0xFF2EED7B)),
                      ),
                      TextSpan(text: "'nı ve "),
                      TextSpan(
                        text: "Gizlilik Politikası",
                        style: TextStyle(color: Color(0xFF2EED7B)),
                      ),
                      TextSpan(text: "'nı okudum ve kabul ediyorum."),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => widget.controller.register(
              emailController.text,
              passwordController.text,
              fullNameController.text,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2EED7B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  "Kayıt Ol",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "YA DA",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
            ],
          ),
          const SizedBox(height: 32),
          _GoogleButton(
            text: "Google ile Devam Et",
            onPressed: () => widget.controller.signInWithGoogle(),
          ),
          const SizedBox(height: 40),
          Center(
            child: RichText(
              text: TextSpan(
                text: "Zaten bir hesabın var mı? ",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: "Giriş Yap",
                    style: const TextStyle(
                      color: Color(0xFF2EED7B),
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        widget.controller.isLogin.value = true;
                      },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _GoogleButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/google_logo.png', height: 24),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _CustomTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: Icon(prefixIcon, color: Colors.white.withOpacity(0.4)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2EED7B)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
