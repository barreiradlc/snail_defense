import 'package:shared_preferences/shared_preferences.dart';

class GameSettings {
  double musicVolume;
  double sfxVolume;

  GameSettings({this.musicVolume = 0.7, this.sfxVolume = 0.7});

  static Future<GameSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return GameSettings(
      musicVolume: prefs.getDouble('musicVolume') ?? 0.7,
      sfxVolume: prefs.getDouble('sfxVolume') ?? 0.7,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('musicVolume', musicVolume);
    await prefs.setDouble('sfxVolume', sfxVolume);
  }
}
