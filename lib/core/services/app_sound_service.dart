import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

/// خدمة تشغيل المؤثرات الصوتية للإشعارات عبر النظام
class AppSoundService {
  AppSoundService._();

  /// المسار المعتمد لصوت إشعار دايت كينج
  static const String customNotificationAssetPath =
      'assets/sounds/diet_king_notification.wav';

  static DynamicLibrary? _winmm;
  static int Function(Pointer<Utf16>, int, int)? _playSoundW;
  static DynamicLibrary? _user32;
  static int Function(int)? _messageBeep;
  static String? _resolvedWavPath;

  static void _initNativeAudio() {
    if (!Platform.isWindows) return;
    try {
      _winmm ??= DynamicLibrary.open('winmm.dll');
      _playSoundW ??= _winmm!.lookupFunction<
          Int32 Function(Pointer<Utf16>, IntPtr, Uint32),
          int Function(Pointer<Utf16>, int, int)>('PlaySoundW');
    } catch (_) {}

    try {
      _user32 ??= DynamicLibrary.open('user32.dll');
      _messageBeep ??= _user32!.lookupFunction<
          Int32 Function(Uint32),
          int Function(int)>('MessageBeep');
    } catch (_) {}
  }

  /// تحديد المسار الفعلي لملف الصوت على القرص الصلب
  static String? _resolveSoundFile() {
    if (_resolvedWavPath != null && File(_resolvedWavPath!).existsSync()) {
      return _resolvedWavPath;
    }

    final candidatePaths = [
      customNotificationAssetPath,
      'assets\\sounds\\diet_king_notification.wav',
      '${Directory.current.path}/$customNotificationAssetPath',
      '${Directory.current.path}\\assets\\sounds\\diet_king_notification.wav',
      '${File(Platform.resolvedExecutable).parent.path}/data/flutter_assets/$customNotificationAssetPath',
    ];

    for (final p in candidatePaths) {
      final f = File(p);
      if (f.existsSync()) {
        _resolvedWavPath = f.absolute.path;
        return _resolvedWavPath;
      }
    }
    return null;
  }

  /// تشغيل صوت إشعار دايت كينج المعتمد (diet_king_notification.wav)
  static void playNotificationSound() {
    // 1. تنبيه عبر نظام فلاتر
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    // 2. تشغيل ملف الصوت المخصص diet_king_notification.wav عبر WinMM PlaySoundW في ويندوز
    if (Platform.isWindows) {
      try {
        _initNativeAudio();
        final wavPath = _resolveSoundFile();

        if (wavPath != null && _playSoundW != null) {
          final pathPtr = wavPath.toNativeUtf16();
          // 0x00020001 = SND_FILENAME (0x20000) | SND_ASYNC (0x1) | SND_NODEFAULT (0x2)
          _playSoundW!(pathPtr, 0, 0x00020003);
          malloc.free(pathPtr);
          return;
        }

        // في حال تعذر العثور على الملف، يتم الرجوع لنغمة النظام التنبيهية كاحتياط
        if (_messageBeep != null) {
          _messageBeep!(0x00000040);
        }
      } catch (_) {}
    }
  }

  /// تشغيل أي مسار ملف صوتي مخصص بصيغة .wav
  static void playCustomWav(String wavFilePath) {
    if (Platform.isWindows) {
      try {
        _initNativeAudio();
        final file = File(wavFilePath);
        if (file.existsSync() && _playSoundW != null) {
          final pathPtr = file.absolute.path.toNativeUtf16();
          _playSoundW!(pathPtr, 0, 0x00020003);
          malloc.free(pathPtr);
          return;
        }
      } catch (_) {}
    }
    playNotificationSound();
  }
}
