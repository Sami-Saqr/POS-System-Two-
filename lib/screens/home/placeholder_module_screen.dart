import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_modules.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../cubits/session/session_cubit.dart';

class PlaceholderModuleScreen extends StatelessWidget {
  const PlaceholderModuleScreen({super.key, required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(module.arabicName)),
        body: Center(
          child: Container(
            padding: const EdgeInsetsDirectional.all(AppDimens.spaceXl),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(module.icon, size: 48, color: AppColors.primary),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  module.arabicName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text('الوردية: ${session.shift}'),
                const Text('إداري'),
                const SizedBox(height: AppDimens.spaceMd),
                const Text('قيد التطوير'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
