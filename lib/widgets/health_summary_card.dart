import 'package:flutter/material.dart';

class HealthSummaryCard extends StatelessWidget {
  final String title;
  final String content;
  final String? subtitle;
  final IconData icon;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool isLoading;

  const HealthSummaryCard({
    super.key,
    required this.title,
    required this.content,
    this.subtitle,
    required this.icon,
    this.backgroundColor,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBackground = backgroundColor == null
        ? (isDark
            ? colorScheme.surfaceContainerLow.withValues(alpha: 0.94)
            : colorScheme.surfaceContainer.withValues(alpha: 0.72))
        : Color.alphaBlend(
            backgroundColor!.withValues(alpha: isDark ? 0.18 : 0.42),
            isDark
                ? colorScheme.surfaceContainerLow
                : colorScheme.surfaceContainer,
          );
    final iconTint = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.14),
      colorScheme.surface,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
                  colorScheme.surfaceContainer.withValues(alpha: 0.93),
                ]
              : [
                  colorScheme.surface.withValues(alpha: 0.98),
                  colorScheme.surfaceContainerLow.withValues(alpha: 0.95),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF060D22).withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isDark ? 14 : 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: iconTint,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.32),
                          width: 1.3,
                        ),
                      ),
                      child: isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                          : Icon(
                              icon,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onTap != null && !isLoading)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (subtitle != null && subtitle!.isNotEmpty && !isLoading) ...[
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                ] else
                  const SizedBox(height: 4),
                Text(
                  isLoading ? 'Loading...' : content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.92),
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom widget for status indicators
class HealthStatusCard extends StatelessWidget {
  final String title;
  final String value;
  final String? trend;
  final IconData icon;
  final Color statusColor;
  final VoidCallback? onTap;

  const HealthStatusCard({
    super.key,
    required this.title,
    required this.value,
    this.trend,
    required this.icon,
    required this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              if (trend != null) ...[
                const SizedBox(height: 4),
                Text(
                  trend!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
