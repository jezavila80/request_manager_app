import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../publications/domain/duplicate_check_result.dart';
import '../../../publications/domain/publication.dart';
import '../../../publications/domain/publication_repository.dart';
import '../../../publications/domain/services/publication_duplicate_checker.dart';
import '../../../publications/domain/tri_state_value.dart';

class _DuplicateChoice {
  final bool isCancel;
  final bool isCreateAnyway;
  final Publication? existingPublication;

  const _DuplicateChoice.cancel()
      : isCancel = true,
        isCreateAnyway = false,
        existingPublication = null;

  const _DuplicateChoice.createAnyway()
      : isCancel = false,
        isCreateAnyway = true,
        existingPublication = null;

  const _DuplicateChoice.useExisting(Publication pub)
      : isCancel = false,
        isCreateAnyway = false,
        existingPublication = pub;

  bool get isUseExisting => existingPublication != null;
}

/// Dialog to quickly create and persist a new draft publication from the new request flow.
class QuickDraftDialog extends StatefulWidget {
  final String initialName;
  final PublicationRepository publicationRepository;
  final PublicationDuplicateChecker duplicateChecker;
  final AppClock clock;

  const QuickDraftDialog({
    super.key,
    required this.initialName,
    required this.publicationRepository,
    required this.duplicateChecker,
    required this.clock,
  });

  @override
  State<QuickDraftDialog> createState() => _QuickDraftDialogState();
}

class _QuickDraftDialogState extends State<QuickDraftDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _sizeValueController = TextEditingController();
  final TextEditingController _versionValueController = TextEditingController();

  TriState _sizeState = TriState.sinDefinir;
  TriState _versionState = TriState.sinDefinir;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName.trim());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    _sizeValueController.dispose();
    _versionValueController.dispose();
    super.dispose();
  }

  TriStateValue<String> _buildSizeValue() {
    switch (_sizeState) {
      case TriState.sinDefinir:
        return const TriStateValue.sinDefinir();
      case TriState.noAplica:
        return const TriStateValue.noAplica();
      case TriState.conValor:
        final val = _sizeValueController.text.trim();
        return val.isNotEmpty
            ? TriStateValue.conValor(val)
            : const TriStateValue.sinDefinir();
    }
  }

  TriStateValue<String> _buildVersionValue() {
    switch (_versionState) {
      case TriState.sinDefinir:
        return const TriStateValue.sinDefinir();
      case TriState.noAplica:
        return const TriStateValue.noAplica();
      case TriState.conValor:
        final val = _versionValueController.text.trim();
        return val.isNotEmpty
            ? TriStateValue.conValor(val)
            : const TriStateValue.sinDefinir();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final nowUtc = widget.clock.nowUtc();
    final candidate = Publication.quickDraft(
      name: _nameController.text,
      description: _descriptionController.text,
      type: _typeController.text,
      size: _buildSizeValue(),
      version: _buildVersionValue(),
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final duplicateResult =
          await widget.duplicateChecker.checkDuplicates(candidate);

      if (!mounted) return;

      if (duplicateResult.status == DuplicateCheckStatus.possibleDuplicate &&
          duplicateResult.matches.isNotEmpty) {
        setState(() {
          _isSaving = false;
        });

        final choice =
            await _showPossibleDuplicateDialog(duplicateResult.matches);
        if (choice == null || choice.isCancel) {
          // User chose to return to edit
          return;
        }

        if (choice.isUseExisting && choice.existingPublication != null) {
          // Select existing publication without creating a new draft
          if (mounted) {
            Navigator.of(context).pop(choice.existingPublication);
          }
          return;
        }

        // User confirmed creating anyway
        setState(() {
          _isSaving = true;
        });
      }

      final saved = await widget.publicationRepository.create(candidate);
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage =
              'Error al guardar la publicación en borrador. Intente nuevamente.';
        });
      }
    }
  }

  Future<_DuplicateChoice?> _showPossibleDuplicateDialog(
      List<Publication> matches) async {
    return showDialog<_DuplicateChoice>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('possible_duplicate_dialog'),
        title: const Text('¿Es alguna de estas publicaciones?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se encontraron publicaciones similares en el catálogo. Verifique si alguna coincide antes de crear un nuevo borrador:',
                style: AppTypography.bodySecondary,
              ),
              AppSpacing.vSpacerSm,
              ...matches.map(
                (match) => ListTile(
                  key: Key('duplicate_match_item_${match.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.menu_book_rounded,
                      color: AppColors.primaryLight),
                  title: Text(match.name, style: AppTypography.titleCard),
                  subtitle: Text(
                    [
                      if (match.code != null && match.code!.isNotEmpty)
                        match.code!,
                      if (match.type != null && match.type!.isNotEmpty)
                        match.type!,
                    ].join(' · '),
                    style: AppTypography.bodySecondary,
                  ),
                  trailing: TextButton(
                    key: Key('select_existing_pub_${match.id}_button'),
                    child: const Text('Seleccionar'),
                    onPressed: () => Navigator.of(dialogCtx)
                        .pop(_DuplicateChoice.useExisting(match)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('duplicate_warning_cancel_button'),
            onPressed: () =>
                Navigator.of(dialogCtx).pop(const _DuplicateChoice.cancel()),
            child: const Text('Volver a editar'),
          ),
          ElevatedButton(
            key: const Key('confirm_create_anyway_button'),
            onPressed: () => Navigator.of(dialogCtx)
                .pop(const _DuplicateChoice.createAnyway()),
            child: const Text('No es la misma (Crear borrador)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('quick_draft_dialog'),
      title: const Row(
        children: [
          Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 26),
          AppSpacing.hSpacerSm,
          Expanded(
            child: Text(
              'Crear publicación en borrador',
              style: AppTypography.titleSection,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFormField(
                  key: const Key('quick_draft_name_field'),
                  labelText: 'Nombre *',
                  hintText: 'Nombre de la publicación',
                  controller: _nameController,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El nombre de la publicación no puede estar vacío.';
                    }
                    return null;
                  },
                ),
                AppSpacing.vSpacerMd,
                AppFormField(
                  key: const Key('quick_draft_type_field'),
                  labelText: 'Tipo',
                  hintText: 'Ej. Libro, Folleto, Revista (opcional)',
                  controller: _typeController,
                ),
                AppSpacing.vSpacerMd,
                AppFormField(
                  key: const Key('quick_draft_description_field'),
                  labelText: 'Descripción (recomendada)',
                  hintText: 'Detalles para identificar la publicación...',
                  controller: _descriptionController,
                ),
                AppSpacing.vSpacerMd,
                AppDropdownField<TriState>(
                  key: const Key('quick_draft_size_dropdown'),
                  labelText: 'Tamaño',
                  value: _sizeState,
                  items: const [
                    DropdownMenuItem(
                      value: TriState.sinDefinir,
                      child: Text('Sin definir'),
                    ),
                    DropdownMenuItem(
                      value: TriState.noAplica,
                      child: Text('No aplica'),
                    ),
                    DropdownMenuItem(
                      value: TriState.conValor,
                      child: Text('Con valor específico'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _sizeState = val);
                    }
                  },
                ),
                if (_sizeState == TriState.conValor) ...[
                  AppSpacing.vSpacerSm,
                  AppFormField(
                    key: const Key('quick_draft_size_value_field'),
                    labelText: 'Valor del tamaño',
                    hintText: 'Ej. Grande, Bolsillo',
                    controller: _sizeValueController,
                  ),
                ],
                AppSpacing.vSpacerMd,
                AppDropdownField<TriState>(
                  key: const Key('quick_draft_version_dropdown'),
                  labelText: 'Versión',
                  value: _versionState,
                  items: const [
                    DropdownMenuItem(
                      value: TriState.sinDefinir,
                      child: Text('Sin definir'),
                    ),
                    DropdownMenuItem(
                      value: TriState.noAplica,
                      child: Text('No aplica'),
                    ),
                    DropdownMenuItem(
                      value: TriState.conValor,
                      child: Text('Con valor específico'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _versionState = val);
                    }
                  },
                ),
                if (_versionState == TriState.conValor) ...[
                  AppSpacing.vSpacerSm,
                  AppFormField(
                    key: const Key('quick_draft_version_value_field'),
                    labelText: 'Valor de la versión',
                    hintText: 'Ej. Revisada 2013',
                    controller: _versionValueController,
                  ),
                ],
                AppSpacing.vSpacerMd,
                Container(
                  padding: AppSpacing.pAllSm,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: AppColors.textSecondary),
                      AppSpacing.hSpacerSm,
                      Expanded(
                        child: Text(
                          'El código se completará posteriormente cuando se identifique la publicación.',
                          style: AppTypography.bodySecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  AppSpacing.vSpacerMd,
                  Container(
                    key: const Key('quick_draft_error_banner'),
                    padding: AppSpacing.pAllSm,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 18, color: AppColors.error),
                        AppSpacing.hSpacerSm,
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            key: const Key('quick_draft_error_message'),
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isSaving) ...[
                  AppSpacing.vSpacerMd,
                  const AppLoadingIndicator(message: 'Guardando borrador...'),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('quick_draft_cancel_button'),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('quick_draft_submit_button'),
          onPressed: _isSaving ? null : _submit,
          child: const Text('Crear borrador'),
        ),
      ],
    );
  }
}
