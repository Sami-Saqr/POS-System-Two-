import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/supabase_config.dart';
import 'core/supabase_client.dart';
import 'core/theme/app_colors.dart';
import 'core/cubits/held_orders_cubit.dart';
import 'cubits/branches/branches_cubit.dart';
import 'cubits/catalog/catalog_cubit.dart';
import 'cubits/pos_settings/pos_settings_cubit.dart';
import 'cubits/sales/sales_cubit.dart';
import 'cubits/session/session_cubit.dart';
import 'cubits/sync/sync_cubit.dart';
import 'cubits/admin_access/admin_access_cubit.dart';
import 'cubits/auth/auth_cubit.dart';
import 'core/repositories/admin_access_repository.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'repositories/pos_settings_repository.dart';
import 'repositories/sales_repository.dart';
import 'data/inventory/inventory_api.dart';
import 'data/inventory/inventory_sync.dart';
import 'screens/inventory/cubit/inventory_cubit.dart';
import 'cubits/notifications/notifications_cubit.dart';
import 'core/widgets/global_notification_overlay.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  // Initialize FFI for Windows desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey, // ignore: deprecated_member_use
  );

  // عند كل تشغيل: أزل أي جلسة Supabase قديمة محفوظة محلياً
  // حتى يختار الكاشير الفرع والوردية في كل مرة
  await supabase.auth.signOut(scope: SignOutScope.local);

  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1024, 768),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HeldOrdersCubit()),
        BlocProvider(create: (_) => AuthCubit()),
        // CatalogCubit على مستوى التطبيق — يبقى حياً طوال الجلسة
        BlocProvider(create: (_) => CatalogCubit()),
        // BranchesCubit — يُحمَّل مرة واحدة ويبقى طوال الجلسة
        BlocProvider(create: (_) => BranchesCubit()),
        // SessionCubit — بيانات الجلسة الثابتة بعد تسجيل الدخول
        BlocProvider(create: (_) => SessionCubit()),
        // PosSettingsCubit — إعدادات نقطة البيع (نسبة الضريبة)
        // تُحمَّل مرة واحدة بعد تسجيل الدخول وتظل طوال الجلسة
        BlocProvider(
          create: (_) => PosSettingsCubit(repository: PosSettingsRepository()),
        ),
        // SalesCubit — لإتمام المبيعات وحفظها
        BlocProvider(create: (_) => SalesCubit(SalesRepository())),
        // SyncCubit — مزامنة الخلفية
        BlocProvider(create: (_) => SyncCubit()),
        // AdminAccessCubit — التحقق من باسورد الإدارة
        BlocProvider(create: (_) => AdminAccessCubit(AdminAccessRepository())),
        // NotificationsCubit — نظام الإشعارات المشترك لجميع الأقسام
        BlocProvider(create: (_) => NotificationsCubit()),
        // InventoryCubit — وحدة المخزون، حياة طوال الجلسة
        BlocProvider(
          create: (_) {
            final client = supabase;
            // InventorySync يجلب من السيرفر مباشرة (بدون SQLite cache)
            return InventoryCubit(
              InventoryApi(client),
              InventorySync(client),
            );
          },
          lazy: true, // لا يُنشَأ حتى أول استخدام
        ),
      ],
      child: const DietKingApp(),
    ),
  );
}

class DietKingApp extends StatelessWidget {
  const DietKingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دايت كنج POS — تسجيل دخول',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      builder: (context, child) {
        return GlobalNotificationOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surface,
          primary: AppColors.primary,
          primaryContainer: AppColors.primaryContainer,
          tertiary: AppColors.tertiary,
          onSurface: AppColors.onSurface,
          outline: AppColors.outlineVariant,
        ),
        textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
