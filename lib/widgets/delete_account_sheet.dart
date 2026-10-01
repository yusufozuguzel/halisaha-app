import 'package:flutter/material.dart';

class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({
    super.key,
    required this.requiresPassword,
    required this.onDelete,
  });

  final bool requiresPassword;
  final Future<void> Function(String password) onDelete;

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Hesabı Sil',
          style: TextStyle(fontSize: 20, color: Colors.redAccent),
        ),
        const SizedBox(height: 16),
        const Text(
          'Bu işlem geri alınamaz. Devam etmek için kimliğinizi doğrulamanız gerekir.',
        ),
        if (widget.requiresPassword)
          TextField(
            controller: _password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Şifre'),
          ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final password = _password.text;
                  _password.clear();
                  try {
                    await widget.onDelete(password);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'İşleniyor…' : 'Hesabımı Kalıcı Olarak Sil'),
        ),
      ],
    ),
  );
}
