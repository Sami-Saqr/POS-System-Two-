import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/pos_settings_repository.dart';

// ── PosSettingsStatus ──────────────────────────────────────────────────────────

/// حالات تحميل إعدادات نقطة البيع
enum PosSettingsStatus {
  /// لم يبدأ أي تحميل بعد
  initial,

  /// تم التحميل بنجاح
  loaded,

  /// فشل التحميل ولا يوجد كاش محلي
  failure,
}

// ── State ──────────────────────────────────────────────────────────────────────

/// حالة PosSettingsCubit — على مستوى التطبيق
class PosSettingsState extends Equatable {
  /// نسبة الضريبة المحمّلة من Supabase (أو الكاش)
  final double defaultVatRate;

  /// نسبة الضريبة المطبّقة حالياً (قابلة للتعديل مؤقتاً بإذن المدير)
  final double currentVatRate;

  /// حالة التحميل
  final PosSettingsStatus status;

  /// رسالة الخطأ لو status == failure
  final String? errorMessage;

  const PosSettingsState({
    this.defaultVatRate = 0.0,
    this.currentVatRate = 0.0,
    this.status = PosSettingsStatus.initial,
    this.errorMessage,
  });

  /// هل تم تعديل النسبة عن القيمة المحمّلة؟
  bool get isOverridden => currentVatRate != defaultVatRate;

  PosSettingsState copyWith({
    double? defaultVatRate,
    double? currentVatRate,
    PosSettingsStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PosSettingsState(
      defaultVatRate: defaultVatRate ?? this.defaultVatRate,
      currentVatRate: currentVatRate ?? this.currentVatRate,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    defaultVatRate,
    currentVatRate,
    status,
    errorMessage,
  ];
}

// ── Cubit ──────────────────────────────────────────────────────────────────────

/// Cubit إعدادات نقطة البيع — على مستوى التطبيق
///
/// يُحمَّل مرة واحدة فقط بعد تسجيل الدخول.
/// لو الحالة [PosSettingsStatus.loaded]: لا يُعيد الجلب أبداً.
/// تعديل [currentVatRate] يظل في الجلسة فقط — لا يُكتب في Supabase.
class PosSettingsCubit extends Cubit<PosSettingsState> {
  final PosSettingsRepository _repository;

  /// علم لمنع التحميل المتزامن
  bool _isLoading = false;

  PosSettingsCubit({PosSettingsRepository? repository})
    : _repository = repository ?? PosSettingsRepository(),
      super(const PosSettingsState());

  /// يجلب نسبة الضريبة من السيرفر (أو الكاش عند انقطاع الشبكة).
  ///
  /// - لو الحالة [loaded]: ارجع فوراً بدون طلب.
  /// - لو الجلب جارٍ (_isLoading): ارجع فوراً.
  /// - نجاح: [status = loaded]، defaultVatRate = currentVatRate = القيمة المحمّلة.
  /// - فشل مع كاش: [status = loaded] بالقيمة المخزنة.
  /// - فشل بدون كاش: [status = failure] مع رسالة خطأ.
  Future<void> load() async {
    // لو محمّلة بالفعل: لا تُعيد الجلب
    if (state.status == PosSettingsStatus.loaded) return;

    // حماية من التشغيل المتزامن
    if (_isLoading) return;
    _isLoading = true;

    try {
      final rate = await _repository.fetchVatRate();

      if (!isClosed) {
        emit(
          PosSettingsState(
            defaultVatRate: rate,
            currentVatRate: rate,
            status: PosSettingsStatus.loaded,
          ),
        );
      }
    } on VatRateCacheMissException catch (_) {
      // لا يوجد كاش ولا اتصال بالإنترنت
      if (!isClosed) {
        emit(
          PosSettingsState(
            defaultVatRate: 0.0,
            currentVatRate: 0.0,
            status: PosSettingsStatus.failure,
            errorMessage: 'تعذر تحميل نسبة الضريبة',
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          PosSettingsState(
            defaultVatRate: 0.0,
            currentVatRate: 0.0,
            status: PosSettingsStatus.failure,
            errorMessage: 'تعذر تحميل نسبة الضريبة',
          ),
        );
      }
    } finally {
      _isLoading = false;
    }
  }

  /// إعادة المحاولة (يُستدعى من زر "إعادة المحاولة" فقط)
  Future<void> retry() async {
    // السماح بإعادة المحاولة حتى لو status = failure
    if (state.status == PosSettingsStatus.loaded) return;

    // أعد تهيئة العلم
    _isLoading = false;
    await load();
  }

  /// تعديل نسبة الضريبة للجلسة الحالية فقط (بعد إذن المدير)
  /// لا يكتب في Supabase.
  /// [rate] يجب أن تكون بين 0 و 100.
  void overrideCurrentVatRate(double rate) {
    assert(rate >= 0 && rate <= 100, 'نسبة الضريبة يجب أن تكون بين 0 و 100');
    if (isClosed) return;
    emit(state.copyWith(currentVatRate: rate));
  }

  /// استعادة نسبة الضريبة الافتراضية (المحمّلة) — بدون باسورد
  void resetToDefault() {
    if (isClosed) return;
    emit(state.copyWith(currentVatRate: state.defaultVatRate));
  }

  /// إعادة ضبط الكل عند تسجيل الخروج أو إقفال الوردية
  void reset() {
    if (isClosed) return;
    emit(const PosSettingsState());
  }
}
