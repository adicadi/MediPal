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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor ??
                      colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(
                        icon,
                        color: colorScheme.primary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLoading ? 'Loading...' : content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && !isLoading) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing icon
              if (onTap != null && !isLoading)
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 20,
                ),
            ],
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
