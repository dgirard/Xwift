import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_settings.dart';

/// Provider for user settings
final userSettingsProvider =
    StateNotifierProvider<UserSettingsNotifier, AsyncValue<UserSettings>>((ref) {
  return UserSettingsNotifier();
});

/// Notifier for user settings
class UserSettingsNotifier extends StateNotifier<AsyncValue<UserSettings>> {
  UserSettingsNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final settings = await UserSettings.load();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update user settings
  Future<void> update(UserSettings newSettings) async {
    await newSettings.save();
    state = AsyncValue.data(newSettings);
  }

  /// Update a single field
  Future<void> updateUserName(String? name) async {
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.copyWith(userName: name);
      await update(updated);
    }
  }

  /// Update FTP
  Future<void> updateFtp(int ftp) async {
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.copyWith(ftp: ftp);
      await update(updated);
    }
  }

  /// Update weight
  Future<void> updateWeight(double weight) async {
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.copyWith(weight: weight);
      await update(updated);
    }
  }

  /// Reload settings from storage
  Future<void> reload() => _load();
}
