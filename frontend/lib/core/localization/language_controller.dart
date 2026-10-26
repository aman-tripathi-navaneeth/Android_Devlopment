import 'package:flutter/material.dart';

/// Language state controller facilitating instant live switching between English and Telugu.
class LanguageController extends ChangeNotifier {
  static final LanguageController _instance = LanguageController._internal();
  factory LanguageController() => _instance;
  LanguageController._internal();

  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isTelugu => _locale.languageCode == 'te';

  void setLocale(Locale newLocale) {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'en') {
      setLocale(const Locale('te'));
    } else {
      setLocale(const Locale('en'));
    }
  }
}
