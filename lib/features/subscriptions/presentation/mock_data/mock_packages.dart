import 'package:flutter/material.dart';

import '../models/subscription_package.dart';

// TODO: استبدل هذه القائمة ببيانات حقيقية من Supabase لاحقًا
final List<SubscriptionPackage> mockPackages = [
  SubscriptionPackage(
    id: 'cutting',
    name: 'التنشيف',
    subtitle: 'خسارة الدهون مع الحفاظ على العضلات',
    icon: Icons.local_fire_department_rounded,
    proteinLabel: '120 جم بروتين',
    footerNote: 'توازن مثالي للكارب والبروتين',
    durationMeals: {
      20: [
        MealOption(label: '2 وجبات', price: 800),
        MealOption(label: '3 وجبات', price: 1100),
        MealOption(label: '4 وجبات', price: 1400),
        MealOption(label: '5 وجبات', price: 1700),
      ],
      26: [
        MealOption(label: '2 وجبات', price: 1000),
        MealOption(label: '3 وجبات', price: 1400),
        MealOption(label: '4 وجبات', price: 1800),
        MealOption(label: '5 وجبات', price: 2200),
      ],
      30: [
        MealOption(label: '2 وجبات', price: 1100),
        MealOption(label: '3 وجبات', price: 1600),
        MealOption(label: '4 وجبات', price: 2100),
        MealOption(label: '5 وجبات', price: 2600),
      ],
    },
  ),
  SubscriptionPackage(
    id: 'athletes',
    name: 'الرياضيين',
    subtitle: 'للرياضيين المحترفين وبناة الأجسام',
    icon: Icons.fitness_center_rounded,
    proteinLabel: '150 جم بروتين',
    footerNote: 'أعلى طلب في الأسبوع',
    durationMeals: {
      20: [
        MealOption(label: '2 وجبات', price: 950),
        MealOption(label: '3 وجبات', price: 1250),
        MealOption(label: '4 وجبات', price: 1550),
        MealOption(label: '5 وجبات', price: 1850),
      ],
      26: [
        MealOption(label: '2 وجبات', price: 1200),
        MealOption(label: '3 وجبات', price: 1600),
        MealOption(label: '4 وجبات', price: 2000),
        MealOption(label: '5 وجبات', price: 2400),
      ],
      30: [
        MealOption(label: '2 وجبات', price: 1400),
        MealOption(label: '3 وجبات', price: 1850),
        MealOption(label: '4 وجبات', price: 2300),
        MealOption(label: '5 وجبات', price: 2750),
      ],
    },
  ),
  SubscriptionPackage(
    id: 'bulking',
    name: 'التضخيم',
    subtitle: 'زيادة الكتلة العضلية بكفاءة عالية',
    icon: Icons.trending_up_rounded,
    proteinLabel: '180 جم بروتين',
    footerNote: 'مثالي لمرحلة البناء العضلي',
    durationMeals: {
      20: [
        MealOption(label: '2 وجبات', price: 900),
        MealOption(label: '3 وجبات', price: 1200),
        MealOption(label: '4 وجبات', price: 1500),
        MealOption(label: '5 وجبات', price: 1800),
      ],
      26: [
        MealOption(label: '2 وجبات', price: 1150),
        MealOption(label: '3 وجبات', price: 1550),
        MealOption(label: '4 وجبات', price: 1950),
        MealOption(label: '5 وجبات', price: 2350),
      ],
      30: [
        MealOption(label: '2 وجبات', price: 1300),
        MealOption(label: '3 وجبات', price: 1750),
        MealOption(label: '4 وجبات', price: 2200),
        MealOption(label: '5 وجبات', price: 2650),
      ],
    },
  ),
];
