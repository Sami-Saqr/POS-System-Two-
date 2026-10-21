import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'cubit/inventory_cubit.dart';
import 'cubit/inventory_state.dart';
import 'models/enums.dart';
import 'sections/raw_materials_section.dart';
import 'sections/supply_requests_section.dart';
import 'sections/stock_audit_section.dart';
import 'sections/kitchen_issue_section.dart';
import 'sections/kitchen_receipts_section.dart';
import 'sections/branch_orders_section.dart';
import 'sections/inventory_admin_section.dart';
import 'widgets/inventory_sidebar.dart';

class InventoryShell extends StatelessWidget {
  const InventoryShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const InventorySidebar(),
        Expanded(
          child: BlocBuilder<InventoryCubit, InventoryState>(
            buildWhen: (previous, current) =>
                previous.section != current.section,
            builder: (context, state) {
              switch (state.section) {
                case InventorySection.rawMaterials:
                  return const RawMaterialsSection();
                case InventorySection.supplyRequests:
                  return const SupplyRequestsSection();
                case InventorySection.stockAudit:
                  return const StockAuditSection();
                case InventorySection.kitchenIssue:
                  return const KitchenIssueSection();
                case InventorySection.kitchenReceipts:
                  return const KitchenReceiptsSection();
                case InventorySection.branchOrders:
                  return const BranchOrdersSection();
                case InventorySection.administration:
                  return const InventoryAdminSection();
              }
            },
          ),
        ),
      ],
    );
  }
}
