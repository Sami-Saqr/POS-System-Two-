import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_cubit.dart';
import '../../cubit/inventory_state.dart';
import '../read_error_state.dart';
import 'kitchen_issue_row.dart';

class KitchenIssuesTable extends StatelessWidget {
  const KitchenIssuesTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: BlocBuilder<InventoryCubit, InventoryState>(
              builder: (context, state) {
                if (state.kitchenIssues.isEmpty) {
                  if (state.error != null) {
                    return ReadErrorState(
                      message: state.error!,
                      onRetry: () =>
                          context.read<InventoryCubit>().loadKitchenIssues(),
                    );
                  }
                  return Center(
                    child: Text(
                      'لا توجد صرفيات مطبخ حالياً',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final itemsById = state.catalogItemsById;
                return ListView.builder(
                  itemCount: state.kitchenIssues.length,
                  itemBuilder: (context, index) {
                    final issue = state.kitchenIssues[index];
                    return KitchenIssueRow(
                      key: ValueKey(issue.id),
                      issue: issue,
                      itemsById: itemsById,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'رقم الإذن',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'خطة الطهي',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'الشيف',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'الوردية',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'الخامات والكميات',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'التاريخ',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 40), // Actions or status column
        ],
      ),
    );
  }
}
