import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_desktop_app/screens/hr/hr_shell.dart';
import 'package:my_desktop_app/features/accounting/presentation/accounting_shell.dart';
import '../../core/app_modules.dart';
import '../../cubits/catalog/catalog_cubit.dart';
import '../../cubits/pos_settings/pos_settings_cubit.dart';
import '../../cubits/session/session_cubit.dart';
import '../../cubits/sync/sync_cubit.dart';
import '../../features/auth/presentation/widgets/start_shift_dialog.dart';
import '../../features/meal_sales/presentation/screens/meal_sales_screen.dart';
import '../../models/user_profile.dart';
import '../inventory/cubit/inventory_cubit.dart';
import '../inventory/inventory_screen.dart';

/// التحقق من الاتصال بالإنترنت
Future<bool> _isOnline() async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) =>
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.mobile);
}

/// عرض dialog عند انقطاع الإنترنت لأقسام الإدارة
Future<void> _showOfflineDialog(BuildContext context, AppModule module) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.orange),
          const SizedBox(width: 8),
          const Text('لا يوجد اتصال بالإنترنت'),
        ],
      ),
      content: Text(
        'قسم "${module.arabicName}" يتطلب اتصالاً بالإنترنت.\n'
        'تحقق من الاتصال وحاول مجدداً.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

Future<void> startAndOpenModule(
  BuildContext context,
  AppModule module,
  UserProfile profile, {
  bool replace = false,
}) async {
  // ── فحص الإنترنت لأقسام الإدارة (غير الكاشير) ──────────────────────────
  // الكاشير يعمل offline — لا حاجة للفحص
  if (module != AppModule.cashier) {
    final online = await _isOnline();
    if (!context.mounted) return;
    if (!online) {
      await _showOfflineDialog(context, module);
      return;
    }
  }

  // فعّل المزامنة للمستخدم الحالي قبل فتح أي قسم. بذلك تُرسل كل المستندات
  // المحلية فوراً عند وجود اتصال، بدلاً من بقائها pending حتى محاولة لاحقة.
  await context.read<SyncCubit>().onLogin(profile.userId);
  if (!context.mounted) return;

  final sessionCubit = context.read<SessionCubit>();
  if (module == AppModule.cashier) {
    await sessionCubit.restoreCashierSession(
      userId: profile.userId,
      email: profile.email,
      fullName: profile.fullName,
      role: profile.role,
    );
    if (!context.mounted) return;
  }
  if (sessionCubit.hasModuleSession(module)) {
    sessionCubit.resume(
      userId: profile.userId,
      email: profile.email,
      fullName: profile.fullName,
      role: profile.role,
      module: module,
    );
    if (!context.mounted) return;
    prepareModule(context, module);
    final route = MaterialPageRoute<void>(
      builder: (_) => _moduleScreen(module),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
    return;
  }
  final start = await StartShiftDialog.show(context, module, profile);
  if (!context.mounted || start == null) return;
  await context.read<SessionCubit>().start(
    userId: profile.userId,
    email: profile.email,
    fullName: profile.fullName,
    role: profile.role,
    module: module,
    shift: start.shift,
    selectedBranch: profile.role == AppRole.cashier ? null : start.branch,
    cashierBranch: profile.role == AppRole.cashier ? start.branch : null,
    openingCash: start.openingCash,
  );
  if (!context.mounted) return;
  prepareModule(context, module);
  final route = MaterialPageRoute<void>(builder: (_) => _moduleScreen(module));
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

Widget _moduleScreen(AppModule module) {
  return switch (module) {
    AppModule.cashier   => const MealSalesScreen(),
    AppModule.inventory => const InventoryScreen(),
    AppModule.accounts  => const AccountingShell(),
    AppModule.hr        => const HrShell(),
  };
}

void prepareModule(BuildContext context, AppModule module) {
  if (module == AppModule.cashier) {
    // شاشة طلبات المخزون ضمن نقطة البيع تعتمد على نفس كتالوج المخزون.
    // يبدأ التحميل مرة واحدة فقط داخل InventoryCubit، لذا لن يعيد المزامنة
    // عند الرجوع إلى نقطة البيع في نفس الجلسة.
    context.read<InventoryCubit>().initModule();
    context.read<CatalogCubit>().load();
    context.read<PosSettingsCubit>().load();
  }
}
