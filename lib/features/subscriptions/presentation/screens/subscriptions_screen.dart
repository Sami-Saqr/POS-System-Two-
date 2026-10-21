import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/cubits/held_orders_cubit.dart';
import '../../../../core/models/held_order.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../mock_data/mock_packages.dart';
import '../models/subscription_package.dart';
import '../widgets/action_dock_bar.dart';
import '../widgets/package_stats_indicators.dart';
import '../widgets/pos_app_bar.dart';
import '../widgets/pos_status_footer.dart';
import '../widgets/subscribers_list_button.dart';
import '../widgets/subscription_package_card.dart';

class SubscriptionsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialPayload;

  const SubscriptionsScreen({super.key, this.initialPayload});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final FocusNode _focusNode = FocusNode();

  String? _selectedPackageId;
  String? _selectedPackageName;
  int? _selectedDurationDays;
  int? _selectedMealIndex;
  String? _selectedPlanLabel;
  int? _selectedPrice;

  @override
  void initState() {
    super.initState();
    if (widget.initialPayload != null) {
      final p = widget.initialPayload!;
      _selectedPackageId = p['packageId'];
      _selectedPackageName = p['packageName'];
      _selectedDurationDays = p['durationDays'];
      _selectedMealIndex = p['mealIndex'];
      _selectedPlanLabel = p['planLabel'];
      _selectedPrice = p['price'];
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onPlanSelected(
    SubscriptionPackage package,
    int durationDays,
    int mealIndex,
    String durationLabel,
    String mealLabel,
    int price,
  ) {
    setState(() {
      _selectedPackageId = package.id;
      _selectedPackageName = package.name;
      _selectedDurationDays = durationDays;
      _selectedMealIndex = mealIndex;
      _selectedPlanLabel = '$durationLabel — $mealLabel';
      _selectedPrice = price;
    });
  }

  void _onPlanDeselected() {
    setState(() {
      _selectedPackageId = null;
      _selectedPackageName = null;
      _selectedDurationDays = null;
      _selectedMealIndex = null;
      _selectedPlanLabel = null;
      _selectedPrice = null;
    });
  }

  void _handleHoldOrder() {
    if (_selectedPackageId == null || _selectedPrice == null) return;

    final order = HeldOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      source: HeldOrderSource.subscription,
      heldAt: DateTime.now(),
      summaryLabel: '$_selectedPackageName - $_selectedPlanLabel',
      totalAmount: _selectedPrice!.toDouble(),
      payload: {
        'packageId': _selectedPackageId,
        'packageName': _selectedPackageName,
        'durationDays': _selectedDurationDays,
        'mealIndex': _selectedMealIndex,
        'planLabel': _selectedPlanLabel,
        'price': _selectedPrice,
      },
    );

    context.read<HeldOrdersCubit>().holdOrder(order);
    _onPlanDeselected();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تعليق الطلب بنجاح', textAlign: TextAlign.right),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _onPlanDeselected();
          } else if (event.logicalKey == LogicalKeyboardKey.f4) {
            _handleHoldOrder();
          }
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // ── 1. AppBar المركّب (عنوان + جلسة + تابات) ──────────────────
              const PosAppBar(),

              // ── 2. محتوى الصفحة الرئيسي ─────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                    vertical: AppDimens.spaceMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── مؤشرات الإحصائيات ───────────────────────────────
                      const Row(children: [PackageStatsIndicators()]),
                      const SizedBox(height: AppDimens.spaceLg),

                      // ── شبكة بطاقات الباقات (3 بطاقات) ──────────────────
                      SizedBox(
                        height: 420,
                        child: Row(
                          children: List.generate(mockPackages.length, (index) {
                            final pkg = mockPackages[index];
                            final isFeatured = pkg.id == 'athletes';
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: index > 0 ? AppDimens.spaceMd : 0,
                                ),
                                child: SubscriptionPackageCard(
                                  package: pkg,
                                  isFeatured: isFeatured,
                                  selectedPackageId: _selectedPackageId,
                                  selectedDurationDays: _selectedDurationDays,
                                  selectedMealIndex: _selectedMealIndex,
                                  onPlanSelected: _onPlanSelected,
                                  onPlanDeselected: _onPlanDeselected,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),

                      // ── زر قائمة المشتركين ──────────────────────────────
                      const SubscribersListButton(),
                      const SizedBox(height: AppDimens.spaceMd),
                    ],
                  ),
                ),
              ),

              // ── 3. شريط الإجراءات السفلي ────────────────────────────────
              ActionDockBar(
                selectedPackageName: _selectedPackageName,
                selectedPlanLabel: _selectedPlanLabel,
                selectedPrice: _selectedPrice,
                onCancel: _onPlanDeselected,
              ),

              // ── 4. فوتر حالة الأجهزة ────────────────────────────────────
              const PosStatusFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
