import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/app_date_time.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../domain/request_list_item.dart';

/// Card widget to display a [RequestListItem] in the orders list screen.
class RequestListItemCard extends StatelessWidget {
  final RequestListItem item;
  final ValueChanged<int>? onTap;

  const RequestListItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final publicationText = item.publicationCount == 1
        ? '1 publicación'
        : '${item.publicationCount} publicaciones';
    final progressText =
        '$publicationText · ${item.quantityFulfilled} de ${item.quantityRequested} surtidas';

    return AppCard(
      key: Key('card_pedido_${item.requestId}'),
      onTap: onTap != null ? () => onTap!(item.requestId) : null,
      padding: AppSpacing.pAllMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Solicitante & 2. Estado del pedido
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  item.requesterName,
                  key: Key('text_solicitante_${item.requestId}'),
                  style: AppTypography.titleCard,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.hSpacerSm,
              AppStatusBadge.fromFulfillmentStatus(item.fulfillmentStatus),
            ],
          ),
          AppSpacing.vSpacerXs,
          // 3. Fecha
          Text(
            AppDateTime.formatShortDate(item.createdAt),
            key: Key('text_fecha_${item.requestId}'),
            style: AppTypography.bodySecondary,
          ),
          AppSpacing.vSpacerMd,
          // 4. Progreso de cantidades, 5. Número de publicaciones & 6. ID del pedido
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  progressText,
                  key: Key('text_progreso_${item.requestId}'),
                  style: AppTypography.bodyNormal.copyWith(fontSize: 13.0),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.hSpacerSm,
              Text(
                'Pedido #${item.requestId}',
                key: Key('text_id_pedido_${item.requestId}'),
                style: AppTypography.bodySecondary.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
