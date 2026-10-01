import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/presentation/providers/settings_providers.dart';

/// Centralized sound service for playing subtle, responsive interaction sound effects.
///
/// Uses local bundled audio assets, respects system silent/vibrate settings,
/// operates with non-stealing ambient audio focus so background media is undisturbed,
/// and observes user sound preferences (enabled toggle & volume slider).
class SoundService {
  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  SoundService(this._ref) {
    _initAudioContext();
  }

  Future<void> _initAudioContext() async {
    if (_initialized) return;
    try {
      // Configure audio context to be ambient / sonification so it does NOT steal audio focus
      final audioContext = AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {},
        ),
      );
      AudioPlayer.global.setAudioContext(audioContext);
      _player.setReleaseMode(ReleaseMode.stop);
      _initialized = true;
    } catch (e) {
      debugPrint('SoundService: Failed to set audio context: $e');
    }
  }

  bool get isSoundEnabled {
    try {
      return _ref.read(soundEnabledProvider);
    } catch (_) {
      return true;
    }
  }

  double get volume {
    try {
      return _ref.read(soundVolumeProvider).clamp(0.0, 1.0);
    } catch (_) {
      return 0.8;
    }
  }

  Future<void> _playSound(String assetPath) async {
    if (!isSoundEnabled) return;
    try {
      await _initAudioContext();
      await _player.setVolume(volume);
      // Play local asset source (AssetSource looks inside assets/ directory)
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('SoundService: Playback error for $assetPath: $e');
    }
  }

  /// Subtle click/tap sound for buttons and chips.
  Future<void> playButton() async {
    await _playSound('sounds/button_tap.wav');
  }

  /// Short satisfying confirmation tone for adding an expense.
  Future<void> playExpenseAdded() async {
    await _playSound('sounds/expense_added.wav');
  }

  /// Positive ascending confirmation tone for adding income.
  Future<void> playIncomeAdded() async {
    await _playSound('sounds/income_added.wav');
  }

  /// Distinctive pleasant tone when screenshot import completes.
  Future<void> playImportComplete() async {
    await _playSound('sounds/import_complete.wav');
  }

  /// Subtle confirmation sound when approving a transaction.
  Future<void> playTransactionImported() async {
    await _playSound('sounds/transaction_imported.wav');
  }

  /// Soft low double-tone for errors.
  Future<void> playError() async {
    await _playSound('sounds/error.wav');
  }

  void dispose() {
    _player.dispose();
  }
}

/// Riverpod provider for the application [SoundService].
final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
