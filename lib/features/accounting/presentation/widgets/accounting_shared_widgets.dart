import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Shared widgets used across all accounting screens
// ══════════════════════════════════════════════════════════════════════════════

class AccKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  const AccKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: iconColor),
            const Spacer(),
          ]),
          const SizedBox(height: 10),
          Text(value,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(title,
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11, color: const Color(0xFF8A92A3))),
        ]),
      ),
    );
  }
}

class AccSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const AccSectionCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141720),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2430)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text(title,
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        const Divider(color: Color(0xFF1E2430), height: 1),
        Padding(padding: const EdgeInsets.all(12), child: child),
      ]),
    );
  }
}

class AccActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const AccActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class AccErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const AccErrorWidget({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFFF6B6B)),
        const SizedBox(height: 12),
        Text('حدث خطأ',
            style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 6),
        Text(message,
            style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12, color: const Color(0xFF8A92A3))),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: const Color(0xFF1A1200),
          ),
        ),
      ]),
    );
  }
}

class AccTableHeader extends StatelessWidget {
  final String text;
  const AccTableHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(text,
            style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8A92A3))),
      );
}

class AccTableCell extends StatelessWidget {
  final String text;
  final bool isName;
  final Color? color;
  final bool small;
  const AccTableCell(this.text,
      {super.key, this.isName = false, this.color, this.small = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(text,
            style: GoogleFonts.ibmPlexSansArabic(
                fontSize: small ? 11 : 12,
                fontWeight: isName ? FontWeight.w600 : FontWeight.normal,
                color: color ?? Colors.white)),
      );
}

class AccDlgField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController ctrl;
  final bool isNumber;
  final bool readOnly;
  final int maxLines;
  const AccDlgField(
    this.label, {
    super.key,
    required this.hint,
    required this.ctrl,
    this.isNumber = false,
    this.readOnly = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11, color: const Color(0xFF8A92A3))),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8A92A3)),
          filled: true,
          fillColor: const Color(0xFF141720),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide.none),
        ),
      ),
    ]);
  }
}
