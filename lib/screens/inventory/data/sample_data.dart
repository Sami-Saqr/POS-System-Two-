import 'package:flutter/material.dart';
import 'package:my_desktop_app/screens/inventory/models/enums.dart';
import 'package:my_desktop_app/screens/inventory/models/raw_material.dart';
import 'package:my_desktop_app/screens/inventory/models/supply_order.dart';
import 'package:my_desktop_app/screens/inventory/models/audit_row.dart';
import 'package:my_desktop_app/screens/inventory/models/kitchen_issue.dart';
import '../models/meal_batch.dart';
import '../models/branch_order.dart';

class SampleData {
  static const List<RawMaterial> rawMaterials = [
    RawMaterial(
      sku: 'RAW-PRT-0101',
      name: 'صدور دجاج طازجة',
      category: RawCategory.proteins,
      categoryLabel: 'بروتينات',
      stock: 480,
      minLevel: 150,
      unit: 'كجم',
      icon: Icons.egg_alt,
    ),
    RawMaterial(
      sku: 'RAW-PRT-0104',
      name: 'لحم عجل هبرة مبرد',
      category: RawCategory.proteins,
      categoryLabel: 'بروتينات',
      stock: 210,
      minLevel: 100,
      unit: 'كجم',
      icon: Icons.restaurant,
    ),
    RawMaterial(
      sku: 'RAW-PRT-0205',
      name: 'فيليه سالمون نرويجي',
      category: RawCategory.proteins,
      categoryLabel: 'بروتينات بحرية',
      stock: 35,
      minLevel: 80,
      unit: 'كجم',
      icon: Icons.set_meal,
    ),
    RawMaterial(
      sku: 'RAW-CRB-0310',
      name: 'أرز بسمتي هندي ممتاز',
      category: RawCategory.carbs,
      categoryLabel: 'نشويات وحبوب',
      stock: 1250,
      minLevel: 400,
      unit: 'كجم',
      icon: Icons.grain,
    ),
    RawMaterial(
      sku: 'RAW-CRB-0315',
      name: 'شوفان عضوي خالي جلوتين',
      category: RawCategory.carbs,
      categoryLabel: 'نشويات وحبوب',
      stock: 340,
      minLevel: 120,
      unit: 'كجم',
      icon: Icons.spa,
    ),
    RawMaterial(
      sku: 'RAW-OIL-0402',
      name: 'زيت زيتون بكر ممتاز',
      category: RawCategory.oils,
      categoryLabel: 'زيوت وتوابل',
      stock: 260,
      minLevel: 80,
      unit: 'لتر',
      icon: Icons.water_drop,
    ),
    RawMaterial(
      sku: 'RAW-SPY-0420',
      name: 'بهارات وتتبيل دايت كينج الخاصة',
      category: RawCategory.oils,
      categoryLabel: 'زيوت وتوابل',
      stock: 95,
      minLevel: 40,
      unit: 'كجم',
      icon: Icons.local_florist,
    ),
    RawMaterial(
      sku: 'RAW-VEG-0508',
      name: 'بروكلي وفاصوليا خضراء طازجة',
      category: RawCategory.produce,
      categoryLabel: 'خضار وطازج',
      stock: 45,
      minLevel: 120,
      unit: 'كجم',
      icon: Icons.eco,
    ),
  ];

  static final List<SupplyOrder> supplyOrders = [
    SupplyOrder(
      id: 'PO-2024-0891',
      supplier: 'شركة مزارع التنمية الغذائية',
      items: 'صدور دجاج طازجة (300 كجم)',
      date: DateTime(2024, 5, 18),
      status: SupplyStatus.pending,
    ),
    SupplyOrder(
      id: 'PO-2024-0892',
      supplier: 'الشركة الخليجية للحبوب والأرز',
      items: 'أرز بسمتي أبيض (800 كجم)',
      date: DateTime(2024, 5, 19),
      status: SupplyStatus.pending,
    ),
    SupplyOrder(
      id: 'PO-2024-0893',
      supplier: 'أسماك المحيط للبحريات',
      items: 'فيليه سالمون مبرد (120 كجم)',
      date: DateTime(2024, 5, 20),
      status: SupplyStatus.pending,
    ),
    SupplyOrder(
      id: 'PO-2024-0888',
      supplier: 'المورد الإيطالي للزيوت',
      items: 'زيت زيتون بكر إسباني (200 لتر)',
      date: DateTime(2024, 5, 16),
      status: SupplyStatus.ordered,
    ),
    SupplyOrder(
      id: 'PO-2024-0885',
      supplier: 'شركة خضار القصيم الطازجة',
      items: 'بروكلي وزهرة وخضار مشكل (350 كجم)',
      date: DateTime(2024, 5, 15),
      status: SupplyStatus.ordered,
    ),
    SupplyOrder(
      id: 'PO-2024-0870',
      supplier: 'مطاحن الدقيق الوطنية',
      items: 'شوفان عضوي (500 كجم)',
      date: DateTime(2024, 5, 12),
      status: SupplyStatus.received,
    ),
    SupplyOrder(
      id: 'PO-2024-0865',
      supplier: 'شركة توابل الشرق الأوسط',
      items: 'بهارات دايت كينج (100 كجم)',
      date: DateTime(2024, 5, 10),
      status: SupplyStatus.received,
    ),
  ];

  static const List<AuditRow> auditRows = [
    AuditRow(
      sku: 'RAW-PRT-0101',
      name: 'صدور دجاج طازجة',
      systemQty: 480,
      actualQty: 480,
      unit: 'كجم',
      note: 'مطابق تماماً',
    ),
    AuditRow(
      sku: 'RAW-PRT-0205',
      name: 'فيليه سالمون نرويجي',
      systemQty: 35,
      actualQty: 33,
      unit: 'كجم',
      note: 'فارق 2 كجم تالف أثناء التقطيع',
    ),
    AuditRow(
      sku: 'RAW-CRB-0310',
      name: 'أرز بسمتي هندي ممتاز',
      systemQty: 1250,
      actualQty: 1250,
      unit: 'كجم',
      note: 'مطابق للدفاتر',
    ),
    AuditRow(
      sku: 'RAW-OIL-0402',
      name: 'زيت زيتون بكر ممتاز',
      systemQty: 260,
      actualQty: 258,
      unit: 'لتر',
      note: 'استهلاك غير مسجل بتتبيل المطبخ',
    ),
    AuditRow(
      sku: 'RAW-VEG-0508',
      name: 'بروكلي وفاصوليا خضراء',
      systemQty: 45,
      actualQty: 40,
      unit: 'كجم',
      note: 'تلف رطوبة بالصناديق',
    ),
  ];

  static const List<KitchenIssue> kitchenIssues = [
    KitchenIssue(
      id: 'ISSUE-2024-301',
      plan: 'تحضير 300 وجبة بروتين رياضية',
      materials: '120 كجم صدور دجاج + 40 كجم أرز',
      chef: 'الشيف أنس القحطاني',
      status: IssueStatus.issued,
    ),
    KitchenIssue(
      id: 'ISSUE-2024-302',
      plan: 'تجهيز صواني وجبات الكيتو البحرية',
      materials: '25 كجم سالمون + 10 كجم بروكلي + 3 لتر زيت زيتون',
      chef: 'الشيف سمير ممدوح',
      status: IssueStatus.issued,
    ),
    KitchenIssue(
      id: 'ISSUE-2024-303',
      plan: 'وجبات إفطار الشوفان الصحي',
      materials: '30 كجم شوفان عضوي',
      chef: 'الشيف إبراهيم',
      status: IssueStatus.pending,
    ),
  ];

  static final List<MealBatch> mealBatches = [
    MealBatch(
      batch: 'BATCH-2024-0518-A',
      meal: 'وجبة صدور الدجاج المشوية مع الأرز والبروكلي',
      quantity: 180,
      producedAt: DateTime(2024, 5, 18, 7, 0),
      expiresAt: DateTime(2024, 5, 20, 7, 0),
      qualityNote: 'مطابق للاشتراطات 100%',
    ),
    MealBatch(
      batch: 'BATCH-2024-0518-B',
      meal: 'وجبة سالمون مشوي كيتو مع الخضار المشوية',
      quantity: 95,
      producedAt: DateTime(2024, 5, 18, 8, 30),
      expiresAt: DateTime(2024, 5, 20, 8, 30),
      qualityNote: 'مطابق للاشتراطات 100%',
    ),
    MealBatch(
      batch: 'BATCH-2024-0518-C',
      meal: 'وجبة لحم عجل هبرة متبل مع البطاطا المهروسة',
      quantity: 120,
      producedAt: DateTime(2024, 5, 18, 9, 15),
      expiresAt: DateTime(2024, 5, 20, 9, 15),
      qualityNote: 'مطابق للاشتراطات 100%',
    ),
  ];

  static const List<BranchOrder> branchOrders = [
    BranchOrder(
      id: 'ORD-BR-01',
      branch: 'فرع السليمانية (الرياض)',
      timeLabel: 'اليوم 09:00 ص',
      status: 'جاهز للإرسال',
      dispatched: false,
      items: [
        BranchOrderItem(
          id: 'item-1',
          name: 'وجبة صدور دجاج مشوي مع أرز',
          requested: 50,
          issued: 50,
          unavailable: false,
        ),
        BranchOrderItem(
          id: 'item-2',
          name: 'وجبة سالمون كيتو دايت',
          requested: 25,
          issued: 25,
          unavailable: false,
        ),
        BranchOrderItem(
          id: 'item-3',
          name: 'سلطة سيزر صحية مع صوص خفيف',
          requested: 30,
          issued: 30,
          unavailable: false,
        ),
      ],
    ),
    BranchOrder(
      id: 'ORD-BR-02',
      branch: 'فرع الملقا (الرياض)',
      timeLabel: 'اليوم 09:45 ص',
      status: 'قيد التجهيز بالمستودع',
      dispatched: false,
      items: [
        BranchOrderItem(
          id: 'item-4',
          name: 'وجبة لحم عجل هبرة مع بطاطا',
          requested: 40,
          issued: 40,
          unavailable: false,
        ),
        BranchOrderItem(
          id: 'item-5',
          name: 'وجبة تونة طازجة متبلة',
          requested: 20,
          issued: 0,
          unavailable: true,
        ),
        BranchOrderItem(
          id: 'item-6',
          name: 'شوفان بالتوت والمكسرات',
          requested: 15,
          issued: 15,
          unavailable: false,
        ),
      ],
    ),
    BranchOrder(
      id: 'ORD-BR-03',
      branch: 'فرع حي النرجس (شمال الرياض)',
      timeLabel: 'اليوم 10:15 ص',
      status: 'طلب جديد',
      dispatched: false,
      items: [
        BranchOrderItem(
          id: 'item-7',
          name: 'وجبة صدور دجاج مشوي مع أرز',
          requested: 60,
          issued: 60,
          unavailable: false,
        ),
        BranchOrderItem(
          id: 'item-8',
          name: 'ساندوتش فاهيتا بروتينية',
          requested: 35,
          issued: 35,
          unavailable: false,
        ),
      ],
    ),
  ];
}
