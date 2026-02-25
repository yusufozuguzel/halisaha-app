import 'package:get/get.dart';
import '../models/match_model.dart';
import '../services/match_service.dart';

class MatchController extends GetxController {
  final MatchService _service = MatchService();

  var matches = <MatchModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    _service.getMatches().listen((data) {
      matches.value = data;
    });
  }

  Future<void> createMatch(MatchModel match) async {
    await _service.createMatch(match);
  }
}
