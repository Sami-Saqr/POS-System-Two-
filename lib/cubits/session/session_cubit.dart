import 'dart:convert';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/app_modules.dart';
import '../../core/local_db.dart';
import '../../models/login_branch.dart';

class SessionState extends Equatable {
  final bool isActive;
  final String userId;
  final String email;
  final String cashierName;
  final String? branchId;
  final String branchName;
  final String branchCode;
  final String shift;
  final String sessionId;
  final DateTime? startedAt;
  final AppRole? role;
  final AppModule? module;
  final double openingCash;

  const SessionState({
    this.isActive = false,
    this.userId = '',
    this.email = '',
    this.cashierName = '',
    this.branchId,
    this.branchName = '',
    this.branchCode = '',
    this.shift = '',
    this.sessionId = '',
    this.startedAt,
    this.role,
    this.module,
    this.openingCash = 0,
  });

  @override
  List<Object?> get props => [
    isActive,
    userId,
    email,
    cashierName,
    branchId,
    branchName,
    branchCode,
    shift,
    sessionId,
    startedAt,
    role,
    module,
    openingCash,
  ];
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit() : super(const SessionState());

  final Map<AppModule, _ModuleSession> _moduleSessions = {};

  static String _cashierSessionKey(String userId) =>
      'active_cashier_session_$userId';

  bool hasModuleSession(AppModule module) =>
      _moduleSessions.containsKey(module);

  /// يستعيد وردية الكاشير المفتوحة بعد إعادة تشغيل البرنامج.
  /// الجلسة مرتبطة بمعرّف المستخدم، لذلك لا يمكن لمستخدم آخر استعادتها.
  Future<bool> restoreCashierSession({
    required String userId,
    required String email,
    required String fullName,
    required AppRole role,
  }) async {
    if (role != AppRole.cashier || hasModuleSession(AppModule.cashier)) {
      return hasModuleSession(AppModule.cashier);
    }

    try {
      final database = await LocalDb.db;
      final rows = await database.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: [_cashierSessionKey(userId)],
        limit: 1,
      );
      if (rows.isEmpty) return false;

      final raw = rows.single['value'] as String;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final branchId = data['branch_id'] as String?;
      final branchName = data['branch_name'] as String?;
      final branchCode = data['branch_code'] as String?;
      final shift = data['shift'] as String?;
      final sessionId = data['session_id'] as String?;
      final startedAtRaw = data['started_at'] as String?;
      final openingCash = (data['opening_cash'] as num?)?.toDouble();

      if (branchId == null ||
          branchName == null ||
          branchCode == null ||
          shift == null ||
          shift.isEmpty ||
          sessionId == null ||
          sessionId.isEmpty ||
          startedAtRaw == null ||
          openingCash == null) {
        return false;
      }

      final startedAt = DateTime.tryParse(startedAtRaw)?.toLocal();
      if (startedAt == null) return false;

      _moduleSessions[AppModule.cashier] = _ModuleSession(
        shift: shift,
        branch: LoginBranch(id: branchId, name: branchName, code: branchCode),
        openingCash: openingCash,
        sessionId: sessionId,
        startedAt: startedAt,
      );
      resume(
        userId: userId,
        email: email,
        fullName: fullName,
        role: role,
        module: AppModule.cashier,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void resume({
    required String userId,
    required String email,
    required String fullName,
    required AppRole role,
    required AppModule module,
  }) {
    final existing = _moduleSessions[module];
    if (existing == null) return;
    emit(
      SessionState(
        isActive: true,
        userId: userId,
        email: email,
        cashierName: fullName.isEmpty ? email.split('@').first : fullName,
        branchId: existing.branch?.id,
        branchName: existing.branch?.name ?? 'إدارة',
        branchCode: existing.branch?.code ?? '',
        shift: existing.shift,
        sessionId: existing.sessionId,
        startedAt: existing.startedAt,
        role: role,
        module: module,
        openingCash: existing.openingCash,
      ),
    );
  }

  Future<void> start({
    required String userId,
    required String email,
    required String fullName,
    required AppRole role,
    required AppModule module,
    required String shift,
    LoginBranch? selectedBranch,
    LoginBranch? cashierBranch,
    double openingCash = 0,
  }) async {
    if (hasModuleSession(module)) {
      resume(
        userId: userId,
        email: email,
        fullName: fullName,
        role: role,
        module: module,
      );
      return;
    }
    final branch = role == AppRole.cashier ? cashierBranch : selectedBranch;
    if (role == AppRole.cashier && branch == null) {
      throw StateError('حساب الكاشير غير مرتبط بفرع صالح');
    }
    final moduleSession = _ModuleSession(
      shift: shift,
      branch: branch,
      openingCash: openingCash,
      sessionId: _generateUuidV4(),
      startedAt: DateTime.now(),
    );
    _moduleSessions[module] = moduleSession;
    emit(
      SessionState(
        isActive: true,
        userId: userId,
        email: email,
        cashierName: fullName.isEmpty ? email.split('@').first : fullName,
        branchId: moduleSession.branch?.id,
        branchName: moduleSession.branch?.name ?? 'إدارة',
        branchCode: moduleSession.branch?.code ?? '',
        shift: moduleSession.shift,
        sessionId: moduleSession.sessionId,
        startedAt: moduleSession.startedAt,
        role: role,
        module: module,
        openingCash: moduleSession.openingCash,
      ),
    );

    if (module == AppModule.cashier) {
      await _persistCashierSession(userId, moduleSession);
    }
  }

  /// يمسح حالة الواجهة فقط، مع إبقاء الوردية المفتوحة محفوظة للاستعادة.
  void clearMemory() {
    _moduleSessions.clear();
    emit(const SessionState());
  }

  /// يُستدعى فقط بعد إقفال الوردية؛ عندها تصبح الوردية غير قابلة للاستعادة.
  Future<void> end() async {
    final userId = state.userId;
    if (userId.isNotEmpty) {
      final database = await LocalDb.db;
      await database.delete(
        'app_meta',
        where: 'key = ?',
        whereArgs: [_cashierSessionKey(userId)],
      );
    }
    clearMemory();
  }

  Future<void> _persistCashierSession(
    String userId,
    _ModuleSession session,
  ) async {
    final branch = session.branch;
    if (branch == null) {
      throw StateError('لا يمكن حفظ وردية كاشير بدون فرع');
    }
    final database = await LocalDb.db;
    await database.insert('app_meta', {
      'key': _cashierSessionKey(userId),
      'value': jsonEncode({
        'branch_id': branch.id,
        'branch_name': branch.name,
        'branch_code': branch.code,
        'shift': session.shift,
        'session_id': session.sessionId,
        'started_at': session.startedAt.toUtc().toIso8601String(),
        'opening_cash': session.openingCash,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10, 16).join()}';
  }
}

class _ModuleSession {
  const _ModuleSession({
    required this.shift,
    required this.branch,
    required this.openingCash,
    required this.sessionId,
    required this.startedAt,
  });

  final String shift;
  final LoginBranch? branch;
  final double openingCash;
  final String sessionId;
  final DateTime startedAt;
}
