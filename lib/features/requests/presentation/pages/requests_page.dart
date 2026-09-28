import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_states.dart';
import '../../data/repositories/request_repository_impl.dart';
import '../../domain/request_list_item.dart';
import '../../domain/request_repository.dart';
import '../widgets/request_list_item_card.dart';
import 'new_request_page.dart';

/// Screen displaying the list of requests/orders (Phase 2.8).
class RequestsPage extends StatefulWidget {
  final RequestRepository? repository;

  const RequestsPage({
    super.key,
    this.repository,
  });

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  late final RequestRepository _repository;

  bool _isLoading = true;
  String? _errorMessage;
  List<RequestListItem> _requests = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RequestRepositoryImpl();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _repository.getRequestList();
      if (mounted) {
        setState(() {
          _requests = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudieron cargar los pedidos.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToNewRequest() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NewRequestPage(),
      ),
    );
    if (result != null && mounted) {
      await _loadRequests();
    }
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const AppLoadingIndicator(
        message: 'Cargando pedidos...',
      );
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        actionLabel: 'Reintentar',
        onRetryPressed: _loadRequests,
      );
    }

    if (_requests.isEmpty) {
      return const AppEmptyState(
        message: 'No hay pedidos registrados.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        key: const Key('requests_list_view'),
        itemCount: _requests.length,
        separatorBuilder: (context, index) => AppSpacing.vSpacerSm,
        itemBuilder: (context, index) {
          final item = _requests[index];
          return RequestListItemCard(
            item: item,
            onTap: (requestId) {
              // Navigation to order detail will be implemented in Phase 2.9
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pAllMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Listado de Pedidos',
                  style: AppTypography.titleSection,
                ),
              ),
              AppPrimaryButton(
                key: const Key('btn_nuevo_pedido'),
                text: 'Nuevo Pedido',
                icon: Icons.add_rounded,
                onPressed: _navigateToNewRequest,
              ),
            ],
          ),
          AppSpacing.vSpacerMd,
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }
}
