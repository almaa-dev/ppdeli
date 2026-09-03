import 'package:flutter/services.dart';
import 'package:pickles_and_pies/util/app_constants.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController implements GetxService {
  final SharedPreferences sharedPreferences;
  ThemeController({required this.sharedPreferences}) {
    _loadCurrentTheme();
  }

  bool _darkTheme = false;
  Color? _lightColor;
  Color? _darkColor;

  bool get darkTheme => _darkTheme;
  Color? get darkColor => _darkColor;
  Color? get lightColor => _lightColor;

  String _lightMap = '[]';
  String get lightMap => _lightMap;

  String _darkMap = '[]';
  String get darkMap => _darkMap;

  String _lightMapTaxi = '[]';
  String get lightMapTaxi => _lightMapTaxi;

  void toggleTheme() {
    _darkTheme = !_darkTheme;
    sharedPreferences.setBool(AppConstants.theme, _darkTheme);
    // The root GetBuilder in main.dart is registered with id 'theme_root'
    // and is what rebuilds GetMaterialApp with the new `theme:`. Calling
    // update() with no id would NOT trigger that builder, so the theme
    // would toggle in the controller but the MaterialApp would never
    // re-evaluate `themeController.darkTheme ? dark() : light()`.
    update(['theme_root']);
    // Also notify the un-keyed GetBuilders (e.g. setting_page, web_menu_bar)
    // that listen to the same controller without an id, so widgets like
    // the dark/light icon switch react to the toggle.
    update();
  }

  void changeTheme(Color lightColor, Color darkColor) {
    _lightColor = lightColor;
    _darkColor = darkColor;
    update(['theme_root']);
    update();
  }

  void _loadCurrentTheme() async {
    _lightMap = await rootBundle.loadString('assets/map/light_map.json');
    _darkMap = await rootBundle.loadString('assets/map/dark_map.json');
    _lightMapTaxi = await rootBundle.loadString('assets/map/light_taxi.json');
    _darkTheme = sharedPreferences.getBool(AppConstants.theme) ?? false;
    // Make sure GetMaterialApp picks up the persisted theme on cold start.
    update(['theme_root']);
    update();
  }
}
