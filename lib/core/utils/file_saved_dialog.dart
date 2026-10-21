import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// يعرض نافذة صغيرة (Dialog) بنجاح حفظ الملف
/// ويوفر أزرار لفتح الملف، فتح المجلد، ونسخ المسار.
void showFileSavedDialog(BuildContext context, String filePath) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => _FileSavedDialog(filePath: filePath),
  );
}

class _FileSavedDialog extends StatelessWidget {
  final String filePath;

  const _FileSavedDialog({required this.filePath});

  Future<void> _openFolder(BuildContext context) async {
    try {
      final pathWithBackslashes = filePath.replaceAll('/', '\\');
      await Process.run('explorer.exe', ['/select,', pathWithBackslashes]);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر فتح المجلد',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onPrimary),
            ),
            backgroundColor: AppColors.statusRed,
          ),
        );
      }
    }
  }

  Future<void> _openFile(BuildContext context) async {
    try {
      await Process.run('cmd', ['/c', 'start', '', filePath]);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر فتح الملف',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onPrimary),
            ),
            backgroundColor: AppColors.statusRed,
          ),
        );
      }
    }
  }

  void _copyPath(BuildContext context) {
    Clipboard.setData(ClipboardData(text: filePath));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ المسار',
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onPrimary),
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.statusGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'تم حفظ الملف بنجاح',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        filePath,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'نسخ المسار',
                      child: IconButton(
                        icon: const Icon(
                          Icons.copy,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        onPressed: () => _copyPath(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'إغلاق',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerHigh,
                      foregroundColor: AppColors.onSurface,
                    ),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(
                      'فتح المجلد',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () => _openFolder(context),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                    icon: const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 18,
                    ),
                    label: Text(
                      'فتح الملف',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _openFile(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
