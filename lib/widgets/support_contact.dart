import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportContact {
  static const email = 'destekdepar@gmail.com';

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Destek ve İtiraz'),
      scrollable: true,
      content: const _SupportContactBody(),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}

class _SupportContactBody extends StatefulWidget {
  const _SupportContactBody();
  @override
  State<_SupportContactBody> createState() => _SupportContactBodyState();
}

class _SupportContactBodyState extends State<_SupportContactBody> {
  String? _message;
  bool _busy = false;

  Future<void> _contact({bool copy = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      if (copy) {
        await Clipboard.setData(
          const ClipboardData(text: SupportContact.email),
        );
        message = 'E-posta adresi kopyalandı.';
      } else {
        final opened = await launchUrl(
          Uri(scheme: 'mailto', path: SupportContact.email),
        );
        if (!opened) {
          message =
              'E-posta uygulaması açılamadı. Adresi kopyalayarak bize yazabilirsiniz.';
        }
      }
    } catch (_) {
      message = copy
          ? 'Adres kopyalanamadı. Yukarıdaki adresi seçerek kopyalayabilirsiniz.'
          : 'E-posta uygulaması açılamadı. Adresi kopyalayarak bize yazabilirsiniz.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _message = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Destek talepleriniz, şikayetleriniz ve hesap kısıtlamasına itirazlarınız için bize yazabilirsiniz.',
      ),
      const SizedBox(height: 12),
      const SelectableText(SupportContact.email),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: _busy ? null : () => _contact(),
            icon: const Icon(Icons.email_outlined),
            label: const Text('E-posta Yaz'),
          ),
          TextButton.icon(
            onPressed: _busy ? null : () => _contact(copy: true),
            icon: const Icon(Icons.copy),
            label: const Text('Adresi Kopyala'),
          ),
        ],
      ),
      if (_message != null) Text(_message!),
    ],
  );
}
