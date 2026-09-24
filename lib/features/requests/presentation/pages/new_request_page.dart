import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../publications/data/publication_repository_impl.dart';
import '../../../publications/domain/publication.dart';
import '../../../publications/domain/publication_repository.dart';
import '../../../publications/domain/services/publication_catalog_search_service.dart';
import '../../../requesters/data/repositories/requester_repository_impl.dart';
import '../../../requesters/domain/requester.dart';
import '../../../requesters/domain/requester_repository.dart';
import '../../../requesters/domain/services/requester_duplicate_checker.dart';
import '../../../requesters/domain/services/requester_name_cleaner.dart';
import '../../data/repositories/request_repository_impl.dart';
import '../../domain/request.dart';
import '../../domain/request_repository.dart';
import '../../domain/usecases/add_publication_to_request_use_case.dart';
import '../../domain/usecases/create_request_use_case.dart';

class NewRequestPage extends StatefulWidget {
  final PublicationRepository publicationRepository;
  final PublicationCatalogSearchService? searchService;
  final AddPublicationToRequestUseCase? addPublicationUseCase;
  final CreateRequestUseCase? createRequestUseCase;
  final RequestRepository? requestRepository;
  final RequesterRepository? requesterRepository;
  final RequesterDuplicateChecker? duplicateChecker;
  final AppClock clock;

  NewRequestPage({
    super.key,
    PublicationRepository? publicationRepository,
    this.searchService,
    this.addPublicationUseCase,
    this.createRequestUseCase,
    RequestRepository? requestRepository,
    RequesterRepository? requesterRepository,
    this.duplicateChecker,
    AppClock? clock,
  })  : publicationRepository =
            publicationRepository ?? PublicationRepositoryImpl(),
        requestRepository = requestRepository ?? RequestRepositoryImpl(),
        requesterRepository = requesterRepository ?? RequesterRepositoryImpl(),
        clock = clock ?? const SystemClock();

  @override
  State<NewRequestPage> createState() => NewRequestPageState();
}

class NewRequestPageState extends State<NewRequestPage> {
  late final PublicationCatalogSearchService _searchService;
  late final AddPublicationToRequestUseCase _addPublicationUseCase;
  late final CreateRequestUseCase _createRequestUseCase;
  late final RequesterRepository _requesterRepository;
  late final RequesterDuplicateChecker _duplicateChecker;
  late final AppClock _clock;

  final TextEditingController _requesterSearchController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');

  Timer? _requesterDebounceTimer;
  int _requesterSearchRequestId = 0;
  bool _isSearchingRequester = false;
  String? _requesterSearchError;
  List<Requester> _requesterSearchResults = [];
  Requester? _selectedRequester;

  Timer? _debounceTimer;
  int _searchRequestId = 0;
  bool _isSearching = false;
  String? _searchError;
  List<Publication> _searchResults = [];

  Publication? _selectedPublication;
  Request? _currentRequest;
  bool _isSaving = false;

  final Map<int, Publication> _publicationCache = {};

  Request? get currentRequest => _currentRequest;
  Requester? get selectedRequester => _selectedRequester;
  Publication? get selectedPublication => _selectedPublication;
  List<Publication> get searchResults => List.unmodifiable(_searchResults);
  List<Requester> get requesterSearchResults =>
      List.unmodifiable(_requesterSearchResults);

  @override
  void initState() {
    super.initState();
    _clock = widget.clock;
    _searchService = widget.searchService ??
        PublicationCatalogSearchService(widget.publicationRepository);
    _addPublicationUseCase = widget.addPublicationUseCase ??
        AddPublicationToRequestUseCase(clock: _clock);
    _createRequestUseCase = widget.createRequestUseCase ??
        CreateRequestUseCase(
          repository: widget.requestRepository ?? RequestRepositoryImpl(),
        );
    _requesterRepository =
        widget.requesterRepository ?? RequesterRepositoryImpl();
    _duplicateChecker = widget.duplicateChecker ??
        RequesterDuplicateChecker(_requesterRepository);
  }

  @override
  void dispose() {
    _requesterDebounceTimer?.cancel();
    _debounceTimer?.cancel();
    _requesterSearchController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Solicitante (Requester) Methods
  // ---------------------------------------------------------------------------

  void _onRequesterSearchChanged(String query) {
    _requesterDebounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _requesterSearchResults = [];
        _isSearchingRequester = false;
        _requesterSearchError = null;
      });
      return;
    }

    _requesterDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performRequesterSearch(trimmed);
    });
  }

  Future<void> _performRequesterSearch(String query) async {
    final currentRequestId = ++_requesterSearchRequestId;
    setState(() {
      _isSearchingRequester = true;
      _requesterSearchError = null;
    });

    try {
      final results = await _requesterRepository.searchActiveByName(query);
      if (currentRequestId == _requesterSearchRequestId && mounted) {
        setState(() {
          _requesterSearchResults = results;
          _isSearchingRequester = false;
        });
      }
    } catch (e) {
      if (currentRequestId == _requesterSearchRequestId && mounted) {
        setState(() {
          _requesterSearchError = 'Error al buscar solicitantes';
          _isSearchingRequester = false;
        });
      }
    }
  }

  void _selectRequester(Requester requester) {
    setState(() {
      _selectedRequester = requester;
      _requesterSearchController.clear();
      _requesterSearchResults = [];
      _isSearchingRequester = false;

      if (_currentRequest != null) {
        _currentRequest = _currentRequest!.copyWith(
          requesterId: requester.id!,
          updatedAt: _clock.nowUtc(),
        );
      }
    });
  }

  void _onChangeRequester() {
    setState(() {
      _selectedRequester = null;
      _requesterSearchController.clear();
      _requesterSearchResults = [];
    });
  }

  Future<void> _handleCreateRequester(String rawName) async {
    final cleanName = RequesterNameCleaner.clean(rawName);

    if (!RequesterNameCleaner.hasAtLeastTwoSignificantWords(cleanName)) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Nombre inválido'),
          content: const Text(
            'El nombre del solicitante debe contener al menos dos palabras.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final checkResult = await _duplicateChecker.check(cleanName);

    if (!mounted) return;

    if (checkResult is RequesterExactDuplicateResult) {
      await showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Ya existe el solicitante'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ya existe el solicitante:\n\n"${checkResult.existing.name}"\n\nVerifique que el nombre del solicitante sea correcto.',
                style: AppTypography.bodyNormal,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const Key('select_exact_duplicate_button'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _selectRequester(checkResult.existing);
              },
              child: const Text('Seleccionar existente'),
            ),
          ],
        ),
      );
    } else if (checkResult is RequesterPossibleDuplicateResult) {
      await showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('¿Es alguno de estos solicitantes?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Se encontraron solicitantes con nombres similares. Verifique antes de crear uno nuevo:',
                  style: AppTypography.bodySecondary,
                ),
                AppSpacing.vSpacerSm,
                ...checkResult.matches.map(
                  (match) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(match.name, style: AppTypography.titleCard),
                    trailing: TextButton(
                      child: const Text('Seleccionar'),
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        _selectRequester(match);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const Key('confirm_create_new_requester_button'),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await _executeCreateRequester(cleanName);
              },
              child: Text('No es la misma persona (+ Crear "$cleanName")'),
            ),
          ],
        ),
      );
    } else {
      await _executeCreateRequester(cleanName);
    }
  }

  Future<void> _executeCreateRequester(String cleanName) async {
    final now = _clock.nowUtc();
    final newRequester = Requester(
      name: cleanName,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final saved = await _requesterRepository.create(newRequester);
      if (mounted) {
        _selectRequester(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear el solicitante: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Publication Search & Add Methods
  // ---------------------------------------------------------------------------

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    final currentRequestId = ++_searchRequestId;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await _searchService.search(query);
      if (currentRequestId == _searchRequestId && mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (currentRequestId == _searchRequestId && mounted) {
        setState(() {
          _searchError = 'Error al buscar publicaciones';
          _isSearching = false;
        });
      }
    }
  }

  void _selectPublication(Publication pub) {
    setState(() {
      _selectedPublication = pub;
      _searchResults = [];
      _searchController.clear();
      _quantityController.text = '1';
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPublication = null;
      _quantityController.text = '1';
    });
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

  Future<void> _onAddPublication() async {
    if (_selectedPublication == null) return;

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La cantidad solicitada debe ser mayor a 0'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final pub = _selectedPublication!;
    if (pub.id != null) {
      _publicationCache[pub.id!] = pub;
    }

    _currentRequest ??= _addPublicationUseCase.createRequest(
      requesterId: _selectedRequester?.id ?? 1,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    final result = _addPublicationUseCase.addPublication(
      request: _currentRequest!,
      publication: pub,
      quantity: quantity,
    );

    if (result is PublicationAddedToRequest) {
      setState(() {
        _currentRequest = result.request;
        _selectedPublication = null;
        _quantityController.text = '1';
        _searchController.clear();
        _searchResults = [];
      });
    } else if (result is PublicationAlreadyInRequest) {
      await _handlePublicationAlreadyInRequest(result);
    }
  }

  Future<void> _handlePublicationAlreadyInRequest(
    PublicationAlreadyInRequest result,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publicación ya agregada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${result.publication.name}" ya está agregada con cantidad ${result.existingItem.quantityRequested}.',
              style: AppTypography.bodyNormal,
            ),
            AppSpacing.vSpacerSm,
            Text(
              '¿Deseas agregar ${result.quantityToAdd} más?',
              style: AppTypography.bodyNormal,
            ),
            AppSpacing.vSpacerMd,
            Text(
              'Nueva cantidad: ${result.newTotalQuantity}',
              style: AppTypography.titleCard.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('confirm_accumulation_cancel_button'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('confirm_accumulation_confirm_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final updatedRequest =
          _addPublicationUseCase.confirmAccumulationForPublication(
        request: _currentRequest!,
        publication: result.publication,
        quantityToAdd: result.quantityToAdd,
      );

      setState(() {
        _currentRequest = updatedRequest;
        _selectedPublication = null;
        _quantityController.text = '1';
        _searchController.clear();
        _searchResults = [];
      });
    }
  }

  Future<void> _onSaveRequest() async {
    if (_selectedRequester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un solicitante para el pedido'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_currentRequest == null || !_currentRequest!.isValidForOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La solicitud debe contener al menos un artículo'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final finalRequest = _currentRequest!.copyWith(
        requesterId: _selectedRequester!.id!,
        notes: () => _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        updatedAt: _clock.nowUtc(),
      );

      final saved = await _createRequestUseCase(finalRequest);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pedido guardado exitosamente${saved.id != null ? " (#${saved.id})" : ""}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(saved);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el pedido: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Widget Builders
  // ---------------------------------------------------------------------------

  Widget _buildRequesterSection() {
    if (_selectedRequester != null) {
      return AppCard(
        key: const Key('selected_requester_card'),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Solicitante seleccionado',
                      style: AppTypography.bodySecondary),
                  AppSpacing.vSpacerXs,
                  Text(_selectedRequester!.name,
                      style: AppTypography.titleCard),
                ],
              ),
            ),
            TextButton.icon(
              key: const Key('change_requester_button'),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Cambiar'),
              onPressed: _onChangeRequester,
            ),
          ],
        ),
      );
    }

    final query = _requesterSearchController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFormField(
          key: const Key('search_requester_field'),
          labelText: 'Solicitante',
          hintText: 'Buscar o ingresar solicitante...',
          controller: _requesterSearchController,
          prefixIcon: Icons.person_search_rounded,
          onChanged: _onRequesterSearchChanged,
        ),
        if (_isSearchingRequester)
          const Padding(
            padding: AppSpacing.pAllMd,
            child: AppLoadingIndicator(message: 'Buscando solicitantes...'),
          ),
        if (_requesterSearchError != null)
          Padding(
            padding: AppSpacing.pAllMd,
            child: AppErrorState(
              message: _requesterSearchError!,
              actionLabel: 'Reintentar',
              onRetryPressed: () => _performRequesterSearch(
                  _requesterSearchController.text.trim()),
            ),
          ),
        if (query.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                ..._requesterSearchResults.map(
                  (req) => ListTile(
                    key: Key('requester_search_result_${req.id}'),
                    leading: const Icon(Icons.person_rounded,
                        color: AppColors.primaryLight),
                    title: Text(req.name, style: AppTypography.titleCard),
                    onTap: () => _selectRequester(req),
                  ),
                ),
                ListTile(
                  key: const Key('create_requester_button'),
                  leading: const Icon(Icons.person_add_rounded,
                      color: AppColors.primary),
                  title: Text(
                    '+ Agregar "$query"',
                    style: AppTypography.titleCard
                        .copyWith(color: AppColors.primary),
                  ),
                  onTap: () => _handleCreateRequester(query),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Padding(
        padding: AppSpacing.pAllMd,
        child: AppLoadingIndicator(
          message: 'Buscando publicaciones...',
        ),
      );
    }

    if (_searchError != null) {
      return Padding(
        padding: AppSpacing.pAllMd,
        child: AppErrorState(
          message: _searchError!,
          actionLabel: 'Reintentar',
          onRetryPressed: () => _performSearch(_searchController.text.trim()),
        ),
      );
    }

    final query = _searchController.text.trim();
    if (query.isNotEmpty && _searchResults.isEmpty) {
      return const Padding(
        padding: AppSpacing.pAllMd,
        child: Center(
          child: Text(
            'No se encontraron publicaciones activas con el criterio ingresado',
            style: AppTypography.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final pub = _searchResults[index];
          final subtitle = _buildSubtitle(pub);

          return ListTile(
            key: Key('search_result_item_${pub.id}'),
            title: Text(pub.name, style: AppTypography.titleCard),
            subtitle: Text(
              subtitle,
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: AppStatusBadge.fromString(pub.status.name),
            onTap: () => _selectPublication(pub),
          );
        },
      ),
    );
  }

  Widget _buildSelectedPublicationCard() {
    if (_selectedPublication == null) {
      return const SizedBox.shrink();
    }

    final pub = _selectedPublication!;
    return AppCard(
      key: const Key('selected_publication_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Publicación seleccionada',
                style: AppTypography.titleSection,
              ),
              IconButton(
                key: const Key('clear_selected_publication_button'),
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: _clearSelection,
              ),
            ],
          ),
          AppSpacing.vSpacerSm,
          Text(pub.name, style: AppTypography.titleCard),
          AppSpacing.vSpacerXs,
          Row(
            children: [
              Text(_buildSubtitle(pub), style: AppTypography.bodySecondary),
              const Spacer(),
              AppStatusBadge.fromString(pub.status.name),
            ],
          ),
          AppSpacing.vSpacerMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: AppFormField(
                  key: const Key('quantity_field'),
                  labelText: 'Cantidad',
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                ),
              ),
              AppSpacing.hSpacerMd,
              Expanded(
                flex: 3,
                child: AppPrimaryButton(
                  key: const Key('add_publication_button'),
                  text: 'Agregar',
                  icon: Icons.add_rounded,
                  onPressed: _onAddPublication,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSummary() {
    final items = _currentRequest?.items ?? const [];
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: AppSpacing.pAllMd,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No hay artículos agregados al pedido',
            style: AppTypography.bodySecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('request_items_summary'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => AppSpacing.vSpacerSm,
      itemBuilder: (context, index) {
        final item = items[index];
        final pub = _publicationCache[item.publicationId];
        final name = pub?.name ?? 'Publicación #${item.publicationId}';
        final subtitle = pub != null ? _buildSubtitle(pub) : null;

        return AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.titleCard),
                    if (subtitle != null) ...[
                      AppSpacing.vSpacerXs,
                      Text(subtitle, style: AppTypography.bodySecondary),
                    ],
                  ],
                ),
              ),
              AppSpacing.hSpacerSm,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 4,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  '${item.quantityRequested}',
                  style: AppTypography.titleCard.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Pedido'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pAllMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRequesterSection(),
            AppSpacing.vSpacerMd,
            AppFormField(
              key: const Key('notes_field'),
              labelText: 'Notas (opcional)',
              hintText: 'Observaciones sobre el pedido...',
              controller: _notesController,
            ),
            AppSpacing.vSpacerLg,
            const Divider(),
            AppSpacing.vSpacerMd,
            AppFormField(
              key: const Key('search_publication_field'),
              labelText: 'Buscar publicación',
              hintText: 'Buscar por código o nombre...',
              controller: _searchController,
              prefixIcon: Icons.search_rounded,
              onChanged: _onSearchChanged,
            ),
            _buildSearchResults(),
            if (_selectedPublication != null) ...[
              AppSpacing.vSpacerMd,
              _buildSelectedPublicationCard(),
            ],
            AppSpacing.vSpacerLg,
            const Text(
              'Artículos del pedido',
              style: AppTypography.titleSection,
            ),
            AppSpacing.vSpacerSm,
            _buildItemsSummary(),
            AppSpacing.vSpacerXl,
            AppPrimaryButton(
              key: const Key('save_request_button'),
              text: 'Guardar pedido',
              icon: Icons.save_rounded,
              fullWidth: true,
              isLoading: _isSaving,
              onPressed: (_selectedRequester != null &&
                      _currentRequest != null &&
                      _currentRequest!.isValidForOrder)
                  ? _onSaveRequest
                  : null,
            ),
            AppSpacing.vSpacerLg,
          ],
        ),
      ),
    );
  }
}
