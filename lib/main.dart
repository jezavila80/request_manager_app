// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Import design system tokens and widgets
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_card.dart';
import 'core/widgets/app_status_badge.dart';
import 'core/widgets/app_buttons.dart';
import 'core/widgets/app_fields.dart';
import 'core/widgets/app_states.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Request Manager App',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      // Configure localizations for Spanish language support in DatePicker and others
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentTab = 0;
  String _simulatedState = 'normal'; // 'normal', 'loading', 'empty', 'error'
  String? _selectedOrderId;

  // Recepciones Form State
  final _recepcionCodigoController = TextEditingController(text: 'RL-12');
  String _selectedPublicacion = 'Libro A';
  final _recepcionCantidadController = TextEditingController(text: '15');
  DateTime? _selectedRecepcionDate = DateTime(2026, 8, 25);

  final List<String> _publicacionesList = ['Libro A', 'Revista B', 'Libro C', 'Manual D'];

  // Mock data for the demo
  final List<Map<String, dynamic>> _mockPedidos = [
    {
      'id': '0012',
      'solicitante': 'María Pérez',
      'fecha': '17/08/2026',
      'estado': 'parcialmenteSurtido',
      'articulos': [
        {
          'codigo': 'RL-12',
          'nombre': 'Libro A',
          'solicitado': 10,
          'surtido': 6,
          'pendiente': 4,
          'estado': 'parcialmenteSurtido'
        },
        {
          'codigo': 'RV-04',
          'nombre': 'Revista B',
          'solicitado': 5,
          'surtido': 0,
          'pendiente': 5,
          'estado': 'pendiente'
        }
      ]
    },
    {
      'id': '0011',
      'solicitante': 'Juan López',
      'fecha': '16/08/2026',
      'estado': 'pendiente',
      'articulos': [
        {
          'codigo': 'RL-15',
          'nombre': 'Libro C',
          'solicitado': 3,
          'surtido': 0,
          'pendiente': 3,
          'estado': 'pendiente'
        }
      ]
    },
    {
      'id': '0010',
      'solicitante': 'Ana Gómez',
      'fecha': '15/08/2026',
      'estado': 'surtido',
      'articulos': [
        {
          'codigo': 'RL-12',
          'nombre': 'Libro A',
          'solicitado': 8,
          'surtido': 8,
          'pendiente': 0,
          'estado': 'surtido'
        }
      ]
    }
  ];

  final List<Map<String, dynamic>> _mockInventario = [
    {'codigo': 'RL-12', 'nombre': 'Libro A', 'existencia': 5},
    {'codigo': 'RV-04', 'nombre': 'Revista B', 'existencia': 12},
    {'codigo': 'RL-15', 'nombre': 'Libro C', 'existencia': 0},
    {'codigo': 'MN-08', 'nombre': 'Manual D', 'existencia': 8},
  ];

  @override
  void dispose() {
    _recepcionCodigoController.dispose();
    _recepcionCantidadController.dispose();
    super.dispose();
  }

  // Helper method to reset simulation back to normal
  void _resetSimulation() {
    setState(() {
      _simulatedState = 'normal';
    });
  }

  // Render content based on active tab and simulation state
  Widget _buildTabContent() {
    if (_simulatedState == 'loading') {
      return const AppLoadingIndicator(message: 'Cargando datos de la sección...');
    }
    if (_simulatedState == 'empty') {
      return AppEmptyState(
        message: 'No se encontraron registros en esta sección.',
        icon: Icons.folder_open_rounded,
        actionLabel: 'Volver a Normal',
        onActionPressed: _resetSimulation,
      );
    }
    if (_simulatedState == 'error') {
      return AppErrorState(
        message: 'Error al establecer conexión con el servidor local SQLite.',
        actionLabel: 'Reintentar Carga',
        onRetryPressed: _resetSimulation,
      );
    }

    switch (_currentTab) {
      case 0:
        return _buildInicioTab();
      case 1:
        return _buildPedidosTab();
      case 2:
        return _buildRecepcionesTab();
      case 3:
        return _buildInventarioTab();
      default:
        return _buildInicioTab();
    }
  }

  // TAB 0: INICIO (DASHBOARD)
  Widget _buildInicioTab() {
    return SingleChildScrollView(
      padding: AppSpacing.pAllMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen de Solicitudes', style: AppTypography.titleSection),
          AppSpacing.vSpacerMd,
          // Summary Grid Cards
          Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: AppSpacing.pAllSm + const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      const Icon(Icons.access_time_rounded, color: AppColors.info, size: 20),
                      AppSpacing.vSpacerXs,
                      const Text('12', style: AppTypography.valueHighlight),
                      Text('Pendientes', style: AppTypography.bodySecondary.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              AppSpacing.hSpacerSm,
              Expanded(
                child: AppCard(
                  padding: AppSpacing.pAllSm + const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      const Icon(Icons.incomplete_circle_rounded, color: AppColors.warning, size: 20),
                      AppSpacing.vSpacerXs,
                      const Text('7', style: AppTypography.valueHighlight),
                      Text('Parciales', style: AppTypography.bodySecondary.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              AppSpacing.hSpacerSm,
              Expanded(
                child: AppCard(
                  padding: AppSpacing.pAllSm + const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                      AppSpacing.vSpacerXs,
                      const Text('38', style: AppTypography.valueHighlight),
                      Text('Surtidos', style: AppTypography.bodySecondary.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vSpacerLg,
          
          // Rule Info banner
          AppCard(
            color: AppColors.surfaceVariant,
            borderSide: BorderSide.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 24),
                AppSpacing.hSpacerMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Regla Funcional de Inventario',
                        style: AppTypography.titleCard.copyWith(color: AppColors.primary, fontSize: 14),
                      ),
                      AppSpacing.vSpacerXs,
                      const Text(
                        'Toda recepción ingresa a Existencia Local. El Surtido ocurre cuando se asigna material de la existencia a un pedido, disminuyendo el inventario.',
                        style: AppTypography.bodySecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vSpacerLg,
          
          // Recent Orders section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pedidos Recientes', style: AppTypography.titleSection),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentTab = 1;
                    _selectedOrderId = null;
                  });
                },
                child: const Text('Ver todos'),
              ),
            ],
          ),
          AppSpacing.vSpacerSm,
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _mockPedidos.length,
            separatorBuilder: (context, index) => AppSpacing.vSpacerSm,
            itemBuilder: (context, index) {
              final pedido = _mockPedidos[index];
              return AppCard(
                onTap: () {
                  setState(() {
                    _selectedOrderId = pedido['id'];
                    _currentTab = 1; // Switch to Pedidos tab
                  });
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('#${pedido['id']}', style: AppTypography.titleCard),
                              AppSpacing.hSpacerSm,
                              Text(pedido['solicitante'], style: AppTypography.bodyNormal.copyWith(fontWeight: FontWeight.w500)),
                            ],
                          ),
                          AppSpacing.vSpacerXs,
                          Text('Fecha: ${pedido['fecha']}', style: AppTypography.bodySecondary),
                        ],
                      ),
                    ),
                    AppStatusBadge.fromString(pedido['estado']),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // TAB 1: PEDIDOS (LISTADO Y DETALLE)
  Widget _buildPedidosTab() {
    if (_selectedOrderId != null) {
      return _buildPedidoDetalle(_selectedOrderId!);
    }

    return Padding(
      padding: AppSpacing.pAllMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Listado de Pedidos', style: AppTypography.titleSection),
              ),
            ],
          ),
          AppSpacing.vSpacerMd,
          // Search Field mock
          const AppFormField(
            labelText: 'Buscar pedido',
            hintText: 'Buscar por solicitante o código...',
            prefixIcon: Icons.search_rounded,
          ),
          AppSpacing.vSpacerLg,
          Expanded(
            child: ListView.separated(
              itemCount: _mockPedidos.length,
              separatorBuilder: (context, index) => AppSpacing.vSpacerSm,
              itemBuilder: (context, index) {
                final pedido = _mockPedidos[index];
                return AppCard(
                  onTap: () {
                    setState(() {
                      _selectedOrderId = pedido['id'];
                    });
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#${pedido['id']}', style: AppTypography.titleCard),
                            AppSpacing.vSpacerXs,
                            Text(pedido['solicitante'], style: AppTypography.bodyNormal),
                            Text('Fecha: ${pedido['fecha']}', style: AppTypography.bodySecondary),
                          ],
                        ),
                      ),
                      AppStatusBadge.fromString(pedido['estado']),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1 DETAIL: DETALLE DE PEDIDO
  Widget _buildPedidoDetalle(String id) {
    final pedido = _mockPedidos.firstWhere((p) => p['id'] == id);

    return SingleChildScrollView(
      padding: AppSpacing.pAllMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigation Back
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedOrderId = null;
              });
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Volver al listado'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          ),
          AppSpacing.vSpacerSm,
          
          // Header Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pedido #$id', style: AppTypography.titlePrimary),
                    AppStatusBadge.fromString(pedido['estado']),
                  ],
                ),
                AppSpacing.vSpacerMd,
                const Divider(),
                AppSpacing.vSpacerMd,
                Text('Solicitante', style: AppTypography.bodySecondary.copyWith(fontWeight: FontWeight.w600)),
                Text(pedido['solicitante'], style: AppTypography.bodyNormal),
                AppSpacing.vSpacerMd,
                Text('Fecha de Pedido', style: AppTypography.bodySecondary.copyWith(fontWeight: FontWeight.w600)),
                Text(pedido['fecha'], style: AppTypography.bodyNormal),
              ],
            ),
          ),
          AppSpacing.vSpacerLg,
          
          // Articles section
          Text('Publicaciones Solicitadas', style: AppTypography.titleSection),
          AppSpacing.vSpacerSm,
          
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (pedido['articulos'] as List).length,
            separatorBuilder: (context, index) => AppSpacing.vSpacerSm,
            itemBuilder: (context, index) {
              final art = pedido['articulos'][index];
              return AppCard(
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
                              Text(art['codigo'], style: AppTypography.titleCard.copyWith(color: AppColors.primaryLight)),
                              Text(art['nombre'], style: AppTypography.titleCard),
                            ],
                          ),
                        ),
                        AppStatusBadge.fromString(art['estado']),
                      ],
                    ),
                    AppSpacing.vSpacerMd,
                    const Divider(),
                    AppSpacing.vSpacerMd,
                    // Quantities row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Solicitado', style: AppTypography.bodySecondary),
                            Text('${art['solicitado']}', style: AppTypography.bodyNormal.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Surtido', style: AppTypography.bodySecondary),
                            Text('${art['surtido']}', style: AppTypography.bodyNormal.copyWith(fontWeight: FontWeight.bold, color: AppColors.success)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pendiente', style: AppTypography.bodySecondary),
                            Text('${art['pendiente']}', style: AppTypography.bodyNormal.copyWith(fontWeight: FontWeight.bold, color: art['pendiente'] > 0 ? AppColors.warning : AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          
          AppSpacing.vSpacerXl,
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  text: 'Entregar Material',
                  icon: Icons.send_rounded,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Simulando entrega de existencia local al pedido...'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 2: RECEPCIONES (FORMULARIO)
  Widget _buildRecepcionesTab() {
    return SingleChildScrollView(
      padding: AppSpacing.pAllMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registrar Recepción de Material', style: AppTypography.titleSection),
          AppSpacing.vSpacerXs,
          Text(
            'Registra la llegada de publicaciones físicas para integrarlas al almacén local.',
            style: AppTypography.bodySecondary,
          ),
          AppSpacing.vSpacerLg,
          
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFormField(
                  labelText: 'Código de Publicación',
                  hintText: 'Ej. RL-12',
                  controller: _recepcionCodigoController,
                  prefixIcon: Icons.qr_code_rounded,
                ),
                AppSpacing.vSpacerMd,
                
                AppDropdownField<String>(
                  labelText: 'Publicación',
                  value: _selectedPublicacion,
                  items: _publicacionesList.map((pub) {
                    return DropdownMenuItem(
                      value: pub,
                      child: Text(pub),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPublicacion = val;
                      });
                    }
                  },
                ),
                AppSpacing.vSpacerMd,
                
                AppFormField(
                  labelText: 'Cantidad Recibida',
                  hintText: 'Ej. 15',
                  controller: _recepcionCantidadController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.add_moderator,
                ),
                AppSpacing.vSpacerMd,
                
                AppDateField(
                  labelText: 'Fecha de Recepción',
                  selectedDate: _selectedRecepcionDate,
                  onDateSelected: (date) {
                    setState(() {
                      _selectedRecepcionDate = date;
                    });
                  },
                ),
                AppSpacing.vSpacerLg,
                
                // Form buttons
                Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(
                        text: 'Cancelar',
                        onPressed: () {
                          setState(() {
                            _recepcionCodigoController.clear();
                            _recepcionCantidadController.clear();
                            _selectedRecepcionDate = DateTime.now();
                          });
                        },
                      ),
                    ),
                    AppSpacing.hSpacerMd,
                    Expanded(
                      child: AppPrimaryButton(
                        text: 'Guardar Entrada',
                        icon: Icons.save_rounded,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Se guardaron ${_recepcionCantidadController.text} unidades de $_selectedPublicacion en existencia.'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: INVENTARIO
  Widget _buildInventarioTab() {
    return Padding(
      padding: AppSpacing.pAllMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Existencia Local de Literatura', style: AppTypography.titleSection),
          AppSpacing.vSpacerXs,
          Text(
            'Cantidades disponibles de publicaciones físicas en el almacén local.',
            style: AppTypography.bodySecondary,
          ),
          AppSpacing.vSpacerLg,
          
          Expanded(
            child: ListView.separated(
              itemCount: _mockInventario.length,
              separatorBuilder: (context, index) => AppSpacing.vSpacerSm,
              itemBuilder: (context, index) {
                final item = _mockInventario[index];
                final bool lowStock = item['existencia'] == 0;
                
                return AppCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['codigo'], style: AppTypography.bodySecondary.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                          Text(item['nombre'], style: AppTypography.titleCard),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: lowStock ? AppColors.errorLight : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: lowStock ? AppColors.error : AppColors.border, width: 1.0),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${item['existencia']}',
                              style: AppTypography.valueHighlight.copyWith(
                                fontSize: 20.0,
                                color: lowStock ? AppColors.error : AppColors.primary,
                              ),
                            ),
                            Text(
                              'unidades',
                              style: AppTypography.bodySecondary.copyWith(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w600,
                                color: lowStock ? AppColors.error : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Manager App'),
        actions: [
          // Simulation Selector menu button
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white),
            tooltip: 'Simulador de Estados Visuales',
            onSelected: (String result) {
              setState(() {
                _simulatedState = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'normal',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: _simulatedState == 'normal' ? AppColors.accent : AppColors.textSecondary, size: 20),
                    AppSpacing.hSpacerSm,
                    const Text('Estado: Normal / Completo'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'loading',
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty_rounded, color: _simulatedState == 'loading' ? AppColors.accent : AppColors.textSecondary, size: 20),
                    AppSpacing.hSpacerSm,
                    const Text('Estado: Carga (Loading)'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'empty',
                child: Row(
                  children: [
                    Icon(Icons.folder_open_rounded, color: _simulatedState == 'empty' ? AppColors.accent : AppColors.textSecondary, size: 20),
                    AppSpacing.hSpacerSm,
                    const Text('Estado: Vacío (Empty)'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'error',
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: _simulatedState == 'error' ? AppColors.accent : AppColors.textSecondary, size: 20),
                    AppSpacing.hSpacerSm,
                    const Text('Estado: Error'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Simulation banner if active
            if (_simulatedState != 'normal')
              Container(
                width: double.infinity,
                color: _simulatedState == 'loading'
                    ? AppColors.infoLight
                    : (_simulatedState == 'empty' ? AppColors.warningLight : AppColors.errorLight),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Simulación activa: ${_simulatedState.toUpperCase()}',
                      style: AppTypography.bodySecondary.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _simulatedState == 'loading'
                            ? AppColors.info
                            : (_simulatedState == 'empty' ? AppColors.warning : AppColors.error),
                      ),
                    ),
                    InkWell(
                      onTap: _resetSimulation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(
                            color: _simulatedState == 'loading'
                                ? AppColors.info
                                : (_simulatedState == 'empty' ? AppColors.warning : AppColors.error),
                          ),
                        ),
                        child: Text(
                          'Restablecer',
                          style: AppTypography.badgeText.copyWith(
                            color: _simulatedState == 'loading'
                                ? AppColors.info
                                : (_simulatedState == 'empty' ? AppColors.warning : AppColors.error),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Primary content
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() {
            _currentTab = index;
            // Clear order detail navigation when switching tabs
            if (index != 1) {
              _selectedOrderId = null;
            }
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            activeIcon: Icon(Icons.description_rounded),
            label: 'Pedidos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline_rounded),
            activeIcon: Icon(Icons.add_circle_rounded),
            label: 'Recepciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2_rounded),
            label: 'Inventario',
          ),
        ],
      ),
    );
  }
}
