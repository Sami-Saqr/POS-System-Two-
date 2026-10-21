import 'package:flutter/material.dart';

enum InventorySection {
  rawMaterials('الخامات في المخزون', Icons.grain),
  supplyRequests('طلبات المخزون والتوريد', Icons.shopping_cart_checkout),
  stockAudit('جرد ومطابقة المخزون', Icons.fact_check),
  kitchenIssue('صرف خامات للمطبخ', Icons.soup_kitchen),
  kitchenReceipts('استلام إنتاج المطبخ', Icons.inventory_2),
  branchOrders('طلبات الفروع', Icons.storefront),
  administration('الإدارة', Icons.admin_panel_settings);

  final String label;
  final IconData icon;
  const InventorySection(this.label, this.icon);
}

enum RawCategory {
  proteins('بروتينات ولحوم'),
  carbs('نشويات وحبوب'),
  oils('زيوت وتوابل'),
  produce('خضار وطازج');

  final String label;
  const RawCategory(this.label);
}

enum RawSortColumn { sku, name, category, stock }

enum SupplyStatus { pending, ordered, received }

enum IssueStatus { pending, issued }

enum BadgeTone { success, warning, danger, info, neutral }
