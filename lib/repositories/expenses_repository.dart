import '../core/supabase_client.dart';
import '../core/local_db.dart';

class ExpenseRecord {
  const ExpenseRecord({
    required this.clientId,
    required this.number,
    required this.category,
    required this.amount,
    required this.vatAmount,
    required this.total,
    required this.paymentMethod,
    required this.expenseDate,
    required this.createdAt,
    this.id,
    this.payee,
    this.description,
    this.notes,
  });

  final String? id;
  final String clientId;
  final String number;
  final String category;
  final double amount;
  final double vatAmount;
  final double total;
  final String paymentMethod;
  final DateTime expenseDate;
  final DateTime createdAt;
  final String? payee;
  final String? description;
  final String? notes;

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    double numberValue(dynamic value) => (value as num?)?.toDouble() ?? 0;
    DateTime dateValue(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();

    return ExpenseRecord(
      id: json['id']?.toString(),
      clientId: json['client_id']?.toString() ?? '',
      number: json['number']?.toString() ?? '-',
      category: json['category']?.toString() ?? '-',
      amount: numberValue(json['amount']),
      vatAmount: numberValue(json['vat_amount']),
      total: numberValue(json['total']),
      paymentMethod: json['payment_method']?.toString() ?? 'other',
      expenseDate: dateValue(json['expense_date']),
      createdAt: dateValue(json['created_at']),
      payee: json['payee']?.toString(),
      description: json['description']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  factory ExpenseRecord.fromLocalRecord(LocalRecord record) {
    final payload = record.payload;
    double numberValue(dynamic value) => (value as num?)?.toDouble() ?? 0;

    return ExpenseRecord(
      clientId: record.clientId,
      number: record.serverNumber ?? record.localNumber ?? '-',
      category: payload['category']?.toString() ?? '-',
      amount: numberValue(payload['amount']),
      vatAmount: numberValue(payload['vat_amount']),
      total:
          record.total ??
          numberValue(payload['amount']) + numberValue(payload['vat_amount']),
      paymentMethod: payload['payment_method']?.toString() ?? 'other',
      expenseDate:
          DateTime.tryParse(payload['expense_date']?.toString() ?? '') ??
          record.createdAt,
      createdAt: record.createdAt,
      payee: payload['payee']?.toString(),
      description: payload['description']?.toString(),
      notes: payload['notes']?.toString(),
    );
  }
}

class ExpensesRepository {
  Future<List<ExpenseRecord>> getBranchExpenses(String branchId) async {
    final response = await supabase.rpc(
      'get_branch_expenses',
      params: {'p_branch_id': branchId},
    );
    final rows = (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .map(ExpenseRecord.fromJson)
        .toList();
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }
}
