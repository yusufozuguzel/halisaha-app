import 'dart:async';
import 'package:get/get.dart';
import '../models/match_model.dart';
import '../services/match_service.dart';

class MatchController extends GetxController {
  final MatchService _service = MatchService();

  StreamSubscription<List<MatchModel>>? _subscription;

  var matches = <MatchModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    _subscription = _service.getMatches().listen(
      (data) {
        if (!isClosed) matches.value = data;
      },
      onError: (_) {
        if (!isClosed) matches.clear();
      },
    );
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  Future<void> createMatch(MatchModel match) async {
    await _service.createMatch(match);
  }
}
