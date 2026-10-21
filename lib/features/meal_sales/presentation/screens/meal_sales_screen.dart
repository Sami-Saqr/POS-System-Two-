import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_desktop_app/cubits/sales/sales_cubit.dart';
import '../../../../core/cubits/held_orders_cubit.dart';
import '../../../../core/models/held_order.dart';
import '../../../../core/models/invoice_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/pos_status_footer.dart';
import '../../../../cubits/catalog/catalog_cubit.dart';
import '../../../../cubits/catalog/catalog_state.dart';
import '../../../../cubits/pos_settings/pos_settings_cubit.dart';
import '../../../../cubits/session/session_cubit.dart';
import '../cubits/cart_cubit.dart';
import '../widgets/invoice_preview_dialog.dart';
import '../widgets/meal_sales_app_bar.dart';
import '../widgets/meal_type_selection_dialog.dart';
import '../widgets/order_summary_panel.dart';
import '../widgets/protein_matrix_table.dart';
import '../widgets/quick_addon_card.dart';
import '../widgets/section_header.dart';

/// الشاشة الرئيسية للبيع بالوجبة (Meal Sales) — دايت كنج POS
class MealSalesScreen extends StatefulWidget {
  final List<CartLine>? initialCartLines;

  const MealSalesScreen({super.key, this.initialCartLines});

  @override
  State<MealSalesScreen> createState() => _MealSalesScreenState();
}

class _MealSalesScreenState extends State<MealSalesScreen> {
  late CartCubit _cartCubit;
  final FocusNode _focusNode = FocusNode();

  /// رقم الفاتورة الظاهر للكاشير؛ يبدأ من 001 ويزيد بعد إتمام الدفع.
  int _nextInvoiceNumber = 1;

  String get _displayInvoiceNumber =>
      _nextInvoiceNumber.toString().padLeft(3, '0');

  @override
  void initState() {
    super.initState();

    // نهيّئ CartCubit بنسبة الضريبة الحالية من PosSettingsCubit
    // لو لم تُحمَّل بعد (initial/failure) نبدأ بـ 0
    final posSettings = context.read<PosSettingsCubit>().state;
    final initialVatRate = posSettings.status == PosSettingsStatus.loaded
        ? posSettings.currentVatRate
        : 0.0;

    _cartCubit = CartCubit(initialVatRate: initialVatRate);

    if (widget.initialCartLines != null) {
      _cartCubit.restoreCart(widget.initialCartLines!);
    }
  }

  @override
  void dispose() {
    _cartCubit.close();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleHoldOrder() {
    final state = _cartCubit.state;
    if (state.lines.isEmpty) return;

    // تنظيف الاسم: لو كان UUID نستبدله بـ "صنف"
    String cleanName(String name) {
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      return uuidRegex.hasMatch(name.trim()) ? 'صنف' : name;
    }

    final summaryLabel = state.lines.length <= 2
        ? state.lines.map((l) => cleanName(l.name)).join(' + ')
        : '${cleanName(state.lines[0].name)} + ${cleanName(state.lines[1].name)} و ${state.lines.length - 2} أخرى';

    final order = HeldOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      source: HeldOrderSource.mealSale,
      heldAt: DateTime.now(),
      summaryLabel: summaryLabel,
      totalAmount: state.grandTotal,
      payload: List<CartLine>.from(state.lines),
    );

    context.read<HeldOrdersCubit>().holdOrder(order);
    _cartCubit.clearAll(keepVatRate: _cartCubit.state.vatValue);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تعليق الطلب بنجاح', textAlign: TextAlign.right),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// يبني [InvoiceData] من الحالة الحالية لـ [CartCubit] ويفتح Dialog المعاينة
  void _handleCheckout() {
    final cartState = _cartCubit.state;
    final sessionState = context.read<SessionCubit>().state;
    final posSettings = context.read<PosSettingsCubit>().state;

    // لو PosSettingsCubit في حالة failure (لا توجد نسبة ضريبة): امنع الإتمام
    if (posSettings.status == PosSettingsStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تعذر تحميل نسبة الضريبة. يُرجى إعادة المحاولة قبل إتمام الفاتورة.',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.deepOrange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: () => context.read<PosSettingsCubit>().retry(),
          ),
        ),
      );
      return;
    }

    // لو السلة فارغة، اعرض Snackbar ولا تفتح Dialog
    if (cartState.lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلب لإتمامه', textAlign: TextAlign.right),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final orderNumber = _displayInvoiceNumber;

    // تحويل CartLine → InvoiceLineItem
    final invoiceItems = cartState.lines
        .map(
          (line) => InvoiceLineItem(
            name: line.variantLabel.isNotEmpty
                ? '${line.name} (${line.variantLabel})'
                : line.name,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            totalPrice: line.lineTotal,
          ),
        )
        .toList();

    final invoiceData = InvoiceData(
      companyName: 'دايت كنج',
      branchName: sessionState.branchName.isNotEmpty
          ? sessionState.branchName
          : sessionState.branchCode,
      cashierName: sessionState.cashierName,
      orderNumber: orderNumber,
      dateTime: DateTime.now(),
      items: invoiceItems,
      subtotal: cartState.subtotal,
      discountAmount: cartState.discountAmount,
      vatAmount: cartState.vatAmount,
      grandTotal: cartState.grandTotal,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvoicePreviewDialog(
        invoiceData: invoiceData,
        cartState: cartState,
        sessionState: sessionState,
        onPaymentComplete: () {
          // إعادة ضبط السلة — الخصم يرجع 0، الضريبة ترجع للقيمة الحالية من PosSettingsCubit
          final currentVat = context
              .read<PosSettingsCubit>()
              .state
              .currentVatRate;
          _cartCubit.clearAll(keepVatRate: currentVat);
          context.read<SalesCubit>().reset();
          setState(() => _nextInvoiceNumber++);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الدفع بنجاح', textAlign: TextAlign.right),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cartCubit,
      child: BlocListener<PosSettingsCubit, PosSettingsState>(
        listenWhen: (previous, current) =>
            previous.status != PosSettingsStatus.loaded &&
            current.status == PosSettingsStatus.loaded,
        listener: (_, state) => _cartCubit.syncVatRate(state.currentVatRate),
        child: KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              // تجنب تعارض الاختصارات مع أي TextField مفتوح
              final primaryFocus = FocusManager.instance.primaryFocus;
              final isTextFieldFocused =
                  primaryFocus?.context?.widget is EditableText;

              if (event.logicalKey == LogicalKeyboardKey.f4) {
                _handleHoldOrder();
              } else if (event.logicalKey == LogicalKeyboardKey.escape &&
                  !isTextFieldFocused) {
                _cartCubit.clearAll(keepVatRate: _cartCubit.state.vatValue);
              } else if ((event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                  !isTextFieldFocused) {
                _handleCheckout();
              }
            }
          },
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: _MealSalesBody(
              orderNumber: _displayInvoiceNumber,
              onCheckout: _handleCheckout,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Body مع BlocBuilder للكاتالوج ─────────────────────────────────────────────

class _MealSalesBody extends StatelessWidget {
  final String orderNumber;
  final VoidCallback onCheckout;

  const _MealSalesBody({required this.orderNumber, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── 1. الهيدر ──────────────────────────────────────────────────────
          const MealSalesAppBar(),

          // ── 2. محتوى الكاتالوج والطلب (عمودان) ────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
                vertical: AppDimens.spaceMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── عمود الكاتالوج (8/12) ───────────────────────────────
                  Expanded(
                    flex: 8,
                    child: BlocBuilder<CatalogCubit, CatalogState>(
                      builder: (context, catalogState) {
                        return _CatalogColumn(catalogState: catalogState);
                      },
                    ),
                  ),

                  const SizedBox(width: AppDimens.spaceLg),

                  // ── عمود ملخص الطلب الجانبي الثابت (4/12) ──────────────
                  Expanded(
                    flex: 4,
                    child: OrderSummaryPanel(
                      orderNumber: orderNumber,
                      onCheckout: onCheckout,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. فوتر حالة الأجهزة ────────────────────────────────────────
          const PosStatusFooter(),
        ],
      ),
    );
  }
}

// ── عمود الكاتالوج — يتعامل مع حالات التحميل والخطأ والبيانات ───────────────

class _CatalogColumn extends StatelessWidget {
  final CatalogState catalogState;

  const _CatalogColumn({required this.catalogState});

  @override
  Widget build(BuildContext context) {
    final status = catalogState.status;

    // ── حالة loading بدون بيانات (أول تحميل) ─────────────────────────────
    if (status == CatalogStatus.loading && catalogState.products.isEmpty) {
      return const _CatalogLoadingState();
    }

    // ── حالة فشل بدون بيانات ────────────────────────────────────────────
    if (status == CatalogStatus.failure && catalogState.products.isEmpty) {
      return _CatalogErrorState(
        message: catalogState.errorMessage ?? 'تعذر تحميل المنتجات',
        onRetry: () => context.read<CatalogCubit>().load(force: true),
      );
    }

    // ── حالة initial (لم يبدأ التحميل بعد) ─────────────────────────────
    if (status == CatalogStatus.initial) {
      return const _CatalogLoadingState();
    }

    // ── البيانات موجودة (loaded أو loading مع stale data أو failure مع stale data)
    final mealProducts = catalogState.mealProducts;
    final addonProducts = catalogState.addonProducts;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: AppDimens.spaceSm),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── قسم وجبات البروتين ──────────────────────────────────────────
          if (mealProducts.isNotEmpty) ...[
            SectionHeader(
              title: 'أصناف البروتين الرئيسية',
              subtitle: 'اختر نوع البروتين والوزن لإضافته للفاتورة مباشرة',
              icon: Icons.fitness_center_rounded,
              badgeLabel:
                  '${mealProducts.length} ${mealProducts.length == 1 ? 'نوع' : 'أنواع'}',
            ),
            const SizedBox(height: AppDimens.spaceMd),
            ProteinMatrixTable(products: mealProducts),
            const SizedBox(height: AppDimens.spaceXl),
          ],

          // ── قسم الإضافات ────────────────────────────────────────────────
          if (addonProducts.isNotEmpty) ...[
            SectionHeader(
              title: 'إضافات سريعة وسناكات ومشروبات',
              subtitle: 'إضافات، سلطات، ومشروبات',
              icon: Icons.fastfood_rounded,
              badgeLabel: '${addonProducts.length} أصناف متوفرة',
            ),
            const SizedBox(height: AppDimens.spaceMd),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppDimens.spaceSm,
                crossAxisSpacing: AppDimens.spaceSm,
                mainAxisExtent: 52,
              ),
              itemCount: addonProducts.length,
              itemBuilder: (context, index) {
                final product = addonProducts[index];
                final price = product.price ?? 0.0;
                return QuickAddonCard(
                  label: product.name,
                  subLabel: product.description ?? product.tag ?? '',
                  price: price,
                  icon: _addonIcon(product.tag),
                  onTap: () async {
                    String finalName = product.name;
                    if (finalName.contains('متكامل') ||
                        finalName.contains('متكامله') ||
                        finalName.contains('متكاملة')) {
                      final selectedType = await showDialog<String>(
                        context: context,
                        builder: (_) => const MealTypeSelectionDialog(),
                      );
                      if (selectedType == null) return;
                      finalName = '${product.name} ($selectedType)';
                    }
                    if (!context.mounted) return;
                    context.read<CartCubit>().addItem(
                      productId: product.id,
                      variantId: null,
                      name: finalName,
                      variantLabel: 'إضافة',
                      unitPrice: price,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],

          // لو مافيش منتجات في الكلا القسمين
          if (mealProducts.isEmpty && addonProducts.isEmpty)
            const _EmptyCatalogState(),
        ],
      ),
    );
  }

  IconData _addonIcon(String? tag) {
    if (tag == null) return Icons.add_circle_outline_rounded;
    final t = tag.toLowerCase();
    if (t.contains('مشروب') || t.contains('drink')) {
      return Icons.local_drink_rounded;
    }
    if (t.contains('سلطة') || t.contains('salad')) return Icons.eco_rounded;
    if (t.contains('سناك') || t.contains('snack')) return Icons.cookie_rounded;
    if (t.contains('ساندوتش') || t.contains('sandwich')) {
      return Icons.bakery_dining_rounded;
    }
    return Icons.fastfood_rounded;
  }
}

// ── حالة التحميل ──────────────────────────────────────────────────────────────

class _CatalogLoadingState extends StatelessWidget {
  const _CatalogLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'جارٍ تحميل المنتجات...',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontMd,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── حالة الخطأ ────────────────────────────────────────────────────────────────

class _CatalogErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CatalogErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            message,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontMd,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryButtonGradient,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceXl,
                    vertical: AppDimens.spaceMd,
                  ),
                  child: Text(
                    'إعادة المحاولة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontMd,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── كاتالوج فارغ (لا توجد منتجات نشطة) ──────────────────────────────────────

class _EmptyCatalogState extends StatelessWidget {
  const _EmptyCatalogState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'لا توجد منتجات نشطة حالياً',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontMd,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
