import 'package:my_desktop_app/core/supabase_client.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AccountingRepository — كل استدعاءات Supabase RPC لقسم الحسابات
// يُطابق 025_accounting_rpcs_v2.sql
// ══════════════════════════════════════════════════════════════════════════════

class AccountingRepository {
  // ── المبيعات ────────────────────────────────────────────────────────────────

  /// ملخص المبيعات (إيرادات + مصروفات + مبيعات نقدية/بطاقة)
  Future<Map<String, dynamic>> getSalesSummary({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async {
    final result = await supabase.rpc('acc_get_sales_summary', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// تفاصيل الفواتير — keyset pagination
  Future<Map<String, dynamic>> getSalesDetail({
    required DateTime from,
    required DateTime to,
    String? branchId,
    int limit = 50,
    String? cursorTs,
    String? cursorId,
  }) async {
    final result = await supabase.rpc('acc_get_sales_detail', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
      'p_limit': limit,
      'p_cursor_ts': ?cursorTs,
      'p_cursor_id': ?cursorId,
    });
    return (result as Map<String, dynamic>?) ?? {'items': [], 'limit': limit};
  }

  // ── الإقفالات ───────────────────────────────────────────────────────────────

  /// إقفالات لعرض الـ Dashboard (آخر 20، بدون pagination)
  Future<List<Map<String, dynamic>>> getClosingsForDashboard({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async {
    final result = await supabase.rpc('acc_get_closings_dashboard', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
    });
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  /// قائمة الإقفالات الكاملة — keyset pagination
  Future<Map<String, dynamic>> getClosings({
    required DateTime from,
    required DateTime to,
    String? branchId,
    int limit = 50,
    String? cursorTs,
    String? cursorId,
  }) async {
    final result = await supabase.rpc('acc_get_closings', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
      'p_limit': limit,
      'p_cursor_ts': ?cursorTs,
      'p_cursor_id': ?cursorId,
    });
    return (result as Map<String, dynamic>?) ?? {'items': [], 'limit': limit};
  }

  /// تسجيل مراجعة إقفال
  Future<Map<String, dynamic>> reviewClosing({
    required String closingId,
    required double reviewedDifference,
    String? reviewReason,
    String? accountantNotes,
  }) async {
    final result = await supabase.rpc('acc_review_closing', params: {
      'p_closing_id': closingId,
      'p_reviewed_difference': reviewedDifference,
      'p_review_reason': ?reviewReason,
      'p_accountant_notes': ?accountantNotes,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// إحالة العجز إلى HR
  Future<Map<String, dynamic>> referClosingToHr({
    required String closingId,
    required String employeeId,
    required double amount,
    required String reason,
  }) async {
    final result = await supabase.rpc('acc_refer_closing_to_hr', params: {
      'p_closing_id': closingId,
      'p_employee_id': employeeId,
      'p_amount': amount,
      'p_reason': reason,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// إلغاء عجز إقفال وردية وتصفيره وإلغاء طلب الخصم إذا كان معلقاً
  Future<Map<String, dynamic>> cancelClosingShortage({
    required String closingId,
    String? reason,
  }) async {
    final result = await supabase.rpc('acc_cancel_closing_shortage', params: {
      'p_closing_id': closingId,
      'p_reason': ?reason,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  // ── المصروفات ───────────────────────────────────────────────────────────────

  /// كل المصروفات — keyset pagination
  Future<Map<String, dynamic>> getAllExpenses({
    required DateTime from,
    required DateTime to,
    String? branchId,
    int limit = 50,
    String? cursorTs,
    String? cursorId,
  }) async {
    final result = await supabase.rpc('acc_get_all_expenses', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
      'p_limit': limit,
      'p_cursor_ts': ?cursorTs,
      'p_cursor_id': ?cursorId,
    });
    return (result as Map<String, dynamic>?) ??
        {'summary': {}, 'items': [], 'limit': limit};
  }

  /// إضافة مصروف جديد من المحاسب (مع تحديد الفرع أو بدونه كفرع رئيسي HQ)
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    final result = await supabase.rpc('create_expense', params: {
      'p': data,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }


  // ── المشتريات ───────────────────────────────────────────────────────────────

  /// قائمة طلبات التوريد — keyset pagination
  Future<Map<String, dynamic>> getSupplyOrders({
    String? status,
    int limit = 50,
    String? cursorTs,
    String? cursorId,
  }) async {
    final result = await supabase.rpc('acc_get_supply_orders', params: {
      'p_status': ?status,
      'p_limit': limit,
      'p_cursor_ts': ?cursorTs,
      'p_cursor_id': ?cursorId,
    });
    return (result as Map<String, dynamic>?) ?? {'items': [], 'limit': limit};
  }

  /// إنشاء طلب توريد جديد (يمكن اعتماده تلقائياً إذا كان منشأ من الحسابات)
  Future<Map<String, dynamic>> createSupplyOrder({
    required String clientId,
    required String supplierName,
    String? supplierPhone,
    DateTime? expectedDate,
    String priority = 'normal',
    String? notes,
    required List<Map<String, dynamic>> lines,
    bool autoApprove = false,
  }) async {
    final result = await supabase.rpc('create_supply_order', params: {
      'p_client_id': clientId,
      'p_supplier_name': supplierName,
      'p_supplier_phone': ?supplierPhone,
      'p_expected_date': ?expectedDate?.toIso8601String().substring(0, 10),
      'p_priority': priority,
      'p_notes': ?notes,
      'p_lines': lines,
      'p_auto_approve': autoApprove,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// مراجعة طلب توريد (اعتماد بالكميات المعتمدة أو رفض مع السبب) للمحاسب
  Future<Map<String, dynamic>> reviewSupplyOrder({
    required String orderId,
    required String decision,
    required int expectedVersion,
    String? rejectionReason,
    List<Map<String, dynamic>>? lines,
  }) async {
    final result = await supabase.rpc('review_supply_order', params: {
      'p_order_id': orderId,
      'p_expected_version': expectedVersion,
      'p_decision': decision,
      'p_rejection_reason': ?rejectionReason,
      'p_lines': ?lines,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  // ── المخزون ─────────────────────────────────────────────────────────────────

  /// نظرة عامة على المخزون — keyset pagination
  Future<Map<String, dynamic>> getInventoryOverview({
    bool lowStockOnly = false,
    int limit = 100,
    String? cursorName,
    String? cursorId,
  }) async {
    final result = await supabase.rpc('acc_get_inventory_overview', params: {
      'p_low_stock_only': lowStockOnly,
      'p_limit': limit,
      'p_cursor_name': ?cursorName,
      'p_cursor_id': ?cursorId,
    });
    return (result as Map<String, dynamic>?) ??
        {'summary': {}, 'items': [], 'limit': limit};
  }

  /// تحديث متوسط التكلفة لصنف في المخزون
  Future<Map<String, dynamic>> updateInventoryItemCost({
    required String itemId,
    required double avgCost,
  }) async {
    final result = await supabase.rpc('acc_update_item_cost', params: {
      'p_item_id': itemId,
      'p_avg_cost': avgCost,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// جلب قائمة المنتجات التامة مع أسعار البيع وتكلفة الوجبات
  Future<List<Map<String, dynamic>>> getProductsWithCosts() async {
    final result = await supabase.rpc('acc_get_products_with_costs');
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  /// تحديث سعر البيع وتكلفة المنتج التام والخيارات
  Future<Map<String, dynamic>> updateProductPricing({
    required String productId,
    double? price,
    double cost = 0,
    List<Map<String, dynamic>>? variants,
  }) async {
    final result = await supabase.rpc('acc_update_product_pricing', params: {
      'p_product_id': productId,
      'p_price': ?price,
      'p_cost': cost,
      'p_variants': ?variants,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  // ── الرواتب ─────────────────────────────────────────────────────────────────

  /// قائمة الموظفين مع الرواتب — keyset pagination
  Future<Map<String, dynamic>> getEmployeesSalaries({
    String? branchId,
    String status = 'active',
    int limit = 50,
    String? cursorName,
    String? cursorId,
  }) async {
    final result = await supabase.rpc('acc_get_employees_salaries', params: {
      'p_branch_id': ?branchId,
      'p_status': status,
      'p_limit': limit,
      'p_cursor_name': ?cursorName,
      'p_cursor_id': ?cursorId,
    });
    return (result as Map<String, dynamic>?) ?? {'items': [], 'limit': limit};
  }

  /// تعديل الراتب مع تسجيل السجل التاريخي
  Future<Map<String, dynamic>> updateSalary({
    required String employeeId,
    required double basicSalary,
    double? allowances,
    double? transportAllowance,
    required String reason,
    DateTime? effectiveDate,
  }) async {
    final result = await supabase.rpc('acc_update_salary', params: {
      'p_employee_id': employeeId,
      'p_basic_salary': basicSalary,
      'p_allowances': ?allowances,
      'p_transport_allowance': ?transportAllowance,
      'p_reason': reason,
      'p_effective_date': ?effectiveDate?.toIso8601String().substring(0, 10),
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// سجل تغييرات راتب موظف
  Future<List<Map<String, dynamic>>> getSalaryHistory(
      String employeeId) async {
    final result = await supabase.rpc('acc_get_salary_history', params: {
      'p_employee_id': employeeId,
    });
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  // ── التنبيهات والـ Dashboard ────────────────────────────────────────────────

  /// تنبيهات الـ Dashboard (عجوزات + طلبات معلقة + مخزون منخفض)
  Future<List<Map<String, dynamic>>> getDashboardAlerts() async {
    final result = await supabase.rpc('acc_get_dashboard_alerts');
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  // ── بيانات مشتركة ───────────────────────────────────────────────────────────

  /// قائمة الفروع
  Future<List<Map<String, dynamic>>> listBranches() async {
    final result = await supabase.rpc('acc_list_branches');
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  /// قائمة الموردين
  Future<List<Map<String, dynamic>>> listSuppliers() async {
    final result = await supabase.rpc('acc_list_suppliers');
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  /// موظفو فرع محدد (للإحالة إلى HR)
  Future<List<Map<String, dynamic>>> getBranchEmployees(
      String branchId) async {
    final result = await supabase.rpc('acc_get_branch_employees', params: {
      'p_branch_id': branchId,
    });
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }

  // ── التقارير الشاملة ────────────────────────────────────────────────────────

  /// احتساب طلبيات الفرع من المخزن الرئيسي كقيمة مالية
  Future<Map<String, dynamic>> getBranchWarehouseOrders({
    DateTime? from,
    DateTime? to,
    String? branchId,
  }) async {
    final result =
        await supabase.rpc('acc_get_branch_warehouse_orders', params: {
      'p_from': ?from?.toUtc().toIso8601String(),
      'p_to': ?to?.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
    });
    return (result as Map<String, dynamic>?) ??
        {'orders': [], 'total_cost': 0};
  }

  /// التقرير المالي الشامل للشركة والفرع (مبيعات، مشتريات، مصروفات، طلبيات، فائض كاشير)
  Future<Map<String, dynamic>> getComprehensiveFinancialReport({
    DateTime? from,
    DateTime? to,
    String? branchId,
  }) async {
    final result =
        await supabase.rpc('acc_get_comprehensive_financial_report', params: {
      'p_from': ?from?.toUtc().toIso8601String(),
      'p_to': ?to?.toUtc().toIso8601String(),
      'p_branch_id': ?branchId,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }
}
