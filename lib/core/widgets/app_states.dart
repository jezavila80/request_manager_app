import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

class AppLoadingIndicator extends StatelessWidget {
  final String message;

  const AppLoadingIndicator({
    super.key,
    this.message = 'Cargando datos...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pAllLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
            AppSpacing.vSpacerMd,
            Text(
              message,
              style: AppTypography.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const AppEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pAllLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64.0,
              color: AppColors.textDisabled,
            ),
            AppSpacing.vSpacerMd,
            Text(
              message,
              style: AppTypography.bodyNormal.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onActionPressed != null) ...[
              AppSpacing.vSpacerLg,
              AppPrimaryButton(
                text: actionLabel!,
                onPressed: onActionPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onRetryPressed;

  const AppErrorState({
    super.key,
    this.message = 'Ha ocurrido un error al cargar la información.',
    this.actionLabel = 'Reintentar',
    required this.onRetryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pAllLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64.0,
              color: AppColors.error,
            ),
            AppSpacing.vSpacerMd,
            Text(
              message,
              style: AppTypography.bodyNormal.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vSpacerLg,
            AppSecondaryButton(
              text: actionLabel,
              onPressed: onRetryPressed,
              icon: Icons.refresh_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
