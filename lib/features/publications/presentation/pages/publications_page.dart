import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../data/publication_repository_impl.dart';
import '../../domain/publication.dart';
import '../../domain/publication_repository.dart';
import '../../domain/services/publication_catalog_search_service.dart';
import 'publication_detail_page.dart';

class PublicationsPage extends StatefulWidget {
  final PublicationRepository repository;
  final PublicationCatalogSearchService? searchService;

  PublicationsPage({
    super.key,
    PublicationRepository? repository,
    PublicationCatalogSearchService? searchService,
  })  : repository = repository ?? PublicationRepositoryImpl(),
        searchService = searchService ??
            PublicationCatalogSearchService(
              repository ?? PublicationRepositoryImpl(),
            );

  @override
  State<PublicationsPage> createState() => _PublicationsPageState();
}

class _PublicationsPageState extends State<PublicationsPage> {
  late final PublicationCatalogSearchService _searchService;
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounceTimer;
  int _searchRequestId = 0;

  bool _isLoading = true;
  String? _errorMessage;
  List<Publication> _publications = [];

  @override
  void initState() {
    super.initState();
    _searchService = widget.searchService ??
        PublicationCatalogSearchService(widget.repository);
    _loadPublications();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadPublications();
    });
  }

  Future<void> _loadPublications() async {
    final currentRequestId = ++_searchRequestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _searchService.search(_searchController.text);
      if (currentRequestId == _searchRequestId && mounted) {
        setState(() {
          _publications = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (currentRequestId == _searchRequestId && mounted) {
        setState(() {
          _errorMessage = 'No se pudieron cargar las publicaciones';
          _isLoading = false;
        });
      }
    }
  }

  String _buildSubtitle(Publication pub) {
    final codeText = (pub.code != null && pub.code!.trim().isNotEmpty)
        ? pub.code!.trim()
        : '-Sin código-';

    final hasType = pub.type != null && pub.type!.trim().isNotEmpty;
    if (hasType) {
      return '$codeText · ${pub.type!.trim()}';
    }
    return codeText;
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const AppLoadingIndicator(
        message: 'Cargando publicaciones...',
      );
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        actionLabel: 'Reintentar',
        onRetryPressed: _loadPublications,
      );
    }

    final query = _searchController.text.trim();

    if (_publications.isEmpty) {
      if (query.isEmpty) {
        return const AppEmptyState(
          message: 'Aún no hay publicaciones registradas',
          icon: Icons.menu_book_rounded,
        );
      } else {
        return AppEmptyState(
          message: 'No se encontraron publicaciones para "$query"',
          icon: Icons.search_off_rounded,
        );
      }
    }

    return ListView.separated(
      itemCount: _publications.length,
      separatorBuilder: (context, index) => AppSpacing.vSpacerSm,
      itemBuilder: (context, index) {
        final pub = _publications[index];
        final subtitle = _buildSubtitle(pub);

        return AppCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PublicationDetailPage(publication: pub),
              ),
            );
          },
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pub.name,
                      style: AppTypography.titleCard,
                    ),
                    AppSpacing.vSpacerXs,
                    Text(
                      subtitle,
                      style: AppTypography.bodySecondary.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.hSpacerSm,
              AppStatusBadge.fromString(pub.status.name),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pAllMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Publicaciones',
            style: AppTypography.titleSection,
          ),
          AppSpacing.vSpacerMd,
          AppFormField(
            labelText: 'Buscar publicación',
            hintText: 'Buscar por código o nombre',
            controller: _searchController,
            prefixIcon: Icons.search_rounded,
            onChanged: _onSearchChanged,
          ),
          AppSpacing.vSpacerLg,
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }
}
