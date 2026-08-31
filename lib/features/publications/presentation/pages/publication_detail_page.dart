import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../domain/publication.dart';
import '../../domain/tri_state_value.dart';

class PublicationDetailPage extends StatelessWidget {
  final Publication publication;

  const PublicationDetailPage({
    super.key,
    required this.publication,
  });

  String _formatTriState(TriStateValue triState) {
    if (triState.isSinDefinir) return 'Sin definir';
    if (triState.isNoAplica) return 'No aplica';
    return triState.value?.toString() ?? 'Sin definir';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySecondary.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.vSpacerXs,
          Text(
            value,
            style: AppTypography.bodyNormal.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayCode =
        (publication.code != null && publication.code!.trim().isNotEmpty)
            ? publication.code!.trim()
            : '-Sin código-';

    final displayDescription = (publication.description != null &&
            publication.description!.trim().isNotEmpty)
        ? publication.description!.trim()
        : 'Sin descripción';

    final displayType =
        (publication.type != null && publication.type!.trim().isNotEmpty)
            ? publication.type!.trim()
            : 'Sin definir';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Publicación'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pAllMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              publication.name,
                              style: AppTypography.titlePrimary,
                            ),
                            AppSpacing.vSpacerXs,
                            Text(
                              displayCode,
                              style: AppTypography.bodySecondary.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.hSpacerSm,
                      AppStatusBadge.fromString(publication.status.name),
                    ],
                  ),
                  AppSpacing.vSpacerMd,
                  const Divider(),
                  AppSpacing.vSpacerSm,
                  _buildDetailRow('Descripción', displayDescription),
                  const Divider(),
                  AppSpacing.vSpacerSm,
                  _buildDetailRow('Tipo de publicación', displayType),
                  const Divider(),
                  AppSpacing.vSpacerSm,
                  _buildDetailRow('Tamaño', _formatTriState(publication.size)),
                  const Divider(),
                  AppSpacing.vSpacerSm,
                  _buildDetailRow(
                      'Versión', _formatTriState(publication.version)),
                  const Divider(),
                  AppSpacing.vSpacerSm,
                  _buildDetailRow(
                    'Estado en el sistema',
                    publication.isActive ? 'Sí (Activa)' : 'No (Inactiva)',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
