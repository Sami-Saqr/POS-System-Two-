import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../cubits/auth/auth_cubit.dart';
import '../../../../cubits/auth/auth_state.dart';
import 'package:my_desktop_app/cubits/session/session_cubit.dart';
import 'package:my_desktop_app/cubits/sync/sync_cubit.dart';
import 'package:my_desktop_app/features/auth/presentation/screens/login_screen.dart';
import '../data/accounting_repository.dart';
import 'screens/accounting_dashboard_screen.dart';
import 'screens/sales_report_screen.dart';
import 'screens/closings_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/purchases_screen.dart';
import 'screens/inventory_overview_screen.dart';
import 'screens/comprehensive_reports_screen.dart';
import 'screens/salaries_screen.dart';
import '../../../../core/widgets/notification_bell.dart';
import 'package:window_manager/window_manager.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AccountingShell — الغلاف الرئيسي لقسم الحسابات مع التنقل بين الصفحات
// ══════════════════════════════════════════════════════════════════════════════

class AccountingShell extends StatefulWidget {
  const AccountingShell({super.key});

  @override
  State<AccountingShell> createState() => _AccountingShellState();
}

class _AccountingShellState extends State<AccountingShell> {
  int _selectedIndex = 0;

  static const List<_NavTab> _tabs = [
    _NavTab(label: 'الرئيسية',   icon: Icons.dashboard_outlined,          activeIcon: Icons.dashboard),
    _NavTab(label: 'المبيعات',   icon: Icons.bar_chart_outlined,           activeIcon: Icons.bar_chart),
    _NavTab(label: 'الإقفالات',  icon: Icons.lock_clock_outlined,          activeIcon: Icons.lock_clock),
    _NavTab(label: 'المصروفات',  icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet),
    _NavTab(label: 'المشتريات',  icon: Icons.shopping_cart_outlined,       activeIcon: Icons.shopping_cart),
    _NavTab(label: 'المخزون',    icon: Icons.inventory_2_outlined,         activeIcon: Icons.inventory_2),
    _NavTab(label: 'التقارير الشاملة', icon: Icons.analytics_outlined,     activeIcon: Icons.analytics),
    _NavTab(label: 'الرواتب',    icon: Icons.people_outline,               activeIcon: Icons.people),
  ];

  late final AccountingRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = AccountingRepository();
  }

  Widget get _currentScreen {
    return switch (_selectedIndex) {
      0 => AccountingDashboardScreen(repo: _repo),
      1 => SalesReportScreen(repo: _repo),
      2 => ClosingsScreen(repo: _repo),
      3 => ExpensesScreen(repo: _repo),
      4 => PurchasesScreen(repo: _repo),
      5 => InventoryOverviewScreen(repo: _repo),
      6 => ComprehensiveReportsScreen(repo: _repo),
      7 => SalariesScreen(repo: _repo),
      _ => AccountingDashboardScreen(repo: _repo),
    };
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من قسم الحسابات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    context.read<SyncCubit>().onLogout();
    context.read<SessionCubit>().clearMemory();
    await context.read<AuthCubit>().signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E14),
        body: Column(
          children: [
            _buildTopBar(),
            _buildNavBar(),
            Expanded(child: _currentScreen),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return DragToMoveArea(
      child: Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0E14),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2430))),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF272A31),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.restaurant_menu_rounded,
                  color: AppColors.primaryContainer,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('DietKing',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryContainer,
                        letterSpacing: -0.5)),
                const SizedBox(width: 4),
                const Icon(Icons.verified_rounded,
                    color: AppColors.primaryContainer, size: 16),
              ]),
              Text('نظام الحسابات المالية والرقابة',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 10, color: const Color(0xFF8A92A3))),
            ],
          ),
          const Spacer(),
          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF191C22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(children: [
              _PulsingDot(color: AppColors.tertiary),
              const SizedBox(width: 6),
              Text('متصل',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tertiary)),
            ]),
          ),
          const SizedBox(width: 16),
          // Date
          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 15, color: Color(0xFF8A92A3)),
            const SizedBox(width: 6),
            Text(_currentDateAr(),
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12, color: const Color(0xFF8A92A3))),
          ]),
          const SizedBox(width: 16),
          // User info
          BlocBuilder<AuthCubit, AuthState>(
            builder: (ctx, state) {
              final name = state.profile?.fullName ?? '—';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF191C22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(name,
                          style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D2026),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('محاسب رئيسي',
                            style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 10,
                                color: AppColors.primaryContainer)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Color(0xFF452B00), size: 18),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(width: 8),
          const NotificationBell(),
          const SizedBox(width: 12),
          Tooltip(
            message: 'تسجيل الخروج',
            child: TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: const Text('تسجيل الخروج'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF7B7B),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 24,
            color: const Color(0xFF1E2430),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WindowBtn(
                icon: Icons.remove_rounded,
                tooltip: 'تصغير',
                onTap: () => windowManager.minimize(),
              ),
              const SizedBox(width: 4),
              _WindowBtn(
                icon: Icons.crop_square_rounded,
                tooltip: 'تكبير / استعادة',
                onTap: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
              ),
              const SizedBox(width: 4),
              _WindowBtn(
                icon: Icons.close_rounded,
                tooltip: 'إغلاق',
                isClose: true,
                onTap: () => windowManager.close(),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  // ── NAV BAR ───────────────────────────────────────────────────────────────────
  Widget _buildNavBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0E14),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2430))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final tab = _tabs[i];
            final active = _selectedIndex == i;
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _selectedIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF382710)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(active ? tab.activeIcon : tab.icon,
                        size: 15,
                        color: active
                            ? AppColors.primaryContainer
                            : const Color(0xFF8A92A3)),
                    const SizedBox(width: 5),
                    Text(tab.label,
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: active ? 13 : 12,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: active
                                ? AppColors.primaryContainer
                                : const Color(0xFF8A92A3))),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── FOOTER ────────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0E14),
        border: Border(top: BorderSide(color: Color(0xFF1E2430))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Diet King © 2026 - نظام الإدارة المالية ونقاط البيع',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 10, color: const Color(0xFF8A92A3))),
          Row(children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: AppColors.tertiary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text('الخادم متزامن',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10, color: const Color(0xFF8A92A3))),
          ]),
        ],
      ),
    );
  }

  String _currentDateAr() {
    final now = DateTime.now();
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

// ── Data classes ───────────────────────────────────────────────────────────────
class _NavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavTab(
      {required this.label, required this.icon, required this.activeIcon});
}

// ── Pulsing dot (reused from dashboard) ──────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration:
            BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _WindowBtn extends StatefulWidget {
  const _WindowBtn({
    required this.icon,
    this.tooltip,
    this.isClose = false,
    this.onTap,
  });

  final IconData icon;
  final String? tooltip;
  final bool isClose;
  final VoidCallback? onTap;

  @override
  State<_WindowBtn> createState() => _WindowBtnState();
}

class _WindowBtnState extends State<_WindowBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.isClose
        ? const Color(0xFFE81123)
        : const Color(0xFF262A35);

    final btn = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 26,
          decoration: BoxDecoration(
            color: _hovered ? hoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            widget.icon,
            size: 15,
            color: widget.isClose && _hovered
                ? Colors.white
                : const Color(0xFF9EABB8),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}
