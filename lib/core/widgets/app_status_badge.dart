import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppStatus {
  pendiente,
  parcialmenteSurtido,
  surtido,
  error,
}

class AppStatusBadge extends StatelessWidget {
  final AppStatus status;
  final String? label;

  const AppStatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  // Factory constructor for string mapping
  factory AppStatusBadge.fromString(String statusStr, {String? label}) {
    final cleanStr = statusStr.trim().toLowerCase();
    AppStatus resolvedStatus = AppStatus.pendiente;
    
    if (cleanStr.contains('parcialmente') || cleanStr.contains('parcial')) {
      resolvedStatus = AppStatus.parcialmenteSurtido;
    } else if (cleanStr.contains('surtido') || cleanStr.contains('completado')) {
      resolvedStatus = AppStatus.surtido;
    } else if (cleanStr.contains('error') || cleanStr.contains('cancelado')) {
      resolvedStatus = AppStatus.error;
    }

    return AppStatusBadge(status: resolvedStatus, label: label);
  }

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData iconData;
    String displayLabel;

    switch (status) {
      case AppStatus.pendiente:
        backgroundColor = AppColors.infoLight;
        textColor = AppColors.info;
        iconData = Icons.access_time_rounded;
        displayLabel = label ?? 'Pendiente';
        break;
      case AppStatus.parcialmenteSurtido:
        backgroundColor = AppColors.warningLight;
        textColor = AppColors.warning;
        iconData = Icons.incomplete_circle_rounded;
        displayLabel = label ?? 'Parcialmente Surtido';
        break;
      case AppStatus.surtido:
        backgroundColor = AppColors.successLight;
        textColor = AppColors.success;
        iconData = Icons.check_circle_rounded;
        displayLabel = label ?? 'Surtido';
        break;
      case AppStatus.error:
        backgroundColor = AppColors.errorLight;
        textColor = AppColors.error;
        iconData = Icons.cancel_rounded;
        displayLabel = label ?? 'Cancelado';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.0),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 14.0,
            color: textColor,
          ),
          AppSpacing.hSpacerXs,
          Text(
            displayLabel,
            style: AppTypography.badgeText.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
