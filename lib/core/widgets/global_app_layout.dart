import 'package:flutter/material.dart';

import 'pos_session_info_row.dart';
import 'pos_status_footer.dart';
import 'pos_window_title_row.dart';

/// مخطط عام يشمل البار العلوي (شريط العنوان + معلومات الجلسة) والفوتر السفلي.
/// يمكن استخدامه لتغليف أي صفحة رئيسية في التطبيق (الكاشير، المخزون، الحسابات، شؤون الموظفين، الخ)
/// لضمان توحيد التصميم.
///
/// [onRefresh] — اختياري، إذا تم تمريره يظهر زر ريفريش في شريط الجلسة العلوي.
class GlobalAppLayout extends StatelessWidget {
  final Widget child;

  /// عند تمريره يظهر زر Refresh في شريط الجلسة.
  final Future<void> Function()? onRefresh;

  const GlobalAppLayout({super.key, required this.child, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PosWindowTitleRow(),
        PosSessionInfoRow(onRefresh: onRefresh),
        Expanded(child: child),
        const PosStatusFooter(),
      ],
    );
  }
}
