import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../inventory_constants.dart';
import '../models/enums.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import 'package:my_desktop_app/cubits/auth/auth_cubit.dart';
import 'package:my_desktop_app/cubits/session/session_cubit.dart';
import 'package:my_desktop_app/features/auth/presentation/screens/login_screen.dart';
import '../../../../core/widgets/notification_bell.dart';

class InventorySidebar extends StatelessWidget {
  const InventorySidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: InventoryDimens.sidebarWidth,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: BorderDirectional(
          end: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Divider(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
            height: 1,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Expanded(
            child: BlocBuilder<InventoryCubit, InventoryState>(
              builder: (context, state) {
                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                  ),
                  children: [
                    _SidebarItem(
                      section: InventorySection.rawMaterials,
                      isActive: state.section == InventorySection.rawMaterials,
                    ),
                    _SidebarItem(
                      section: InventorySection.supplyRequests,
                      isActive:
                          state.section == InventorySection.supplyRequests,
                    ),
                    _SidebarItem(
                      section: InventorySection.stockAudit,
                      isActive: state.section == InventorySection.stockAudit,
                    ),
                    _SidebarItem(
                      section: InventorySection.kitchenIssue,
                      isActive: state.section == InventorySection.kitchenIssue,
                    ),
                    _SidebarItem(
                      section: InventorySection.kitchenReceipts,
                      isActive:
                          state.section == InventorySection.kitchenReceipts,
                    ),
                    _SidebarItem(
                      section: InventorySection.branchOrders,
                      isActive: state.section == InventorySection.branchOrders,
                    ),
                    _SidebarItem(
                      section: InventorySection.administration,
                      isActive:
                          state.section == InventorySection.administration,
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: _SidebarItem.action(
              label: 'تسجيل الخروج',
              icon: Icons.logout_rounded,
              onTap: () => _signOut(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await context.read<InventoryCubit>().clearSession();
    if (!context.mounted) return;

    await context.read<AuthCubit>().signOut();
    if (!context.mounted) return;

    context.read<SessionCubit>().clearMemory();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'دايت كينج ERP',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  'إدارة سلاسل الإمداد والمخزون',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const NotificationBell(),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final InventorySection? section;
  final String? label;
  final IconData? icon;
  final bool isActive;
  final VoidCallback? onTap;

  const _SidebarItem({
    this.section,
    this.isActive = false,
  }) : onTap = null,
       icon = null,
       label = null;

  const _SidebarItem.action({
    required this.label,
    required this.icon,
    required this.onTap,
  }) : section = null,
       isActive = false;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.section?.label ?? widget.label ?? '';
    final iconData = widget.section?.icon ?? widget.icon ?? Icons.error;

    return FocusableActionDetector(
      onShowHoverHighlight: (v) => setState(() => _isHovered = v),
      onShowFocusHighlight: (v) => setState(() => _isFocused = v),
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            _handleTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: AppDimens.spaceXs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceMd,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.primaryContainer
                : (_isHovered || _isFocused)
                ? AppColors.surfaceContainerHigh
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: Row(
            children: [
              Icon(
                iconData,
                color: widget.isActive
                    ? AppColors.onPrimaryContainer
                    : AppColors.onSurfaceVariant,
                size: AppDimens.iconMd,
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontMd,
                    fontWeight: widget.isActive
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: widget.isActive
                        ? AppColors.onPrimaryContainer
                        : AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else if (widget.section != null) {
      context.read<InventoryCubit>().selectSection(widget.section!);
    }
  }
}
