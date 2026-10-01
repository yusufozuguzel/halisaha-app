import 'package:flutter/material.dart';

import '../core/services/content_reports.dart';

Future<void> showReportContentDialog(
  BuildContext context, {
  required ReportTarget type,
  required String targetId,
  ContentReports? reports,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _ReportContentDialog(type: type, targetId: targetId, reports: reports),
);

class _ReportContentDialog extends StatefulWidget {
  const _ReportContentDialog({
    required this.type,
    required this.targetId,
    this.reports,
  });
  final ReportTarget type;
  final String targetId;
  final ContentReports? reports;

  @override
  State<_ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<_ReportContentDialog> {
  ReportReason _reason = ReportReason.inappropriateContent;
  bool _busy = false;
  String? _result;
  bool _sent = false;
  bool _checking = true;
  bool _available = false;
  late final ContentReports _reports;

  @override
  void initState() {
    super.initState();
    _reports = widget.reports ?? ContentReports();
    _reports.isAvailable().then((available) {
      if (mounted) {
        setState(() {
          _checking = false;
          _available = available;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Şikayet Et'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_checking)
          const Text('Şikayet hizmeti kontrol ediliyor…')
        else if (!_available)
          const Text(
            'Şikayet gönderme hizmeti şu anda kullanılamıyor. '
            'Kullanıcı profilindeki engelleme seçeneğini kullanabilirsiniz.',
          )
        else ...[
          DropdownButton<ReportReason>(
            value: _reason,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: ReportReason.inappropriateContent,
                child: Text('Uygunsuz içerik / fotoğraf'),
              ),
              DropdownMenuItem(
                value: ReportReason.harassment,
                child: Text('Taciz veya zorbalık'),
              ),
              DropdownMenuItem(value: ReportReason.spam, child: Text('Spam')),
              DropdownMenuItem(value: ReportReason.other, child: Text('Diğer')),
            ],
            onChanged: _busy || _sent
                ? null
                : (value) => setState(() => _reason = value!),
          ),
          if (_result != null) Text(_result!),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Kapat'),
      ),
      if (_available && !_sent)
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await _reports.submit(
                      type: widget.type,
                      targetId: widget.targetId,
                      reason: _reason,
                    );
                    if (mounted) {
                      setState(() {
                        _sent = true;
                        _result = 'Şikayetiniz kaydedildi.';
                      });
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => _result =
                            'Şikayet gönderilemedi veya bu içerik için zaten bir şikayet gönderdiniz.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'Gönderiliyor…' : 'Gönder'),
        ),
    ],
  );
}
