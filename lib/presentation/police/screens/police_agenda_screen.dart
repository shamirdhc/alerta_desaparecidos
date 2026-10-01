import '../../../services/gps_location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/agenda_policial_service.dart';
import '../../../data/models/comisaria_model.dart';
import 'police_home_screen.dart';

class PoliceAgendaScreen extends StatefulWidget {
  const PoliceAgendaScreen({super.key});

  @override
  State<PoliceAgendaScreen> createState() => _PoliceAgendaScreenState();
}

class _PoliceAgendaScreenState extends State<PoliceAgendaScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late AnimationController _pulseController;

  List<String> _departamentosDisponibles = [];
  List<ComisariaModel> _comisarias = [];
  List<ComisariaModel> _comisariasFiltradas = [];

  String? _departamentoSeleccionado;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isInitialized = false;
  String _mensaje = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isInitialized = false;
      _mensaje = 'Conectando con base de datos PNP...';
      _errorMessage = null;
    });

    try {        await AgendaPolicialService.inicializarSincronizacion();
        await _cargarDepartamentos();

        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _animationController.forward();
        }

        // Auto-seleccionar departamento del policía
        if (_departamentosDisponibles.isNotEmpty) {
          final loc = await GpsLocationService.getSavedLocation();
          String deptToSelect = _departamentosDisponibles.first;
          if (loc != null) {
            final match = _departamentosDisponibles.firstWhere(
              (d) => GpsLocationService.matches(d, loc.departamento),
              orElse: () => _departamentosDisponibles.first,
            );
            deptToSelect = match;
          }
          await _seleccionarDepartamento(deptToSelect);
        }
    } catch (e) {
      print('Error en inicialización: $e');
      if (mounted) {
        setState(() {
          _mensaje = 'Error al conectar con el sistema';
          _errorMessage = e.toString();
          _isInitialized = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cargarDepartamentos() async {
    if (!mounted) return;

    try {
      final departamentos =
          await AgendaPolicialService.getDepartamentosDisponibles();

      if (mounted) {
        setState(() {
          _departamentosDisponibles = departamentos;
          if (departamentos.isNotEmpty) {
            _mensaje =
                '${departamentos.length} regiones policiales disponibles';
          } else {
            _mensaje = 'No se encontraron regiones';
          }
        });
      }
    } catch (e) {
      print('Error al cargar departamentos: $e');
      if (mounted) {
        setState(() {
          _mensaje = 'Error al cargar regiones policiales';
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _seleccionarDepartamento(String departamento) async {
    if (!mounted) return;

    setState(() {
      _departamentoSeleccionado = departamento;
      _isLoading = true;
      _mensaje = 'Localizando comisarías en $departamento...';
      _comisarias.clear();
      _comisariasFiltradas.clear();
      _searchController.clear();
      _errorMessage = null;
    });

    try {
      final comisarias =
          await AgendaPolicialService.cargarComisariasDepartamento(
            departamento,
          );

      if (mounted) {
        setState(() {
          _comisarias = comisarias;
          _comisariasFiltradas = comisarias;
          _mensaje = '${comisarias.length} unidades policiales activas';
        });
      }
    } catch (e) {
      print('Error al cargar comisarías: $e');
      if (mounted) {
        setState(() {
          _mensaje = 'Error al localizar unidades';
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (_departamentoSeleccionado == null || !mounted) return;

    if (query.isEmpty) {
      setState(() {
        _comisariasFiltradas = _comisarias;
        _isSearching = false;
      });
    } else {
      setState(() {
        _isSearching = true;
      });
      _buscarComisarias(query);
    }
  }

  Future<void> _buscarComisarias(String query) async {
    if (_departamentoSeleccionado == null || !mounted) return;

    try {
      final resultados = await AgendaPolicialService.buscarComisarias(
        _departamentoSeleccionado!,
        query,
      );

      if (mounted) {
        setState(() {
          _comisariasFiltradas = resultados;
          _mensaje = '${resultados.length} resultados encontrados';
        });
      }
    } catch (e) {
      print('Error en búsqueda: $e');
      if (mounted) {
        setState(() {
          _mensaje = 'Error en la búsqueda';
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                children: [
                  _buildPoliceHeader(),
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoliceHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PoliceHomeScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF415A77), Color(0xFF778DA9)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.arrowLeft,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedTextKit(
                      animatedTexts: [
                        TypewriterAnimatedText(
                          'AGENDA POLICIAL',
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                          speed: const Duration(milliseconds: 100),
                        ),
                      ],
                      totalRepeatCount: 1,
                    ),
                    const Text(
                      'Directorio Nacional PNP',
                      style: TextStyle(
                        color: Color(0xFF778DA9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B998B), Color(0xFF2D5016)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Text(
                  'PNP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatusIndicator(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.1),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isInitialized ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isInitialized ? Colors.green : Colors.orange)
                            .withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _mensaje,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && !_isInitialized) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null && !_isInitialized) {
      return _buildErrorWidget();
    }

    if (_departamentoSeleccionado == null) {
      return _buildDepartmentSelection();
    }

    return _buildComisariasList();
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Lottie.asset(
              'assets/icons/loading_animation.json',
              errorBuilder: (context, error, stackTrace) {
                return const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B998B)),
                  strokeWidth: 3,
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          AnimatedTextKit(
            animatedTexts: [
              TypewriterAnimatedText(
                'Sincronizando con PNP...',
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                speed: const Duration(milliseconds: 100),
              ),
            ],
            repeatForever: true,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: GlassmorphicContainer(
          width: double.infinity,
          height: 300,
          borderRadius: 20,
          blur: 20,
          alignment: Alignment.center,
          border: 2,
          linearGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.5),
              Colors.white.withOpacity(0.2),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(
                  FontAwesomeIcons.triangleExclamation,
                  color: Color(0xFFFF6B35),
                  size: 48,
                ),
                const SizedBox(height: 20),
                const Text(
                  'ERROR DE CONEXIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _mensaje,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _initializeService,
                  icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
                  label: const Text('REINTENTAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B998B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECCIONAR REGIÓN POLICIAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.5,
            ),
            itemCount: _departamentosDisponibles.length,
            itemBuilder: (context, index) {
              final departamento = _departamentosDisponibles[index];
              return _buildDepartmentCard(departamento, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard(String departamento, int index) {
    final colors = [
      const Color(0xFF457B9D),
      const Color(0xFF1B998B),
      const Color(0xFF6A4C93),
      const Color(0xFFFF6B35),
      const Color(0xFF2D5016),
      const Color(0xFF778DA9),
    ];
    
    final color = colors[index % colors.length];

    return GestureDetector(
      onTap: () => _seleccionarDepartamento(departamento),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
              FontAwesomeIcons.mapLocationDot,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              departamento,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 100));
  }

  Widget _buildComisariasList() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B998B)),
                  ),
                )
              : _comisariasFiltradas.isEmpty
                  ? _buildEmptyState()
                  : _buildComisariasGrid(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const FaIcon(
            FontAwesomeIcons.magnifyingGlass,
            color: Color(0xFF778DA9),
            size: 18,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar comisaría...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
              },
              child: const FaIcon(
                FontAwesomeIcons.xmark,
                color: Color(0xFF778DA9),
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FaIcon(
            FontAwesomeIcons.magnifyingGlass,
            color: Color(0xFF778DA9),
            size: 64,
          ),
          const SizedBox(height: 20),
          Text(
            _isSearching ? 'Sin resultados' : 'No hay comisarías disponibles',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isSearching
                ? 'Intenta con otros términos de búsqueda'
                : 'Selecciona otra región policial',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComisariasGrid() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _comisariasFiltradas.length,
      itemBuilder: (context, index) {
        final comisaria = _comisariasFiltradas[index];
        return _buildComisariaCard(comisaria, index);
      },
    );
  }

  Widget _buildComisariaCard(ComisariaModel comisaria, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 190,
        borderRadius: 20,
        blur: 20,
        alignment: Alignment.center,
        border: 3,
        linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.5),
            Colors.white.withOpacity(0.2),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withOpacity(0.2),
                blurRadius: 25,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B998B), Color(0xFF2D5016)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.shield,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      comisaria.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                FontAwesomeIcons.building,
                'Unidad',
                comisaria.unidad,
              ),
              const SizedBox(height: 4),
              _buildInfoRow(
                FontAwesomeIcons.locationDot,
                'Ubicación',
                '${comisaria.distrito}, ${comisaria.provincia}',
              ),
              const SizedBox(height: 8),
              // Botón llamar, número y botón de edición policial
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildActionButton(
                      'LLAMAR',
                      FontAwesomeIcons.phone,
                      const Color(0xFF00C851),
                      () => _llamarComisaria(comisaria.telefono),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildPhoneDisplay(comisaria.telefono),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.amberAccent, size: 18),
                      tooltip: 'Editar Datos de Comisaría (PNP)',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: () => _mostrarDialogoEditarComisaria(comisaria),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 100));
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FaIcon(
          icon,
          color: const Color(0xFF778DA9),
          size: 12,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _llamarComisaria(String telefono) async {
    final url = 'tel:$telefono';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se puede realizar la llamada a $telefono'),
            backgroundColor: const Color(0xFFFF6B35),
          ),
        );
      }
    }
  }

  Widget _buildPhoneDisplay(String telefono) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667EEA).withOpacity(0.3),
            const Color(0xFF764BA2).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF667EEA).withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.phone,
            color: const Color(0xFF667EEA),
            size: 12,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              telefono,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditarComisaria(ComisariaModel comisaria) {
    final telefonoCtrl = TextEditingController(text: comisaria.telefono);
    final direccionCtrl = TextEditingController(text: comisaria.direccion);
    bool guardando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.shieldHalved,
                    color: Color(0xFF60A5FA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Actualizar Comisaría',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comisaria.nombre,
                    style: const TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${comisaria.distrito}, ${comisaria.provincia} - ${comisaria.departamento}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Número Telefónico / Celular:',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone, color: Color(0xFF60A5FA), size: 20),
                      hintText: 'Ej. 980123456 o (01) 456-7890',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF60A5FA)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Dirección / Sede:',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: direccionCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on, color: Color(0xFF60A5FA), size: 20),
                      hintText: 'Dirección o referencia de la sede',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF60A5FA)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton.icon(
                icon: guardando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                label: Text(
                  guardando ? 'Guardando...' : 'Guardar en Tiempo Real',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: guardando
                    ? null
                    : () async {
                        final nuevoTel = telefonoCtrl.text.trim();
                        final nuevaDir = direccionCtrl.text.trim();
                        if (nuevoTel.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('El número de teléfono no puede estar vacío.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => guardando = true);

                        final ok = await AgendaPolicialService.actualizarComisaria(
                          comisaria,
                          nuevoTelefono: nuevoTel,
                          nuevaDireccion: nuevaDir.isNotEmpty ? nuevaDir : null,
                        );

                        if (!mounted) return;
                        Navigator.pop(ctx);

                        if (ok) {
                          setState(() {
                            final idx = _comisarias.indexWhere((c) => c.id == comisaria.id || c.nombre == comisaria.nombre);
                            if (idx != -1) {
                              _comisarias[idx] = comisaria.copyWith(
                                telefono: nuevoTel,
                                direccion: nuevaDir,
                              );
                            }
                            final fIdx = _comisariasFiltradas.indexWhere((c) => c.id == comisaria.id || c.nombre == comisaria.nombre);
                            if (fIdx != -1) {
                              _comisariasFiltradas[fIdx] = comisaria.copyWith(
                                telefono: nuevoTel,
                                direccion: nuevaDir,
                              );
                            }
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '¡Comisaría actualizada en tiempo real! Nuevo número: $nuevoTel',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo actualizar en la nube. Verifique su conexión.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

}
