import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

class PanelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool isHoverable;
  final VoidCallback? onTap;

  const PanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.spaceLg),
    this.isHoverable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );

    if (isHoverable || onTap != null) {
      return _HoverablePanelCard(onTap: onTap, child: card);
    }

    return card;
  }
}

class _HoverablePanelCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverablePanelCard({required this.child, this.onTap});

  @override
  State<_HoverablePanelCard> createState() => _HoverablePanelCardState();
}

class _HoverablePanelCardState extends State<_HoverablePanelCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
