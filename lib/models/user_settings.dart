import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User settings stored in shared preferences
class UserSettings extends Equatable {
  const UserSettings({
    this.ftp = 200,
    this.weight = 70.0,
    this.totalGears = 22,
    this.keepScreenOn = true,
    this.defaultMode = 'sim',
    this.lastDeviceId,
    this.userName,
  });

  final int ftp; // Functional Threshold Power in watts
  final double weight; // Weight in kg
  final int totalGears; // Virtual shifting total gears
  final bool keepScreenOn; // Prevent screen timeout during rides
  final String defaultMode; // 'sim' or 'erg'
  final String? lastDeviceId; // Auto-connect to last device
  final String? userName;

  // SharedPreferences keys
  static const _keyFtp = 'ftp';
  static const _keyWeight = 'weight';
  static const _keyTotalGears = 'totalGears';
  static const _keyKeepScreenOn = 'keepScreenOn';
  static const _keyDefaultMode = 'defaultMode';
  static const _keyLastDeviceId = 'lastDeviceId';
  static const _keyUserName = 'userName';

  /// Load settings from SharedPreferences
  static Future<UserSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserSettings(
      ftp: prefs.getInt(_keyFtp) ?? 200,
      weight: prefs.getDouble(_keyWeight) ?? 70.0,
      totalGears: prefs.getInt(_keyTotalGears) ?? 22,
      keepScreenOn: prefs.getBool(_keyKeepScreenOn) ?? true,
      defaultMode: prefs.getString(_keyDefaultMode) ?? 'sim',
      lastDeviceId: prefs.getString(_keyLastDeviceId),
      userName: prefs.getString(_keyUserName),
    );
  }

  /// Save settings to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFtp, ftp);
    await prefs.setDouble(_keyWeight, weight);
    await prefs.setInt(_keyTotalGears, totalGears);
    await prefs.setBool(_keyKeepScreenOn, keepScreenOn);
    await prefs.setString(_keyDefaultMode, defaultMode);
    if (lastDeviceId != null) {
      await prefs.setString(_keyLastDeviceId, lastDeviceId!);
    } else {
      await prefs.remove(_keyLastDeviceId);
    }
    if (userName != null) {
      await prefs.setString(_keyUserName, userName!);
    } else {
      await prefs.remove(_keyUserName);
    }
  }

  UserSettings copyWith({
    int? ftp,
    double? weight,
    int? totalGears,
    bool? keepScreenOn,
    String? defaultMode,
    String? lastDeviceId,
    String? userName,
  }) {
    return UserSettings(
      ftp: ftp ?? this.ftp,
      weight: weight ?? this.weight,
      totalGears: totalGears ?? this.totalGears,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      defaultMode: defaultMode ?? this.defaultMode,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      userName: userName ?? this.userName,
    );
  }

  @override
  List<Object?> get props => [
        ftp,
        weight,
        totalGears,
        keepScreenOn,
        defaultMode,
        lastDeviceId,
        userName,
      ];
}
