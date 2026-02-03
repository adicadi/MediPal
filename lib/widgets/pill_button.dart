import 'package:flutter/material.dart';

class PillButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isSelected;

  const PillButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: textColor ??
                (isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onPrimaryContainer),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ??
              (isSelected ? colorScheme.primary : colorScheme.primaryContainer),
          foregroundColor: textColor ??
              (isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onPrimaryContainer),
          elevation: isSelected ? 4 : 2,
          shadowColor: isSelected
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.shadow.withValues(alpha: 0.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          animationDuration: const Duration(milliseconds: 200),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.hovered)) {
                return colorScheme.primary.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed)) {
                return colorScheme.primary.withValues(alpha: 0.12);
              }
              return null;
            },
          ),
        ),
      ),
    );
  }
}
