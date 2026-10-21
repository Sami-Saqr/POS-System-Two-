import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/accounting_repository.dart';
import '../widgets/accounting_shared_widgets.dart';
// ══════════════════════════════════════════════════════════════════════════════
// PurchasesScreen — صفحة طلبات التوريد (المشتريات)
// ══════════════════════════════════════════════════════════════════════════════

class PurchasesScreen extends StatefulWidget {
  final AccountingRepository repo;
  const PurchasesScreen({super.key, required this.repo});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  String? _statusFilter;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  static final _dtFmt = DateFormat('dd/MM/yyyy');

  static const _statusOptions = [
    (null,               'الكل'),
    ('pending_review',   'قيد المراجعة'),
    ('approved',         'معتمد'),
    ('received',         'مستلم'),
    ('rejected',         'مرفوض'),
    ('cancelled',        'ملغى'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.repo.getSupplyOrders(status: _statusFilter);
      if (mounted) {
        setState(() => _orders = List<Map<String, dynamic>>.from(data['items'] as List? ?? []));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── KPIs ──────────────────────────────────────────────────────────────────────
  int get _pendingCount   => _orders.where((o) => o['status'] == 'pending_review').length;
  int get _approvedCount  => _orders.where((o) => o['status'] == 'approved').length;
  int get _receivedCount  => _orders.where((o) => o['status'] == 'received').length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer));
    if (_error != null) return AccErrorWidget(message: _error!, onRetry: _load);

    return Container(
      color: const Color(0xFF0B0E14),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilters(),
          const SizedBox(height: 24),
          Row(children: [
            AccKpiCard(title: 'إجمالي الطلبات', value: '${_orders.length}',
                icon: Icons.shopping_cart_outlined, iconColor: AppColors.primaryContainer,
                bgColor: const Color(0xFF1A1200)),
            const SizedBox(width: 12),
            AccKpiCard(title: 'قيد المراجعة', value: '$_pendingCount',
                icon: Icons.pending_actions_rounded, iconColor: const Color(0xFFFFAA00),
                bgColor: const Color(0xFF1A1400)),
            const SizedBox(width: 12),
            AccKpiCard(title: 'معتمد — بانتظار الاستلام', value: '$_approvedCount',
                icon: Icons.check_circle_outlined, iconColor: const Color(0xFF60A0FF),
                bgColor: const Color(0xFF0D1225)),
            const SizedBox(width: 12),
            AccKpiCard(title: 'مستلم', value: '$_receivedCount',
                icon: Icons.inventory_2_outlined, iconColor: AppColors.tertiary,
                bgColor: const Color(0xFF0D1A10)),
          ]),
          const SizedBox(height: 24),
          _buildOrdersList(),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('طلبات التوريد',
          style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
      Text('متابعة طلبات الشراء من الموردين للمستودع',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: const Color(0xFF8A92A3))),
    ]),
    const Spacer(),
    AccActionButton(
      icon: Icons.add_rounded, label: 'طلب توريد جديد',
      onTap: () => _showNewOrderDialog(context),
      color: AppColors.primaryContainer,
    ),
    const SizedBox(width: 8),
    AccActionButton(icon: Icons.refresh_rounded, label: 'تحديث', onTap: _load,
        color: const Color(0xFF8A92A3)),
  ]);

  Widget _buildFilters() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF141720),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2430))),
    child: Row(children: _statusOptions.map((opt) {
      final active = _statusFilter == opt.$1;
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: InkWell(
          onTap: () { setState(() => _statusFilter = opt.$1); _load(); },
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: active ? AppColors.primaryContainer.withValues(alpha: 0.15) : const Color(0xFF1A1E26),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? AppColors.primaryContainer : const Color(0xFF2A2E3A)),
            ),
            child: Text(opt.$2, style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                color: active ? AppColors.primaryContainer : const Color(0xFF8A92A3),
                fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ),
        ),
      );
    }).toList()),
  );

  Widget _buildOrdersList() {
    if (_orders.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(48),
              child: Text('لا توجد طلبات توريد',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14, color: const Color(0xFF8A92A3)))));
    }

    return AccSectionCard(
      title: 'طلبات التوريد (${_orders.length})',
      child: ListView.separated(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: _orders.length,
        separatorBuilder: (_, _) => const Divider(color: Color(0xFF1E2430), height: 1),
        itemBuilder: (_, i) => _OrderTile(
          order: _orders[i],
          onApprove: () => _showApproveOrderDialog(context, _orders[i]),
          onReject: () => _showRejectOrderDialog(context, _orders[i]),
        ),
      ),
    );
  }

  // ── Approve Order Dialog ──────────────────────────────────────────────────────
  void _showApproveOrderDialog(BuildContext context, Map<String, dynamic> order) {
    final rawLines = (order['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (rawLines.isEmpty) return;

    final lineQtyControllers = <String, TextEditingController>{};
    final lineCostControllers = <String, TextEditingController>{};

    for (final l in rawLines) {
      final lineId = l['id']?.toString() ?? '';
      final reqQty = (l['qty_requested'] as num?)?.toDouble() ?? 0;
      final cost = (l['unit_cost'] as num?)?.toDouble() ?? 0;
      lineQtyControllers[lineId] = TextEditingController(text: reqQty.toString());
      lineCostControllers[lineId] = TextEditingController(text: cost.toString());
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1E26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 720,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF60A0FF), size: 24),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('اعتماد طلب توريد — ${order['number'] ?? ''}',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('المورد: ${order['supplier_name'] ?? '—'} | يرجى مراجعة واعتماد الكميات وأسعار التكلفة',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF8A92A3))),
                ]),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: Color(0xFF8A92A3)), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            const Divider(color: Color(0xFF1E2430), height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1.2),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFF141720)),
                      children: ['الصنف', 'المطلوب', 'الكمية المعتمدة', 'سعر الوحدة (ر.س)'].map((h) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Text(h, style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF8A92A3))),
                      )).toList(),
                    ),
                    ...rawLines.map((l) {
                      final lineId = l['id']?.toString() ?? '';
                      return TableRow(
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E2430)))),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            child: Text('${l['item_name'] ?? '—'} (${l['unit_code'] ?? l['unit'] ?? ''})',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: Colors.white)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            child: Text('${l['qty_requested'] ?? '—'}',
                                style: GoogleFonts.spaceGrotesk(fontSize: 13, color: const Color(0xFF8A92A3))),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            child: TextFormField(
                              controller: lineQtyControllers[lineId],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.white),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                filled: true,
                                fillColor: const Color(0xFF0B0E14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2A2E3A))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF60A0FF))),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            child: TextFormField(
                              controller: lineCostControllers[lineId],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.white),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                filled: true,
                                fillColor: const Color(0xFF0B0E14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2A2E3A))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF60A0FF))),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const Divider(color: Color(0xFF1E2430), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Color(0xFF8A92A3)))),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('تأكيد واعتماد الطلب'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF60A0FF),
                    foregroundColor: const Color(0xFF0D1225),
                  ),
                  onPressed: () async {
                    final approvedLines = <Map<String, dynamic>>[];
                    for (final l in rawLines) {
                      final lineId = l['id']?.toString() ?? '';
                      final q = double.tryParse(lineQtyControllers[lineId]?.text ?? '0') ?? 0;
                      final c = double.tryParse(lineCostControllers[lineId]?.text ?? '0') ?? 0;
                      approvedLines.add({
                        'line_id': lineId,
                        'qty_approved': q,
                        'unit_cost': c,
                      });
                    }

                    Navigator.pop(ctx);
                    setState(() => _loading = true);
                    try {
                      await widget.repo.reviewSupplyOrder(
                        orderId: order['id'] as String,
                        expectedVersion: (order['version'] as num?)?.toInt() ?? 1,
                        decision: 'approved',
                        lines: approvedLines,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم اعتماد طلب التوريد بنجاح، وأصبح جاهزاً للاستلام بالمستودع'),
                            backgroundColor: AppColors.tertiary,
                          ),
                        );
                      }
                      _load();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ في الاعتماد: $e'), backgroundColor: const Color(0xFFFF6B6B)),
                        );
                        setState(() => _loading = false);
                      }
                    }
                  },
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Reject Order Dialog ───────────────────────────────────────────────────────
  void _showRejectOrderDialog(BuildContext context, Map<String, dynamic> order) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1E26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Icon(Icons.cancel_outlined, color: Color(0xFFFF6B6B), size: 24),
                const SizedBox(width: 10),
                Text('رفض طلب توريد — ${order['number'] ?? ''}',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: Color(0xFF8A92A3)), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            const Divider(color: Color(0xFF1E2430), height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('سبب الرفض:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF8A92A3))),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'اكتب سبب رفض طلب التوريد لمسؤول المخزن...',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF6C7280)),
                    filled: true,
                    fillColor: const Color(0xFF141720),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A2E3A))),
                  ),
                ),
              ]),
            ),
            const Divider(color: Color(0xFF1E2430), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Color(0xFF8A92A3)))),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('تأكيد الرفض'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final reason = reasonCtrl.text.trim();
                    if (reason.isEmpty) return;

                    Navigator.pop(ctx);
                    setState(() => _loading = true);
                    try {
                      await widget.repo.reviewSupplyOrder(
                        orderId: order['id'] as String,
                        expectedVersion: (order['version'] as num?)?.toInt() ?? 1,
                        decision: 'rejected',
                        rejectionReason: reason,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم رفض طلب التوريد بنجاح'), backgroundColor: Color(0xFFFF6B6B)),
                        );
                      }
                      _load();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ: $e'), backgroundColor: const Color(0xFFFF6B6B)),
                        );
                        setState(() => _loading = false);
                      }
                    }
                  },
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── New Order Dialog ──────────────────────────────────────────────────────────
  void _showNewOrderDialog(BuildContext context) async {
    List<Map<String, dynamic>> inventoryItems = [];
    try {
      final res = await widget.repo.getInventoryOverview();
      inventoryItems = List<Map<String, dynamic>>.from(res['items'] as List? ?? []);
    } catch (_) {}
    if (!mounted) return;

    final supplierNameCtrl = TextEditingController();
    final supplierPhoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime expectedDate = DateTime.now().add(const Duration(days: 3));
    String priority = 'normal';
    bool autoApprove = true;
    final List<_OrderLineEntry> lines = [_OrderLineEntry()];

    showDialog(
      context: this.context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => Dialog(
        backgroundColor: const Color(0xFF1A1E26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(width: 680, child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Text('طلب توريد جديد', style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: Color(0xFF8A92A3)),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
          const Divider(color: Color(0xFF1E2430), height: 1),
          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
            Row(children: [
              Expanded(child: AccDlgField('اسم المورد', hint: 'اسم المورد', ctrl: supplierNameCtrl)),
              const SizedBox(width: 12),
              Expanded(child: AccDlgField('رقم الجوال (اختياري)', hint: '05xxxxxxxx', ctrl: supplierPhoneCtrl)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('تاريخ التوريد المتوقع', style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11, color: const Color(0xFF8A92A3))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: ctx,
                        initialDate: expectedDate, firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setDlg(() => expectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: const Color(0xFF141720), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF8A92A3)),
                      const SizedBox(width: 8),
                      Text(_dtFmt.format(expectedDate),
                          style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.white)),
                    ]),
                  ),
                ),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الأولوية', style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11, color: const Color(0xFF8A92A3))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: priority, dropdownColor: const Color(0xFF1A1E26),
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true, fillColor: Color(0xFF141720),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none)),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('عادية')),
                    DropdownMenuItem(value: 'urgent', child: Text('عاجلة')),
                  ],
                  onChanged: (v) => setDlg(() => priority = v!),
                ),
              ])),
            ]),
            const SizedBox(height: 12),
            AccDlgField('ملاحظات', hint: 'ملاحظات الطلب', ctrl: notesCtrl, maxLines: 2),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF141720),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2E3A)),
              ),
              child: Row(children: [
                Checkbox(
                  value: autoApprove,
                  activeColor: const Color(0xFF60A0FF),
                  onChanged: (v) => setDlg(() => autoApprove = v ?? true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('اعتماد الطلب فوراً (بانتظار استلام المخزون)',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    Text('تفعيل هذا الخيار ينشئ الطلب كمعتمد مباشرة ويُرسل إشعاراً للمستودع للاستلام دون الحاجة لمراجعة إضافية',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF8A92A3))),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            // Lines
            Row(children: [
              Text('أصناف الطلب', style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('إضافة صنف'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryContainer),
                onPressed: () => setDlg(() => lines.add(_OrderLineEntry())),
              ),
            ]),
            const SizedBox(height: 8),
            ...lines.asMap().entries.map((entry) {
              final idx = entry.key;
              final line = entry.value;
              return _OrderLineTile(
                line: line, items: inventoryItems,
                onRemove: lines.length > 1 ? () => setDlg(() => lines.removeAt(idx)) : null,
                onChanged: () => setDlg(() {}),
              );
            }),
          ]))),
          const Divider(color: Color(0xFF1E2430), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء', style: TextStyle(color: Color(0xFF8A92A3)))),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(autoApprove ? 'إنشاء واعتماد الطلب' : 'إرسال الطلب للمراجعة'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: const Color(0xFF1A1200)),
                onPressed: () async {
                  if (supplierNameCtrl.text.trim().isEmpty) return;
                  if (lines.any((l) => l.itemId == null || l.qty <= 0)) return;
                  Navigator.pop(ctx);
                  setState(() => _loading = true);
                  try {
                    await widget.repo.createSupplyOrder(
                      clientId: const Uuid().v4(),
                      supplierName: supplierNameCtrl.text.trim(),
                      supplierPhone: supplierPhoneCtrl.text.trim().isEmpty ? null : supplierPhoneCtrl.text.trim(),
                      expectedDate: expectedDate,
                      priority: priority,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      lines: lines.map((l) => {
                        'item_id': l.itemId,
                        'qty_requested': l.qty,
                        'unit_cost': l.unitCost,
                      }).toList(),
                      autoApprove: autoApprove,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(autoApprove
                              ? 'تم إنشاء واعتماد طلب التوريد بنجاح، وبانتظار استلام المخزون'
                              : 'تم إرسال طلب التوريد للمراجعة بنجاح'),
                          backgroundColor: AppColors.tertiary,
                        ),
                      );
                    }
                    _load();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('خطأ: $e'), backgroundColor: const Color(0xFFFF6B6B)));
                    }
                    if (mounted) setState(() => _loading = false);
                  }
                },
              ),
            ]),
          ),
        ])),
      )),
    );
  }
}

// ── Order Tile ─────────────────────────────────────────────────────────────────
class _OrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const _OrderTile({required this.order, this.onApprove, this.onReject});

  static final _dtFmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final status     = order['status'] as String? ?? '';
    final lines      = (order['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final expectedDt = DateTime.tryParse(order['expected_date'] as String? ?? '');
    final isUrgent   = order['priority'] == 'urgent';

    return ExpansionTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _statusBg(status), borderRadius: BorderRadius.circular(10)),
        child: Icon(_statusIcon(status), color: _statusColor(status), size: 20),
      ),
      title: Row(children: [
        Expanded(child: Text(order['number'] as String? ?? '—',
            style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white))),
        Text(order['supplier_name'] as String? ?? '—',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF8A92A3))),
        const SizedBox(width: 8),
        if (isUrgent) Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.3))),
          child: Text('عاجل', style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10, color: const Color(0xFFFF6B6B))),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: _statusBg(status), borderRadius: BorderRadius.circular(4)),
          child: Text(_statusLabel(status), style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10, color: _statusColor(status))),
        ),
      ]),
      subtitle: Text(
        'التوريد المتوقع: ${expectedDt != null ? _dtFmt.format(expectedDt) : '—'}  —  ${lines.length} صنف',
        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF8A92A3)),
      ),
      iconColor: const Color(0xFF8A92A3),
      collapsedIconColor: const Color(0xFF8A92A3),
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF0B0E14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E2430))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Table(
              columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1)},
              children: [
                TableRow(decoration: const BoxDecoration(color: Color(0xFF1A1E26)),
                    children: ['الصنف','مطلوب','معتمد','مستلم'].map((h) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(h, style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF8A92A3))),
                    )).toList()),
                ...lines.map((l) => TableRow(
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF1E2430)))),
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text('${l['item_name'] ?? '—'} (${l['unit_code'] ?? l['unit'] ?? ''})',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.white))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text('${l['qty_requested'] ?? '—'}',
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.white))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text(l['qty_approved']?.toString() ?? '—',
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: const Color(0xFF60A0FF)))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text(l['qty_received']?.toString() ?? '—',
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppColors.tertiary))),
                  ],
                )),
              ],
            ),
            if (status == 'pending_review') ...[
              const SizedBox(height: 14),
              const Divider(color: Color(0xFF1E2430), height: 1),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('طلب وارد من المستودع بانتظار الاعتماد:',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFFFFAA00))),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFFF6B6B)),
                  label: const Text('رفض الطلب', style: TextStyle(color: Color(0xFFFF6B6B))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF6B6B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onReject,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('اعتماد وتحديد الكميات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF60A0FF),
                    foregroundColor: const Color(0xFF0D1225),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onApprove,
                ),
              ]),
            ],
            if (order['notes'] != null && (order['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('ملاحظات: ${order['notes']}',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF8A92A3))),
            ],
            if (order['rejection_reason'] != null && (order['rejection_reason'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('سبب الرفض: ${order['rejection_reason']}',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFFFF6B6B))),
            ],
          ]),
        ),
      ],
    );
  }

  Color _statusColor(String s) => switch (s) {
    'pending_review' => const Color(0xFFFFAA00),
    'approved'       => const Color(0xFF60A0FF),
    'received'       => AppColors.tertiary,
    'rejected'       => const Color(0xFFFF6B6B),
    'cancelled'      => const Color(0xFF8A92A3),
    _                => const Color(0xFF8A92A3),
  };

  Color _statusBg(String s) => _statusColor(s).withValues(alpha: 0.12);

  IconData _statusIcon(String s) => switch (s) {
    'pending_review' => Icons.pending_actions_rounded,
    'approved'       => Icons.check_circle_outline_rounded,
    'received'       => Icons.inventory_2_outlined,
    'rejected'       => Icons.cancel_outlined,
    'cancelled'      => Icons.remove_circle_outline_rounded,
    _                => Icons.help_outline_rounded,
  };

  String _statusLabel(String s) => switch (s) {
    'pending_review' => 'قيد المراجعة',
    'approved'       => 'معتمد',
    'received'       => 'مستلم',
    'rejected'       => 'مرفوض',
    'cancelled'      => 'ملغى',
    _                => s,
  };
}

// ── Order Line Entry (stateful for new order dialog) ──────────────────────────
class _OrderLineEntry {
  String? itemId;
  String? itemName;
  double qty = 1;
  double unitCost = 0;
}

class _OrderLineTile extends StatefulWidget {
  final _OrderLineEntry line;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;
  const _OrderLineTile({required this.line, required this.items,
    this.onRemove, required this.onChanged});

  @override
  State<_OrderLineTile> createState() => _OrderLineTileState();
}

class _OrderLineTileState extends State<_OrderLineTile> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _costCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl  = TextEditingController(text: widget.line.qty.toString());
    _costCtrl = TextEditingController(text: widget.line.unitCost.toString());
  }

  @override
  void dispose() { _qtyCtrl.dispose(); _costCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF0B0E14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E2430))),
      child: Row(children: [
        // Item picker
        Expanded(flex: 3, child: DropdownButtonFormField<String>(
          initialValue: widget.line.itemId,
          dropdownColor: const Color(0xFF1A1E26),
          style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 12),
          decoration: const InputDecoration(isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true, fillColor: Color(0xFF141720),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none)),
          hint: const Text('اختر صنف', style: TextStyle(color: Color(0xFF8A92A3), fontSize: 12)),
          items: widget.items.map((item) {
            final id = (item['id'] ?? item['item_id']) as String;
            final unit = item['unit_code'] ?? item['unit'] ?? '';
            return DropdownMenuItem(
              value: id,
              child: Text('${item['name'] ?? ''} ($unit)', style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: (v) { setState(() { widget.line.itemId = v; }); widget.onChanged(); },
        )),
        const SizedBox(width: 8),
        // Qty
        SizedBox(width: 80, child: TextFormField(
          controller: _qtyCtrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.white),
          decoration: const InputDecoration(labelText: 'الكمية', isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true, fillColor: Color(0xFF141720),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none)),
          onChanged: (v) { widget.line.qty = double.tryParse(v) ?? 1; widget.onChanged(); },
        )),
        const SizedBox(width: 8),
        // Unit cost
        SizedBox(width: 100, child: TextFormField(
          controller: _costCtrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.white),
          decoration: const InputDecoration(labelText: 'التكلفة', isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true, fillColor: Color(0xFF141720),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none)),
          onChanged: (v) { widget.line.unitCost = double.tryParse(v) ?? 0; widget.onChanged(); },
        )),
        if (widget.onRemove != null) ...[
          const SizedBox(width: 6),
          IconButton(icon: const Icon(Icons.remove_circle_outline_rounded,
              size: 18, color: Color(0xFFFF6B6B)),
              onPressed: widget.onRemove),
        ],
      ]),
    );
  }
}
