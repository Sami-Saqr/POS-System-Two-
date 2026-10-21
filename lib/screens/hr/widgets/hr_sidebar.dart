import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

import '../cubit/hr_cubit.dart';
import '../cubit/hr_state.dart';
import '../models/hr_enums.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart'; // fallback
import '../../../../core/widgets/notification_bell.dart';

class HrSidebar extends StatelessWidget {
  const HrSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.badge,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الموارد البشرية',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontLg,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'HR Admin',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontSm,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const NotificationBell(),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Menu Items ─────────────────────────────────────────
          Expanded(
            child: BlocBuilder<HrCubit, HrState>(
              buildWhen: (previous, current) =>
                  previous.section != current.section,
              builder: (context, state) {
                return ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spaceMd,
                    horizontal: AppDimens.spaceSm,
                  ),
                  children: [
                    _SidebarItem(
                      section: HrSection.employees,
                      icon: Icons.people_alt_outlined,
                      isActive: state.section == HrSection.employees,
                    ),
                    _SidebarItem(
                      section: HrSection.leaveRequests,
                      icon: Icons.beach_access_outlined,
                      isActive: state.section == HrSection.leaveRequests,
                    ),
                    _SidebarItem(
                      section: HrSection.attendanceAbsences,
                      icon: Icons.calendar_today_outlined,
                      isActive: state.section == HrSection.attendanceAbsences,
                    ),
                    _SidebarItem(
                      section: HrSection.deductionsBonuses,
                      icon: Icons.account_balance_wallet_outlined,
                      isActive: state.section == HrSection.deductionsBonuses,
                    ),
                    _SidebarItem(
                      section: HrSection.monthlyReport,
                      icon: Icons.bar_chart_rounded,
                      isActive: state.section == HrSection.monthlyReport,
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),
          // Logout
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: InkWell(
              onTap: () {
                // Typical logout logic
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: AppDimens.iconSm,
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Text(
                      'تسجيل الخروج',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final HrSection section;
  final IconData icon;
  final bool isActive;

  const _SidebarItem({
    required this.section,
    required this.icon,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.read<HrCubit>().setSection(section),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primaryContainer.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(
                color: isActive
                    ? AppColors.primaryContainer.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  size: AppDimens.iconMd,
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Text(
                    section.label,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: isActive ? AppColors.primary : AppColors.onSurface,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: AppDimens.fontMd,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
