import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/raw_material.dart';

class EditStockDialog extends StatefulWidget {
  final RawMaterial item;
  final ValueChanged<double> onSave;

  const EditStockDialog({super.key, required this.item, required this.onSave});

  @override
  State<EditStockDialog> createState() => _EditStockDialogState();
}

class _EditStockDialogState extends State<EditStockDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.stock.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim()) ?? 0;
    widget.onSave(value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text(
          'تعديل رصيد ${widget.item.name}',
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
        ),
        content: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
          decoration: InputDecoration(
            labelText: 'الرصيد الجديد (${widget.item.unit})',
            labelStyle: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurfaceVariant,
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
          autofocus: true,
          onSubmitted: (_) => _save(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(
              'حفظ',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
