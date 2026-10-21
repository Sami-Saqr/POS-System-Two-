import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app_modules.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../cubits/auth/auth_cubit.dart';
import '../../../../cubits/auth/auth_state.dart';
import '../../../../cubits/branches/branches_cubit.dart';
import '../../../../cubits/session/session_cubit.dart';
import '../../../../screens/home/module_launcher.dart';
import '../../../../screens/home/modules_screen.dart';
import '../widgets/login_card.dart';
import '../widgets/login_footer.dart';
import '../widgets/login_status_strip.dart';
import '../widgets/login_title_bar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty)
      return;
    await context.read<AuthCubit>().signIn(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    _passwordController.clear();
  }

  Future<void> _continueAfterLogin() async {
    var profile = context.read<AuthCubit>().state.profile;
    if (profile == null) return;
    if (profile.role == AppRole.cashier) {
      final branchesCubit = context.read<BranchesCubit>();
      await branchesCubit.load();
      if (!mounted) return;
      final branchesState = branchesCubit.state;
      if (branchesState.status == BranchesStatus.loaded) {
        final matches = branchesState.branches
            .where((item) => item.id == profile!.branchId)
            .toList();
        if (matches.isEmpty) {
          await context.read<AuthCubit>().block(
            'الفرع المرتبط بحسابك غير نشط، تواصل مع الإدارة',
          );
          return;
        }
        profile = await context.read<AuthCubit>().cacheCashierBranch(
          matches.single,
        );
        if (!mounted) return;
      } else if (profile.branchName == null || profile.branchCode == null) {
        await context.read<AuthCubit>().block(
          'تعذر تحميل بيانات الفرع، تواصل مع الإدارة',
        );
        return;
      }
    }
    if (profile == null) return;
    final modules = allowedModules(profile.role);
    if (modules.length == 1) {
      await startAndOpenModule(context, modules.single, profile, replace: true);
      if (mounted && !context.read<SessionCubit>().state.isActive) {
        await context.read<AuthCubit>().signOut();
      }
      return;
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ModulesScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const _BackgroundGradient(),
            BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state.status == AuthStatus.roleResolved)
                  _continueAfterLogin();
              },
              builder: (context, state) {
                final loading = state.status == AuthStatus.loading;
                final error =
                    state.status == AuthStatus.error ||
                        state.status == AuthStatus.blocked
                    ? state.message
                    : null;
                return Column(
                  children: [
                    const LoginTitleBar(),
                    const LoginStatusStrip(),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppDimens.spaceMd,
                            vertical: AppDimens.spaceLg,
                          ),
                          child: LoginCard(
                            emailController: _emailController,
                            passwordController: _passwordController,
                            emailFocus: _emailFocus,
                            passwordFocus: _passwordFocus,
                            onSubmit: _submit,
                            loading: loading,
                            error: error,
                          ),
                        ),
                      ),
                    ),
                    const LoginFooter(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundGradient extends StatelessWidget {
  const _BackgroundGradient();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryContainer.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.tertiary.withValues(alpha: 0.06),
                    Colors.transparent,
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
