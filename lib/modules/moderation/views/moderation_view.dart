import 'package:flutter/material.dart';
import '../../../core/services/safety_api.dart';

class ModerationView extends StatefulWidget {
  const ModerationView({super.key, this.api});
  final SafetyApi? api;
  @override
  State<ModerationView> createState() => _ModerationViewState();
}

class _ModerationViewState extends State<ModerationView> {
  late final SafetyApi _api = widget.api ?? SafetyApi();
  List<Map<String, dynamic>> _items = [];
  bool _busy = false;
  String _kind = 'reports', _next = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
      if (!more) _items = [];
    });
    try {
      final result = await _api.call('moderationQueue', {
        'kind': _kind,
        'after': more ? _next : '',
      });
      if (!mounted) return;
      setState(() {
        final items = (result['items'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _items = more ? [..._items, ...items] : items;
        _next = result['next'] as String? ?? '';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _items = [];
          _next = '';
          _error =
              'Liste yüklenemedi. Yetkinizi kontrol edin ve gerekirse yeniden giriş yapın.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send(String function, Map<String, dynamic> data) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.call(function, data);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'İşlem uygulanamadı. İçerik veya yetkiniz değişmiş olabilir. Listeyi yenileyip yeniden inceleyin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(
    Map<String, dynamic> item, {
    bool restore = false,
    bool redact = false,
  }) async {
    final match = item['type'] == 'match';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          restore
              ? 'Kısıtlamayı Kaldır'
              : match
              ? 'Maçı Kaldır'
              : redact
              ? 'Profili Temizle ve Kısıtla'
              : 'Hesabı Kısıtla',
        ),
        content: Text(
          restore
              ? 'Hesap yeniden profil düzenleyebilir, maç ve arkadaşlık işlemleri yapabilir.'
              : match
              ? 'Maç kalıcı olarak kaldırılacak. Bağlı davetler sunucuda temizlenecek.'
              : redact
              ? 'Profil adı, konumu ve fotoğrafı temizlenecek; hesap yazma işlemleri kısıtlanacak. Eski fotoğraf ve bildirim kopyaları sunucuda silinecek. Silinen içerik geri getirilemez. Kısıtlama temizlik tamamlandıktan sonra kaldırılabilir.'
              : 'Profil düzenleme, fotoğraf yükleme, maç ve arkadaşlık yazma işlemleri durdurulacak. Mevcut içerikler kaldırılmaz. Giriş, okuma, şikayet ve hesap silme erişimi korunur. Kısıtlama geri alınabilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _send(
      restore ? 'restoreModeratedAccount' : 'applyModerationAction',
      restore
          ? {'uid': item['id'], 'reportId': item['reportId']}
          : {
              'reportId': item['id'],
              'action': match
                  ? 'removeMatch'
                  : redact
                  ? 'redactProfile'
                  : 'restrictAccount',
              'version': item['version'],
            },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Moderasyon'),
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'reports', label: Text('Şikayetler')),
            ButtonSegment(value: 'restrictions', label: Text('Kısıtlamalar')),
          ],
          selected: {_kind},
          onSelectionChanged: _busy
              ? null
              : (value) {
                  _kind = value.single;
                  _load();
                },
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        if (!_busy && _error == null && _items.isEmpty)
          const Text('Bekleyen kayıt yok.'),
        for (final item in _items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _kind == 'restrictions'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kısıtlanan hesap: ${item['id']}'),
                        if (item['cleanupPending'] == true)
                          const Text(
                            'İçerik temizliği sürüyor. Durumu yenileyebilirsiniz.',
                          ),
                        TextButton(
                          onPressed: _busy || item['cleanupPending'] == true
                              ? null
                              : () => _action(item, restore: true),
                          child: const Text('Kısıtlamayı Kaldır'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['type'] == 'user' ? 'Profil / fotoğraf' : 'Maç'}: ${item['targetId']}',
                        ),
                        Text('${item['preview']?['title'] ?? ''}'),
                        Text('${item['preview']?['detail'] ?? ''}'),
                        if (Uri.tryParse(
                              item['preview']?['image'] ?? '',
                            )?.scheme ==
                            'https')
                          Image.network(
                            item['preview']['image'],
                            height: 120,
                            errorBuilder: (_, error, stack) =>
                                const Text('Fotoğraf yüklenemedi.'),
                          ),
                        Text(
                          'Neden: ${const {'harassment': 'Taciz / zorbalık', 'inappropriateContent': 'Uygunsuz içerik', 'spam': 'Spam', 'other': 'Diğer'}[item['reason']] ?? 'Diğer'}',
                        ),
                        if (item['version'] == '')
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _send('reviewContentReport', {
                                    'reportId': item['id'],
                                    'status': 'dismissed',
                                  }),
                            child: const Text('İçerik Yok — Kaydı Kapat'),
                          )
                        else if (item['status'] == 'pending')
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _send('reviewContentReport', {
                                    'reportId': item['id'],
                                    'status': 'reviewing',
                                  }),
                            child: const Text('İncelemeye Al'),
                          )
                        else
                          Wrap(
                            children: [
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _send('reviewContentReport', {
                                        'reportId': item['id'],
                                        'status': 'dismissed',
                                      }),
                                child: const Text('İhlal Bulunmadı'),
                              ),
                              TextButton(
                                onPressed: _busy || item['version'] == ''
                                    ? null
                                    : () => _action(item),
                                child: Text(
                                  item['type'] == 'match'
                                      ? 'Maçı Kaldır'
                                      : 'Hesabı Kısıtla',
                                ),
                              ),
                              if (item['type'] == 'user')
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _action(item, redact: true),
                                  child: const Text(
                                    'Profili Temizle ve Kısıtla',
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
            ),
          ),
        if (_next.isNotEmpty)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Daha Fazla'),
          ),
      ],
    ),
  );
}
