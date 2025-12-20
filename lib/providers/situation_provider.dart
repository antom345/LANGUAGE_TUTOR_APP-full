import 'package:flutter/foundation.dart';
import 'package:language_tutor_app/models/situation.dart';

class SituationProvider extends ChangeNotifier {
  final Map<String, SituationContext> _byLanguage = {};
  int _revision = 0;

  SituationContext? getSituation(String languageCode) {
    return _byLanguage[languageCode];
  }

  bool hasSituation(String languageCode) => _byLanguage.containsKey(languageCode);

  int get revision => _revision;

  void setSituation(String languageCode, SituationContext situation) {
    _byLanguage[languageCode] = situation;
    _revision++;
    notifyListeners();
  }

  void reset(String languageCode) {
    _byLanguage.remove(languageCode);
    _revision++;
    notifyListeners();
  }
}
