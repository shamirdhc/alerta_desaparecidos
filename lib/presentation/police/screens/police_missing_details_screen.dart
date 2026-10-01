import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/desaparecido.dart';
import '../view_models/police_missing_details_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../injection.dart' as di;
import '../../../domain/repositories/policia_repository.dart';
// Agregar estos imports para los diálogos
import '../widgets/mark_as_found_dialog.dart';
import '../widgets/jurisdiction_error_dialog.dart';

class PoliceMissingDetailsScreen extends StatefulWidget {
  final Desaparecido desaparecido;

  const PoliceMissingDetailsScreen({super.key, required this.desaparecido});

  @override
  State<PoliceMissingDetailsScreen> createState() => _PoliceMissingDetailsScreenState();
}

class _PoliceMissingDetailsScreenState extends State<PoliceMissingDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late TextEditingController _notesController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _notesController = TextEditingController();
    _scrollController = ScrollController();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PoliceMissingDetailsViewModel(
        di.locator(),
        di.locator<PoliciaRepository>(),
        widget.desaparecido,
      ),
      child: Consumer<PoliceMissingDetailsViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildSliverAppBar(context, viewModel),
                ];
              },
              body: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Column(
                        children: [
                          _buildTabBar(),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildPersonalInfoTab(viewModel),
                                _buildLocationTab(viewModel),
                                _buildInvestigationTab(viewModel),
                                _buildTimelineTab(viewModel),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomNavigationBar: _buildActionBar(context, viewModel),
            floatingActionButton: _buildFloatingActionButton(context, viewModel),
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, PoliceMissingDetailsViewModel viewModel) {
    final desaparecido = viewModel.desaparecido;
    final priority = _calculatePriority(desaparecido);
    
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: const Color(0xFF1565C0),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          '${desaparecido.nombres} ${desaparecido.apellidos}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Imagen de fondo
            if (desaparecido.fotoUrl != null)
              Image.network(
                desaparecido.fotoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.person, size: 100, color: Colors.grey),
                  );
                },
              )
            else
              Container(
                color: Colors.grey[300],
                child: const Icon(Icons.person, size: 100, color: Colors.grey),
              ),
            
            // Overlay con gradiente
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            
            // Indicadores de estado
            Positioned(
              top: 100,
              right: 16,
              child: Column(
                children: [
                  _buildPriorityBadge(priority),
                  const SizedBox(height: 8),
                  _buildStatusBadge(desaparecido.estado == 'encontrado'),
                ],
              ),
            ),
            
            // Información básica
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (desaparecido.dni != null)
                    Text(
                      'DNI: ${desaparecido.dni}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _getDaysAgoText(desaparecido.fechaDesaparicion),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () => _shareCase(context, desaparecido),
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, viewModel, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Editar caso'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'print',
              child: Row(
                children: [
                  Icon(Icons.print, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Imprimir reporte'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(Icons.archive, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Archivar caso'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF1565C0),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF1565C0),
        tabs: const [
          Tab(icon: Icon(Icons.person), text: 'Personal'),
          Tab(icon: Icon(Icons.location_on), text: 'Ubicación'),
          Tab(icon: Icon(Icons.search), text: 'Investigación'),
          Tab(icon: Icon(Icons.timeline), text: 'Cronología'),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoTab(PoliceMissingDetailsViewModel viewModel) {
    final desaparecido = viewModel.desaparecido;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(
            'Información Personal',
            Icons.person,
            [
              _buildInfoRow('Nombres', desaparecido.nombres),
              _buildInfoRow('Apellidos', desaparecido.apellidos),
              _buildInfoRow('DNI', desaparecido.dni),
              _buildInfoRow('Sexo', desaparecido.sexo),
              _buildInfoRow('Edad', _calculateAge(desaparecido.fechaNacimiento)?.toString()),
              _buildInfoRow('Fecha de Nacimiento', 
                desaparecido.fechaNacimiento != null 
                  ? DateFormat('dd/MM/yyyy').format(desaparecido.fechaNacimiento!)
                  : null),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Contacto',
            Icons.contact_phone,
            [
              _buildInfoRow('Teléfono', desaparecido.telefonoContacto),
              // Eliminar las líneas que usan propiedades inexistentes
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Detalles Adicionales',
            Icons.info,
            [
              _buildInfoRow('Detalles', desaparecido.detallesAdicionales),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab(PoliceMissingDetailsViewModel viewModel) {
    final desaparecido = viewModel.desaparecido;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(
            'Lugar de Desaparición',
            Icons.location_on,
            [
              _buildInfoRow('Departamento', desaparecido.departamento),
              _buildInfoRow('Provincia', desaparecido.provincia),
              _buildInfoRow('Distrito', desaparecido.distrito),
              // Eliminar direccion y referencia que no existen
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Fecha y Hora',
            Icons.access_time,
            [
              _buildInfoRow('Fecha de Desaparición', 
                desaparecido.fechaDesaparicion != null 
                  ? DateFormat('dd/MM/yyyy HH:mm').format(desaparecido.fechaDesaparicion!)
                  : null),
              // Eliminar ultimaVezVisto que no existe
              _buildInfoRow('Tiempo transcurrido', _getDaysAgoText(desaparecido.fechaDesaparicion)),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Mapa (placeholder)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Mapa de ubicación', style: TextStyle(color: Colors.grey)),
                  Text('(Próximamente)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestigationTab(PoliceMissingDetailsViewModel viewModel) {
    final desaparecido = viewModel.desaparecido;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(
            'Detalles del Caso',
            Icons.search,
            [
              _buildInfoRow('Número de Caso', desaparecido.id),
              _buildInfoRow('Estado', desaparecido.estado == 'encontrado' ? 'Encontrado' : 'Activo'),
              _buildInfoRow('Prioridad', _getPriorityText(_calculatePriority(desaparecido))),
              _buildInfoRow('Unidad a Cargo', desaparecido.unidadACargo ?? 'División de Búsqueda PNP (Línea 114)'),
              _buildInfoRow('Dependencia Registradora', desaparecido.unidadRegistradora ?? 'Comisaría Sectorial'),
              if (desaparecido.fechaReasignacionDepitptim != null)
                _buildInfoRow(
                  'Reasignado a DEPITPTIM',
                  DateFormat('dd/MM/yyyy HH:mm').format(desaparecido.fechaReasignacionDepitptim!),
                ),
              _buildInfoRow('Fecha de Reporte', 
                desaparecido.fechaCreacion != null 
                  ? DateFormat('dd/MM/yyyy HH:mm').format(desaparecido.fechaCreacion!)
                  : null),
            ],
          ),
          
          const SizedBox(height: 16),
          _buildDepitptimCard(context, viewModel),
          
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Circunstancias',
            Icons.info,
            [
              _buildInfoRow('Detalles Adicionales', desaparecido.detallesAdicionales),
              // Eliminar ropaVestia, objetosPersonales, condicionMedica que no existen
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Notas de investigación
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.note_add, color: Color(0xFF1565C0)),
                      SizedBox(width: 8),
                      Text(
                        'Notas de Investigación',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Agregar notas de investigación...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _saveNotes(viewModel),
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar Notas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab(PoliceMissingDetailsViewModel viewModel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Timeline placeholder
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.timeline, color: Color(0xFF1565C0)),
                      SizedBox(width: 8),
                      Text(
                        'Cronología del Caso',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineItem(
                    'Reporte inicial',
                    viewModel.desaparecido.fechaCreacion ?? DateTime.now(),
                    'Caso reportado por familiar',
                    Icons.report,
                    Colors.blue,
                  ),
                  _buildTimelineItem(
                    'Desaparición',
                    viewModel.desaparecido.fechaDesaparicion ?? DateTime.now(),
                    'Última vez visto',
                    Icons.person_off,
                    Colors.orange,
                  ),
                  if (viewModel.desaparecido.estado == 'encontrado')
                    _buildTimelineItem(
                      'Encontrado',
                      viewModel.desaparecido.fechaEncontrado ?? DateTime.now(),
                      'Persona encontrada',
                      Icons.check_circle,
                      Colors.green,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, DateTime date, String description, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(date),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(int priority) {
    Color color;
    String label;
    
    switch (priority) {
      case 4:
        color = Colors.red;
        label = 'URGENTE';
        break;
      case 3:
        color = Colors.orange;
        label = 'ALTA';
        break;
      case 2:
        color = Colors.yellow[700]!;
        label = 'MEDIA';
        break;
      default:
        color = Colors.green;
        label = 'BAJA';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool encontrado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: encontrado ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        encontrado ? 'ENCONTRADO' : 'ACTIVO',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, PoliceMissingDetailsViewModel viewModel) {
    if (viewModel.desaparecido.estado == 'encontrado') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text(
              'Caso cerrado - Persona encontrada',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: viewModel.actionState == RequestState.Loading
                  ? null
                  : () => _showMarkAsFoundDialog(context, viewModel),
              icon: viewModel.actionState == RequestState.Loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('Marcar como Encontrado'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _updateCaseStatus(context, viewModel),
              icon: const Icon(Icons.update),
              label: const Text('Actualizar Estado'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, PoliceMissingDetailsViewModel viewModel) {
    return FloatingActionButton.extended(
      onPressed: () => _callEmergencyContact(viewModel.desaparecido),
      backgroundColor: const Color(0xFF1565C0),
      icon: const Icon(Icons.phone),
      label: const Text('Contactar'),
    );
  }

  // Métodos auxiliares
  int _calculatePriority(Desaparecido caso) {
    if (caso.fechaDesaparicion == null) return 1;
    
    final daysSinceDisappearance = DateTime.now().difference(caso.fechaDesaparicion!).inDays;
    
    if (daysSinceDisappearance > 30) return 4; // Urgente
    if (daysSinceDisappearance > 14) return 3; // Alta
    if (daysSinceDisappearance > 7) return 2;  // Media
    return 1; // Baja
  }

  int? _calculateAge(DateTime? fechaNacimiento) {
    if (fechaNacimiento == null) return null;
    
    final now = DateTime.now();
    int age = now.year - fechaNacimiento.year;
    
    // Ajustar si aún no ha cumplido años este año
    if (now.month < fechaNacimiento.month || 
        (now.month == fechaNacimiento.month && now.day < fechaNacimiento.day)) {
      age--;
    }
    
    return age;
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 4: return 'Urgente';
      case 3: return 'Alta';
      case 2: return 'Media';
      default: return 'Baja';
    }
  }

  String _getDaysAgoText(DateTime? fecha) {
    if (fecha == null) return 'Fecha no disponible';
    
    final days = DateTime.now().difference(fecha).inDays;
    if (days == 0) return 'Desaparecido hoy';
    if (days == 1) return 'Desaparecido ayer';
    if (days < 7) return 'Desaparecido hace $days días';
    if (days < 30) return 'Desaparecido hace ${(days / 7).floor()} semanas';
    return 'Desaparecido hace ${(days / 30).floor()} meses';
  }

  // Métodos de acción
  void _shareCase(BuildContext context, Desaparecido desaparecido) {
    // Implementar compartir caso
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidad de compartir próximamente')),
    );
  }

  void _handleMenuAction(BuildContext context, PoliceMissingDetailsViewModel viewModel, String action) {
    switch (action) {
      case 'edit':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funcionalidad de edición próximamente')),
        );
        break;
      case 'print':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funcionalidad de impresión próximamente')),
        );
        break;
      case 'archive':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funcionalidad de archivo próximamente')),
        );
        break;
    }
  }

  void _saveNotes(PoliceMissingDetailsViewModel viewModel) {
    // Implementar guardar notas
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notas guardadas exitosamente')),
    );
    _notesController.clear();
  }

  void _showMarkAsFoundDialog(BuildContext context, PoliceMissingDetailsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => MarkAsFoundDialog(
        onConfirm: (fechaEncontrado, detalles) async {
          // Cerrar el diálogo primero
          Navigator.of(context).pop();
          
          // Ejecutar la operación y esperar a que termine
          await viewModel.markAsFound(
            fechaEncontrado: fechaEncontrado,
            detallesEncontrado: detalles,
          );
          
          if (!mounted) return;
          
          // Ahora verificar el estado después de que la operación haya terminado
          if (viewModel.actionState == RequestState.Error && viewModel.isJurisdictionError) {
            _showJurisdictionErrorDialog(context, viewModel);
          } else if (viewModel.actionState == RequestState.Error) {
            // Mostrar error general
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(viewModel.actionMessage),
                backgroundColor: Colors.red,
              ),
            );
          } else if (viewModel.actionState == RequestState.Loaded) {
            // Mostrar éxito
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(viewModel.actionMessage),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _showJurisdictionErrorDialog(BuildContext context, PoliceMissingDetailsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => JurisdictionErrorDialog(
        departamentoDesaparecido: viewModel.desaparecido.departamento ?? 'No especificado',
        departamentoPolicia: viewModel.currentPolicia?.departamento ?? 'No especificado', // Cambiado: removida la tilde
      ),
    );
  }

  void _updateCaseStatus(BuildContext context, PoliceMissingDetailsViewModel viewModel) {
    // Implementar actualización de estado
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidad de actualización próximamente')),
    );
  }

  void _callEmergencyContact(Desaparecido desaparecido) async {
    if (desaparecido.telefonoContacto != null) {
      final url = 'tel:${desaparecido.telefonoContacto}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    }
  }

  Widget _buildDepitptimCard(
    BuildContext context,
    PoliceMissingDetailsViewModel viewModel,
  ) {
    final desaparecido = viewModel.desaparecido;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFF1565C0)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unidad Policial Responsable',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      Text(
                        'Dirección de Trata de Personas (DIRCTPTIM)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city, color: Color(0xFF1565C0), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unidad a cargo: ${desaparecido.unidadACargo ?? "División de Búsqueda PNP (Línea 114)"}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Si el caso es asumido por la unidad especializada DEPITPTIM o derivado para atención comunitaria, reasigne la unidad para coordinar las alertas públicas.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz, color: Color(0xFF1565C0)),
                label: const Text(
                  'Reasignar a DEPITPTIM / Unidad',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
                onPressed: () => _showReasignarDepitptimDialog(context, viewModel),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReasignarDepitptimDialog(
    BuildContext context,
    PoliceMissingDetailsViewModel viewModel,
  ) {
    String selectedUnidad = viewModel.desaparecido.unidadACargo ?? 'División de Búsqueda PNP (Línea 114)';
    final List<String> opciones = [
      'División de Búsqueda PNP (Línea 114)',
      'DEPITPTIM ABANCAY',
      'DIRCTPTIM CENTRAL LIMA',
      'COMISARÍA SECTORIAL TALAVERA',
      'COMISARÍA SAN JERÓNIMO',
      'COMISARÍA CHINCHEROS',
    ];

    if (!opciones.contains(selectedUnidad)) {
      opciones.insert(0, selectedUnidad);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.shield, color: Color(0xFF1565C0)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reasignar Unidad a Cargo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seleccione la unidad especializada o comisaría responsable del caso:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedUnidad,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: opciones.map((op) {
                      return DropdownMenuItem(
                        value: op,
                        child: Text(op, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedUnidad = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Nota: Esta acción actualiza la unidad de contacto y el despacho de alertas públicas en el aplicativo.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      if (viewModel.desaparecido.id != null) {
                        await FirebaseFirestore.instance
                            .collection('desaparecidos')
                            .doc(viewModel.desaparecido.id)
                            .update({
                          'unidad_a_cargo': selectedUnidad,
                          'depitptim_nombre': selectedUnidad,
                          'fecha_reasignacion_depitptim':
                              FieldValue.serverTimestamp(),
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Caso reasignado exitosamente a $selectedUnidad',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al reasignar caso: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Confirmar Reasignación'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}