import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Native iOS entry point. Provider credentials/capability are configured outside
/// the app; visibility alone does not mean Apple authentication is configured.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.apple),
          label: const Text('Apple ile Devam Et'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
