import 'package:flutter/material.dart';

enum AppModule { cashier, accounts, inventory, hr }

enum AppRole {
  owner,
  branchManager,
  cashier,
  accountant,
  storekeeper,
  hr,
  blocked,
}

AppRole roleFromText(String? value) => switch (value) {
  'owner' => AppRole.owner,
  'branch_manager' => AppRole.branchManager,
  'cashier' => AppRole.cashier,
  'accountant' => AppRole.accountant,
  'storekeeper' => AppRole.storekeeper,
  'hr' => AppRole.hr,
  _ => AppRole.blocked,
};

String roleToText(AppRole role) => switch (role) {
  AppRole.owner => 'owner',
  AppRole.branchManager => 'branch_manager',
  AppRole.cashier => 'cashier',
  AppRole.accountant => 'accountant',
  AppRole.storekeeper => 'storekeeper',
  AppRole.hr => 'hr',
  AppRole.blocked => '',
};

List<AppModule> allowedModules(AppRole role) => switch (role) {
  AppRole.owner || AppRole.branchManager => AppModule.values,
  AppRole.cashier => const [AppModule.cashier],
  AppRole.accountant => const [AppModule.accounts],
  AppRole.storekeeper => const [AppModule.inventory],
  AppRole.hr => const [AppModule.hr],
  AppRole.blocked => const [],
};

bool requiresBranch(AppModule module) => module == AppModule.cashier;

extension AppModuleExtension on AppModule {
  String get arabicName => switch (this) {
    AppModule.cashier => 'كاشير',
    AppModule.accounts => 'حسابات',
    AppModule.inventory => 'مخزون',
    AppModule.hr => 'موارد بشرية',
  };

  IconData get icon => switch (this) {
    AppModule.cashier => Icons.point_of_sale,
    AppModule.accounts => Icons.receipt_long,
    AppModule.inventory => Icons.inventory_2,
    AppModule.hr => Icons.badge,
  };

  bool get isImplemented =>
      this == AppModule.cashier ||
      this == AppModule.inventory ||
      this == AppModule.hr;
}
