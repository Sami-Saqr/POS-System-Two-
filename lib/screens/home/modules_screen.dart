import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_modules.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../cubits/auth/auth_cubit.dart';
import 'module_launcher.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  bool _isNavigating = false;

  Future<void> _open(AppModule module) async {
    if (_isNavigating) return;
    final profile = context.read<AuthCubit>().state.profile;
    if (profile == null) return;
    if (!allowedModules(profile.role).contains(module)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية لهذا القسم')),
      );
      return;
    }
    setState(() => _isNavigating = true);
    await startAndOpenModule(context, module, profile);
    if (mounted) setState(() => _isNavigating = false);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.select((AuthCubit cubit) => cubit.state.profile?.role);
    final modules = role == null ? const <AppModule>[] : allowedModules(role);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppDimens.spaceLg),
            child: Column(
              children: [
                Text(
                  'اختر القسم',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXxl,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXxl),
                Wrap(
                  spacing: AppDimens.spaceLg,
                  runSpacing: AppDimens.spaceLg,
                  alignment: WrapAlignment.center,
                  children: AppModule.values
                      .map(
                        (module) => _ModuleCard(
                          key: ValueKey(module),
                          module: module,
                          unlocked: modules.contains(module),
                          onTap: () => _open(module),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    super.key,
    required this.module,
    required this.unlocked,
    required this.onTap,
  });

  final AppModule module;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap();
            return null;
          },
        ),
      },
      child: InkWell(
        onTap: unlocked
            ? onTap
            : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ليس لديك صلاحية لهذا القسم')),
              ),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Opacity(
          opacity: unlocked ? 1 : .45,
          child: Container(
            width: 170,
            height: 150,
            padding: const EdgeInsetsDirectional.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(module.icon, color: AppColors.primary, size: 36),
                      const SizedBox(height: AppDimens.spaceMd),
                      Text(module.arabicName),
                    ],
                  ),
                ),
                if (!unlocked)
                  const PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: Icon(Icons.lock_outline),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
