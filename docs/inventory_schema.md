# مخطط قاعدة بيانات المخزون — Diet King

## ملخص التصميم

### ERD النصي

```
inventory_units (code PK)
    ↑ unit_code
inventory_categories (id PK, code UNIQUE)
    ↑ category_id
inventory_items (id PK, sku UNIQUE)
    ↓ item_id        ↓ item_id         ↓ item_id
inventory_stock      inventory_movements  supply_order_lines
(warehouse_id FK,    (id bigint identity, (order_id FK,
 item_id FK, PK)      immutable)          item_id FK)
    ↑ warehouse_id                            ↑ order_id
warehouses (id PK)                      supply_orders (id PK)
    ↑ branch_id                               ↑ supplier_id
branches (id PK)                        suppliers (id PK)

kitchen_issues → kitchen_issue_lines → inventory_items
kitchen_batches                       → inventory_items (FIN)
stocktakes      → stocktake_lines     → inventory_items
branch_orders   → branch_order_lines  → inventory_items
                                      → branches

notifications → notification_reads
data_versions (key PK)
doc_counters  (doc_type + scope PK)
admin_approvals
inventory_imports
```

---

## الجداول

### 1. `inventory_units`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `code` | text PK | كجم / جرام / لتر / ... |
| `label` | text | الاسم العربي |
| `sort_order` | int | ترتيب العرض |

**Seed:** 12 وحدة (كجم، جرام، لتر، مل، عبوة، كرتونة، قطعة، علبة، كيس، زجاجة، دستة، رول)

---

### 2. `inventory_categories`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | معرّف فريد |
| `code` | text UNIQUE | 2-4 حروف لاتينية كبيرة (PRT, VEG, ...) |
| `name` | text UNIQUE | الاسم العربي |
| `kind` | text | `raw` خامة / `supply` مستلزمات / `finished` منتج تام |
| `is_system` | boolean | التصنيفات النظامية لا تُعدَّل (FIN مثلاً) |
| `is_active` | boolean | — |
| `sort_order` | int | — |

**Seed:** PRT · VEG · BEV · OIL · SPY · CRB · DAI · CLN · BRN · PKG · FIN(نظامي)

---

### 3. `inventory_items`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | المعرّف الرئيسي في الواجهة |
| `sku` | text UNIQUE | 3-30 حرف، حروف لاتينية وأرقام و- و_ |
| `name` | text | فريد case-insensitive بين النشطة |
| `category_id` | uuid FK | التصنيف |
| `unit_code` | text FK | وحدة القياس |
| `min_level` | numeric(14,3) | الحد الأدنى للتنبيه |
| `avg_cost` | numeric(14,4) | متوسط تكلفة مرجّح — يُحدَّث تلقائياً |
| `branch_orderable` | boolean | يظهر في كتالوج طلبيات الفروع |
| `is_active` | boolean | — |
| `low_stock_alerted` | boolean | true بعد إرسال إشعار الحد الأدنى |
| `linked_product_id` | uuid FK? | ربط مستقبلي بـ products (الوصفات) |
| `version` | bigint | للتحكم في التزامن |

**فهارس:** category_id، (is_active, branch_orderable)، partial unique على lower(name) للنشطة

---

### 4. `warehouses`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | — |
| `name` | text | — |
| `kind` | text | `main` أو `branch` |
| `branch_id` | uuid FK? | null للرئيسي |
| `is_active` | boolean | — |

**قيود:** مستودع رئيسي واحد فقط (partial unique index)، مستودع واحد لكل فرع

---

### 5. `inventory_stock`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `warehouse_id` | uuid FK | — |
| `item_id` | uuid FK | — |
| `quantity` | numeric(14,3) ≥ 0 | الرصيد الحالي — لا يقل عن صفر |
| `updated_at` | timestamptz | — |

**PK مركّب:** (warehouse_id, item_id) — **يُكتب فقط عبر `_post_movement`**

---

### 6. `inventory_movements` *(immutable)*
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | bigint identity PK | — |
| `occurred_at` | timestamptz | — |
| `warehouse_id` | uuid FK | — |
| `item_id` | uuid FK | — |
| `movement_type` | text | انظر الجدول أدناه |
| `qty_delta` | numeric(14,3) | موجب = إضافة، سالب = خصم |
| `unit_cost` | numeric(14,4) | لقطة التكلفة وقت الحركة |
| `balance_after` | numeric(14,3) | الرصيد بعد الحركة (للتدقيق) |
| `ref_type` | text? | نوع المستند المرجعي |
| `ref_id` | uuid? | معرّف المستند المرجعي |
| `note` | text? | — |
| `created_by` | uuid FK | — |

**Trigger:** يمنع UPDATE و DELETE — لا تُعدَّل الحركات أبداً

**أنواع الحركات:**
| النوع | الاتجاه | المصدر |
|-------|---------|--------|
| `opening` | + | استيراد Excel (رصيد افتتاحي) |
| `supply_receipt` | + | استلام طلب توريد |
| `kitchen_issue` | − | صرف خامات للمطبخ |
| `kitchen_output` | + | استلام إنتاج المطبخ (منتج تام) |
| `branch_transfer_out` | − | تحويل للفرع (من الرئيسي) |
| `branch_transfer_in` | + | تحويل للفرع (في مستودع الفرع) |
| `damage` | − | تالف مُسجَّل في الجرد |
| `stocktake_adjust` | ± | تعديل جرد (فرق صافٍ) |

---

### 7. `suppliers`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | — |
| `name` | text UNIQUE (case-insensitive) | — |
| `phone` | text? | — |
| `is_active` | boolean | — |

---

### 8. `supply_orders`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | — |
| `number` | text UNIQUE | PO-YYYY-NNNN |
| `client_id` | uuid UNIQUE | للـ idempotency |
| `supplier_id` | uuid FK | — |
| `expected_date` | date | — |
| `priority` | text | `urgent` / `normal` |
| `status` | text | pending_review → approved → received / rejected / cancelled |
| `rejection_reason` | text? | إجباري عند الرفض |
| `has_issues` | boolean | استلام بملاحظات أو فروق |
| `version` | bigint | للتحكم في التزامن |

### 9. `supply_order_lines`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `order_id` | uuid FK | — |
| `item_id` | uuid FK | — |
| `qty_requested` | numeric(14,3) | الكمية المطلوبة |
| `qty_approved` | numeric(14,3)? | المعتمدة من المحاسب |
| `qty_received` | numeric(14,3)? | المستلمة فعلياً |
| `unit_cost` | numeric(12,2) | التكلفة للوحدة |

---

### 10. `kitchen_issues`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | — |
| `number` | text UNIQUE | ISSUE-YYYY-NNNN |
| `client_id` | uuid UNIQUE | — |
| `cook_plan` | text? | خطة الطهي |
| `chef_name` | text | اسم الشيف المستلم |
| `shift` | text | `morning` / `evening` |

### 11. `kitchen_issue_lines`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `issue_id` | uuid FK | — |
| `item_id` | uuid FK | — |
| `qty` | numeric(14,3) | — |
| `unit_cost_snapshot` | numeric(14,4) | avg_cost وقت الصرف (لتقارير التكلفة) |

---

### 12. `kitchen_batches`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | — |
| `number` | text UNIQUE | BATCH-YYYY-MMDD-NNNN |
| `client_id` | uuid UNIQUE | — |
| `item_id` | uuid FK | الصنف التام (تصنيف FIN) |
| `quantity` | numeric(14,3) | عدد الوجبات/الوحدات |
| `produced_at` | timestamptz | — |
| `finished_at` | timestamptz ≥ produced_at | — |
| `quality_note` | text? | ملاحظة الجودة |

---

### 13. `stocktakes`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | — |
| `number` | text UNIQUE | STK-YYYY-NNNN |
| `client_id` | uuid UNIQUE | — |
| `warehouse_id` | uuid FK | — |
| `total_items` | int | عدد الأصناف المجردة |
| `total_adjust` | numeric(14,3) | مجموع التعديلات |
| `total_damage` | numeric(14,3) | مجموع التالف |

### 14. `stocktake_lines`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `stocktake_id` | uuid FK | — |
| `item_id` | uuid FK | — |
| `system_qty` | numeric(14,3) | رصيد النظام وقت التطبيق |
| `counted_qty` | numeric(14,3) ≥ 0 | الكمية المعدودة الصالحة |
| `damaged_qty` | numeric(14,3) ≥ 0 | الكمية التالفة |
| `adjust_qty` | numeric(14,3) | = counted − (system − damaged) |
| `unit_cost` | numeric(14,4) | لقطة avg_cost وقت الجرد |

---

### 15. `branch_orders`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | — |
| `number` | text UNIQUE | BO-<كود_الفرع>-NNNNNN |
| `client_id` | uuid UNIQUE | — |
| `branch_id` | uuid FK | — |
| `status` | text | submitted → approved / rejected / cancelled |
| `rejection_reason` | text? | — |
| `version` | bigint | للتحكم في التزامن (الفرع قد يعدّل الطلب) |

### 16. `branch_order_lines`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `order_id` | uuid FK | — |
| `item_id` | uuid FK | — |
| `qty_requested` | numeric(14,3) | — |
| `qty_approved` | numeric(14,3)? | ≤ qty_requested |

---

### 17. `notifications`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | — |
| `kind` | text | نوع الحدث (7 أنواع) |
| `audience` | text[] | `accounting` / `warehouse` / `branch` |
| `branch_id` | uuid FK? | للإشعارات الخاصة بفرع |
| `title` | text | — |
| `body` | text | — |
| `payload` | jsonb | ref_type, ref_id, domains, ملخص الكميات |

### 18. `notification_reads`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `user_id` | uuid FK | — |
| `notification_id` | uuid FK | — |
| `read_at` | timestamptz | — |

---

### 19. `data_versions`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `key` | text PK | inv_catalog / inv_stock / inv_supply / inv_kitchen / inv_stocktake / branch_orders:<branch_id> / branch_stock:<branch_id> |
| `version` | bigint | يتزايد ذرياً عند كل تغيير |
| `updated_at` | timestamptz | — |

---

### 20. `doc_counters`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `doc_type` | text | po / bo / issue / batch / stk / import / fin_sku / item_sku |
| `scope` | text | السنة، أو السنة:كود_الفرع |
| `last_number` | int | آخر رقم صدر |

---

### 21. `admin_approvals`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | — |
| `token` | uuid UNIQUE | يُرسل للتطبيق |
| `user_id` | uuid FK | — |
| `action` | text | `inventory_import` / `inventory_stocktake` |
| `expires_at` | timestamptz | بعد 10 دقائق من الإصدار |
| `used_at` | timestamptz? | بعد الاستخدام: لا يُقبل مرة ثانية |

---

### 22. `inventory_imports`
| العمود | النوع | الوصف |
|--------|-------|-------|
| `id` | uuid PK | — |
| `number` | text UNIQUE | IMPORT-YYYY-NNNN |
| `client_id` | uuid UNIQUE | — |
| `imported_by` | uuid FK | — |
| `summary` | jsonb | {new, updated, errors} |
| `result` | text | `success` / `failed` |

---

## تدفق العمليات

### أ) استيراد الأصناف من Excel

```
التطبيق
  ├─ admin_issue_approval(password, 'inventory_import') → token
  ├─ import_inventory_items(client_id, token, dry_run=true, rows) → معاينة
  └─ import_inventory_items(client_id, token, dry_run=false, rows)
       ├─ تحقق من التصريح
       ├─ لكل صنف جديد:
       │    ├─ INSERT inventory_items
       │    └─ _post_movement('opening', +qty, unit_cost) → inventory_stock + inventory_movements
       ├─ لكل صنف موجود: UPDATE inventory_items
       ├─ INSERT inventory_imports
       ├─ UPDATE admin_approvals (used_at)
       └─ _bump_data_version(inv_catalog, inv_stock)
```

### ب) دورة طلب التوريد

```
أمين المخزن → create_supply_order
  ├─ INSERT supply_orders (pending_review)
  ├─ INSERT supply_order_lines
  ├─ _notify(supply_submitted → accounting)
  └─ _bump_data_version(inv_supply)

المحاسب → review_supply_order
  ├─ تحقق من version (التزامن)
  ├─ UPDATE supply_order_lines (qty_approved, unit_cost)
  ├─ UPDATE supply_orders (approved / rejected)
  ├─ لو approved: _notify(supply_approved → warehouse)
  └─ _bump_data_version(inv_supply)

أمين المخزن → receive_supply_order
  ├─ تحقق من version
  ├─ UPDATE supply_order_lines (qty_received)
  ├─ لكل سطر qty_received > 0:
  │    └─ _post_movement('supply_receipt', +qty, unit_cost)
  │         ├─ UPDATE inventory_stock (+qty)
  │         ├─ INSERT inventory_movements
  │         └─ UPDATE avg_cost (متوسط مرجّح)
  ├─ UPDATE supply_orders (received, has_issues)
  ├─ لو has_issues: _notify(supply_received_issues → accounting)
  └─ _bump_data_version(inv_supply, inv_stock, inv_catalog)
```

### ج) صرف المطبخ

```
أمين المخزن → create_kitchen_issue
  ├─ INSERT kitchen_issues
  ├─ لكل سطر (في نفس المعاملة):
  │    ├─ لقط unit_cost_snapshot = avg_cost الحالي
  │    ├─ INSERT kitchen_issue_lines
  │    └─ _post_movement('kitchen_issue', -qty, unit_cost_snapshot)
  │         ├─ لو qty > رصيد: RAISE EXCEPTION (يفشل كل العملية)
  │         └─ UPDATE inventory_stock (-qty)
  └─ _bump_data_version(inv_kitchen, inv_stock)
```

### د) استلام إنتاج المطبخ

```
أمين المخزن → create_kitchen_batch
  ├─ لو صنف جديد: INSERT inventory_items (FIN)
  ├─ INSERT kitchen_batches
  ├─ _post_movement('kitchen_output', +qty, 0)
  └─ _bump_data_version(inv_kitchen, inv_stock, inv_catalog)
```

### هـ) الجرد

```
التطبيق
  ├─ admin_issue_approval(password, 'inventory_stocktake') → token
  ├─ apply_stocktake(token, dry_run=true, lines) → معاينة الفروقات
  └─ apply_stocktake(token, dry_run=false, lines)
       ├─ لكل سطر (بقفل FOR UPDATE):
       │    ├─ لو damaged > 0: _post_movement('damage', -damaged)
       │    └─ لو adjust ≠ 0:  _post_movement('stocktake_adjust', ±adjust)
       ├─ INSERT stocktakes + stocktake_lines
       ├─ UPDATE admin_approvals (used_at)
       └─ _bump_data_version(inv_stocktake, inv_stock)
```

### و) طلب الفرع

```
الكاشير → create_branch_order
  ├─ INSERT branch_orders (submitted)
  ├─ INSERT branch_order_lines
  ├─ _notify(branch_order_submitted → accounting + warehouse)
  └─ _bump_data_version(inv_supply, branch_orders:<branch_id>)

الكاشير → update_branch_order (submitted فقط)
  ├─ تحقق من version
  ├─ DELETE + INSERT branch_order_lines (استبدال كامل)
  └─ _notify(branch_order_updated → accounting + warehouse)

أمين المخزن → decide_branch_order
  ├─ تحقق من version (لو الفرع عدّل: رفض القرار)
  ├─ لو approved:
  │    ├─ UPDATE branch_order_lines (qty_approved)
  │    └─ لكل سطر qty_approved > 0 (في نفس المعاملة):
  │         ├─ _post_movement('branch_transfer_out', -qty) من الرئيسي
  │         └─ _post_movement('branch_transfer_in', +qty) لمستودع الفرع
  ├─ UPDATE branch_orders (approved / rejected)
  ├─ _notify(branch_order_decided → branch, payload يحمل الكميات)
  └─ _bump_data_version(inv_supply, inv_stock, branch_orders:<branch_id>, branch_stock:<branch_id>)
```

### ز) فحص الحد الأدنى (داخل _post_movement)

```
بعد كل تغيير رصيد في المستودع الرئيسي:
  ├─ لو qty_جديد ≤ min_level AND min_level > 0 AND NOT low_stock_alerted:
  │    ├─ _notify('low_stock' → accounting + warehouse)
  │    └─ UPDATE inventory_items SET low_stock_alerted = true
  └─ لو qty_جديد > min_level AND low_stock_alerted:
       └─ UPDATE inventory_items SET low_stock_alerted = false (إعادة الراية)
```

---

## نموذج متوسط التكلفة المرجّح (Weighted Average Cost)

```
avg_cost_جديد = (avg_cost_قديم × إجمالي_الرصيد_قبل_الإضافة + unit_cost × qty_delta)
                / إجمالي_الرصيد_الجديد_في_كل_المخازن

مثال:
  رصيد حالي (كل المخازن) = 200 كجم
  avg_cost = 45.00 ريال/كجم
  استلام جديد = 100 كجم بسعر 48.00 ريال/كجم

  avg_cost_جديد = (45.00 × 200 + 48.00 × 100) / 300
               = (9000 + 4800) / 300
               = 46.00 ريال/كجم
```

---

## كيف يتحول كل مستند لقيد محاسبي (مستقبلاً)

> القيود المحاسبية لم تُنفَّذ بعد. هذا القسم توثيق للربط المستقبلي مع وحدة الحسابات.

### 1. استلام توريد (supply_receipt)
```
حـ/ المخزون (asset)              +  qty × unit_cost
    إلى حـ/ الموردين (liability)  +  qty × unit_cost
```
*المرجع: supply_order.id — السطور تعطي تفاصيل كل صنف*

### 2. صرف خامات للمطبخ (kitchen_issue)
```
حـ/ تكلفة البضاعة المباعة / تكلفة الإنتاج   +  qty × unit_cost_snapshot
    إلى حـ/ المخزون (asset)                   -  qty × unit_cost_snapshot
```
*unit_cost_snapshot مخزون في kitchen_issue_lines لثبات الأرقام التاريخية*

### 3. تالف في الجرد (damage)
```
حـ/ خسائر تالف المخزون (expense)   +  qty × unit_cost
    إلى حـ/ المخزون (asset)          -  qty × unit_cost
```

### 4. فرق الجرد (stocktake_adjust)
```
لو سالب (عجز):
  حـ/ عجز مخزون (expense)           +  |adjust| × unit_cost
      إلى حـ/ المخزون (asset)        -  |adjust| × unit_cost

لو موجب (فائض):
  حـ/ المخزون (asset)               +  adjust × unit_cost
      إلى حـ/ فائض مخزون (income)   +  adjust × unit_cost
```

### 5. تحويل للفرع (branch_transfer)
```
حـ/ مخزون الفرع (asset)            +  qty × avg_cost
    إلى حـ/ مخزون الرئيسي (asset)   -  qty × avg_cost
```
*تحويل داخلي — لا يُغيِّر إجمالي قيمة المخزون، فقط يُعيد توزيعه*

### 6. إنتاج المطبخ (kitchen_output)
```
حـ/ مخزون المنتجات التامة (asset)  +  qty × (avg_cost_خامات_مستخدمة)
    إلى حـ/ مخزون الخامات (asset)   -  (يُحسب من kitchen_issue المرتبط)
```
*الربط الكامل يتطلب وصفات (recipes) — مخطط له مستقبلاً*

---

## Views التقارير

| View | الوصف |
|------|-------|
| `v_stock_valuation` | الكمية × avg_cost لكل صنف ومستودع |
| `v_low_stock` | الأصناف تحت الحد الأدنى بالكميات والقيم |
| `v_kitchen_consumption_daily` | الاستهلاك اليومي بالكمية والتكلفة |
| `v_supply_orders_summary` | إجماليات التوريد لكل مورد وشهر |
| `v_branch_order_fulfillment` | نسبة التلبية لكل فرع وصنف وشهر |
| `v_stocktake_losses` | التالف والعجز والفائض بالقيمة |
| `v_movements_daily` | الحركات اليومية مُلخَّصة |

جميعها `security_invoker = true` → تعمل بصلاحيات المستخدم (RLS مُطبَّق).

---

## مصفوفة الصلاحيات

| العملية | owner | storekeeper | accountant | cashier/branch_manager |
|---------|:-----:|:-----------:|:----------:|:----------------------:|
| استيراد الأصناف | ✓ | ✓ | — | — |
| جرد Excel | ✓ | ✓ | — | — |
| إنشاء/إلغاء طلب توريد | ✓ | ✓ | — | — |
| مراجعة طلب التوريد | ✓ | — | ✓ | — |
| استلام التوريد | ✓ | ✓ | — | — |
| صرف المطبخ | ✓ | ✓ | — | — |
| استلام إنتاج المطبخ | ✓ | ✓ | — | — |
| إنشاء/تعديل/إلغاء طلب فرع | ✓ | — | — | ✓ |
| قرار طلب الفرع | ✓ | ✓ | — | — |
| قراءة المستودع الرئيسي | ✓ | ✓ | ✓ | — |
| قراءة مستودع الفرع | ✓ | ✓ | ✓ | ✓ (فرعه فقط) |
| تدقيق الأرصدة | ✓ | — | ✓ | — |

---

## ترتيب تشغيل ملفات SQL

```
01_foundation.sql   ← دوال مساعدة + data_versions + doc_counters + admin_approvals
02_catalog.sql      ← inventory_units + inventory_categories + inventory_items + suppliers
03_stock_core.sql   ← warehouses + inventory_stock + inventory_movements + _post_movement
04_documents.sql    ← كل المستندات والـ RPCs
05_notifications.sql ← notifications + notification_reads + Realtime
06_views.sql        ← Views التقارير
07_security.sql     ← RLS + GRANT/REVOKE
99_smoke_test.sql   ← اختبار شامل (begin...rollback)
```

> **ملاحظة:** `02_catalog.sql` يعتمد على trigger `set_updated_at` و `bump_version` الموجودَين في Supabase.
> تأكد من وجودهما قبل التشغيل.
